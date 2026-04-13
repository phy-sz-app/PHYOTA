//
//  BurnInOTAManager.swift
//  iOS_PHYOTA_Test
//
//  Created by di lu on 2026/4/9.
//

import Foundation
import Combine
import CoreBluetooth

// 烧录规则配置
struct BurnInRule: Codable {
    var namePrefix: String = ""           // 设备名前缀
    var minRSSI: Int = -70               // 最小信号强度
    var scanDuration: Int = 15           // 扫描时长（秒）
    var maxEmptyScanCount: Int = 4       // 最大空扫描次数
    var otaTimeout: Int = 120            // OTA超时时间（秒）
}

// 烧录测试状态
enum BurnInState {
    case idle
    case scanning
    case upgrading
    case waitingForReboot
    case completed
    case failed(String)
    
    // 自定义相等性比较，处理带关联值的 case
    static func == (lhs: BurnInState, rhs: BurnInState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle),
            (.scanning, .scanning),
            (.upgrading, .upgrading),
            (.waitingForReboot, .waitingForReboot),
            (.completed, .completed):
            return true
        case (.failed(let lhsMessage), .failed(let rhsMessage)):
            return lhsMessage == rhsMessage
        default:
            return false
        }
    }
    
    static func != (lhs: BurnInState, rhs: BurnInState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle),
            (.scanning, .scanning),
            (.upgrading, .upgrading),
            (.waitingForReboot, .waitingForReboot),
            (.completed, .completed):
            return false
        case (.failed(let lhsMessage), .failed(let rhsMessage)):
            return lhsMessage != rhsMessage
        default:
            return true
        }
    }
}

// 烧录设备信息
struct BurnInDeviceInfo: Identifiable {
    let id = UUID()
    let uuid: String
    let name: String
    let rssi: Int
    let mac: String
    var isUpgraded: Bool = false
    var upgradeSuccess: Bool = false
    var failReason: String?
}

class BurnInOTAManager: ObservableObject {
    @Published var rule = BurnInRule()
    @Published var state: BurnInState = .idle
    @Published var stateMessage: String = "等待开始"
    @Published var discoveredDevices: [BurnInDeviceInfo] = []   //扫描到的设备列表
    @Published var upgradedDevices: [BurnInDeviceInfo] = []     //已升级完的设备列表
    @Published var currentScanCount: Int = 0        //第几轮扫描
    @Published var emptyScanCount: Int = 0          //空扫描轮数
    @Published var totalUpgradedCount: Int = 0      //总升级成功设备数
    @Published var scanTimeRemaining: Int = 0       //当轮剩余扫描时间
    
    private weak var bluetoothManager: BluetoothManager?
    private var filesManager: OTAFileManager?
    private var logManager: LogManager?
    
    private var scanTimer: Timer?
    
    private var cancellables = Set<AnyCancellable>()
    
    // 当前升级的设备
    private var pendingDevices: [BurnInDeviceInfo] = []     //待升级设备的列表
    private var upgradedUUIDs: Set<String> = []             //保存升级成功设备的UUID列表
    
    
    init() {
        loadRule()
    }
    
    func setupDependencies(bluetoothManager: BluetoothManager, filesManager: OTAFileManager, logManager: LogManager) {
        self.bluetoothManager = bluetoothManager
        self.filesManager = filesManager
        self.logManager = logManager
    }
    
    private func loadRule() {
        if let data = UserDefaults.standard.data(forKey: "burn_in_rule") {
            do {
                rule = try JSONDecoder().decode(BurnInRule.self, from: data)
            } catch {
                print("加载烧录规则失败: \(error)")
            }
        }
    }
    
    func saveRule() {
        do {
            let data = try JSONEncoder().encode(rule)
            UserDefaults.standard.set(data, forKey: "burn_in_rule")
        } catch {
            print("保存烧录规则失败: \(error)")
        }
    }
    
    // 当前是否已选择升级文件
    func getFirstFile() -> OTAFileModel? {
        return filesManager?.selectedFiles.first
    }
    
    // 开始烧录流程
    func startBurnIn() {
        guard let filesManager = filesManager else {
            state = .failed("系统未初始化")
            return
        }
        
        guard !filesManager.selectedFiles.isEmpty else {
            state = .failed("请先在主页面选择升级文件")
            return
        }
        
        // 重置状态
        currentScanCount = 0            //第几轮扫描
        emptyScanCount = 0              //空扫描轮数
        totalUpgradedCount = 0          //总共升级成功设备数
        upgradedUUIDs.removeAll()       //保存升级完成设备的UUID列表
        upgradedDevices.removeAll()     //已升级完成的设备列表
        pendingDevices.removeAll()      //待升级设备的列表
        
        bluetoothManager!.isBurnInMode = true
        state = .scanning
        stateMessage = "开始第 1 轮扫描"
        
        logManager?.addLog(level: .info, source: "BurnIn",
                           message: "开始烧录式OTA，规则: 前缀=\(rule.namePrefix), RSSI>=\(rule.minRSSI)")
        
        startScanCycle()
    }
    
    // 开始一轮扫描
    private func startScanCycle() {
        currentScanCount += 1
        scanTimeRemaining = rule.scanDuration
        discoveredDevices.removeAll()
        
        state = .scanning
        stateMessage = "第 \(currentScanCount) 轮扫描中... 剩余 \(scanTimeRemaining)秒"
        
        bluetoothManager?.startScan()
        
        // 启动扫描倒计时
        scanTimer?.invalidate()
        scanTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            
            self.scanTimeRemaining -= 1
            self.stateMessage = "第 \(self.currentScanCount) 轮扫描中... 剩余 \(self.scanTimeRemaining)秒"
            
            if self.scanTimeRemaining <= 0 {
                timer.invalidate()
                self.finishScanCycle()
            }
        }
    }
    
    func deviceFound(_ devicesArray: [PHYBLEModel]) {
        guard state == .scanning else { return }
        
        for device in devicesArray {
            handleDiscoveredDevice(device);
        }
    }
    
    // 处理扫描到的设备
    func handleDiscoveredDevice(_ device: PHYBLEModel) {
        // 检查是否符合规则
        guard deviceMatchesRule(device) else { return }
        
        let deviceInfo = BurnInDeviceInfo(
            uuid: device.peripheral.identifier.uuidString,
            name: device.realName,
            rssi: device.rssi.intValue,
            mac: device.adverMacAddr
        )
        
        // 添加到扫描发现列表（去重）
        if !discoveredDevices.contains(where: { $0.uuid == deviceInfo.uuid }) {
            discoveredDevices.append(deviceInfo)
            
            logManager?.addLog(level: .debug, source: "BurnIn",
                              message: "发现符合规则设备: \(deviceInfo.name), RSSI: \(deviceInfo.rssi)")
        }
    }
    
    // 检查设备是否符合规则
    private func deviceMatchesRule(_ device: PHYBLEModel) -> Bool {
        // 检查名称前缀
        if !rule.namePrefix.isEmpty {
            guard device.realName.hasPrefix(rule.namePrefix) else {
                return false
            }
        }
        
        // 检查信号强度
        if device.rssi.intValue < rule.minRSSI {
            return false
        }
        
        // 检查是否已经升级过
        if upgradedUUIDs.contains(device.peripheral.identifier.uuidString) {
            return false
        }
        
        return true
    }
    
    // 完成一轮扫描
    private func finishScanCycle() {
        bluetoothManager?.stopScan()
        
        if discoveredDevices.isEmpty {
            emptyScanCount += 1
            logManager?.addLog(level: .info, source: "BurnIn",
                              message: "第 \(currentScanCount) 轮扫描未发现设备，空扫描次数: \(emptyScanCount)")
            
            if emptyScanCount >= rule.maxEmptyScanCount {
                // 达到最大空扫描次数，结束烧录
                completeBurnIn()
                return
            }
            
            // 继续下一轮扫描
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.startScanCycle()
            }
        } else {
            // 发现设备，重置空扫描计数
            emptyScanCount = 0
            
            // 按信号强度排序，准备升级
            pendingDevices = discoveredDevices.sorted { $0.rssi > $1.rssi }
            
            logManager?.addLog(level: .info, source: "BurnIn",
                              message: "第 \(currentScanCount) 轮扫描发现 \(pendingDevices.count) 个设备，开始升级")
            
            // 开始升级这一轮满足条件的设备
            startDevicesUpgrade()
        }
    }
    
    // 开始设备升级
    private func startDevicesUpgrade() {
        state = .upgrading
        stateMessage = "正在升级: \(pendingDevices.count)个设备"
        logManager?.addLog(level: .info, source: "BurnIn", message: stateMessage)
        
        bluetoothManager?.setBurnInDevices(pendingDevices)
        
        // 使用第一个选中的文件
        if let file = filesManager?.selectedFiles.first {
            bluetoothManager?.startOTA(with: file.fileAbsolutePath)
        } else {
            stateMessage = "无升级文件"
        }
    }
    
    // 处理OTA状态通知
    func listenNotify(_ peripheral: CBPeripheral,_ message: String,_ code: UInt) {
        
        if var device = pendingDevices.first(where: {$0.uuid == peripheral.identifier.uuidString}) {
            
            switch code {
            case OTASwiftConstants.OTASuccessReboot:
                
                device.isUpgraded = true
                device.upgradeSuccess = true
                
                upgradedUUIDs.insert(device.uuid)
                totalUpgradedCount += 1
                
                self.upgradedDevices.insert(device, at: 0)
                
                logManager?.addLog(level: .info , source: "BurnIn",
                                  message: "设备升级成功: \(device.name)")
                
                if state == .upgrading {
                    state = .waitingForReboot
    //                stateMessage = "设备重启中: \(peripheral.name)"
    //                logManager?.addLog(level: .info, source: "BurnIn",
    //                                  message: "设备升级成功，等待重启: \(peripheral.name)")
                }
                
            case OTASwiftConstants.OTAFailed,
                 OTASwiftConstants.MAXDisconnectedTime,
                 OTASwiftConstants.DeviceConnectFail,
                 OTASwiftConstants.DeviceErrorCode:
                
                device.isUpgraded = true
                device.upgradeSuccess = false
                device.failReason = message
                
                upgradedUUIDs.insert(device.uuid)
                
                self.upgradedDevices.insert(device, at: 0)
                
                logManager?.addLog(level: .error, source: "BurnIn",
                                  message: "设备升级失败: \(device.name)\(message)")
                
                stateMessage = message
            default:
                break
            }
            
        }
    }
    
    func pendingDevicesOTAEnd(_ devices: [PHYBLEModel]) {
        // 本轮设备全部升级完成，开始下一轮扫描
        logManager?.addLog(level: .info, source: "BurnIn",
                          message: "第 \(currentScanCount) 轮设备升级完成")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            self?.startScanCycle()
        }
    }
    
    private func completeBurnIn() {
        state = .completed
        stateMessage = "烧录完成！共升级 \(totalUpgradedCount) 个设备"
        
        logManager?.addLog(level: .info, source: "BurnIn",
                          message: "烧录式OTA完成，共升级 \(totalUpgradedCount) 个设备，共 \(currentScanCount) 轮扫描")
        
        bluetoothManager?.stopScan()
        bluetoothManager?.stopOTA()
    }
    
    func stopBurnIn() {
        scanTimer?.invalidate()
        
        bluetoothManager?.stopScan()
        bluetoothManager?.stopOTA()
        
        state = .idle
        stateMessage = "已停止"
        
        logManager?.addLog(level: .info, source: "BurnIn", message: "烧录式OTA已停止")
    }
}
