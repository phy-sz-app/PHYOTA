//
//  BluetoothManager.swift
//  iOS_PHYOTA_Test
//
//  Created by di lu on 2026/1/19.
//

import Foundation
import Combine
import CoreBluetooth

class BluetoothManager: NSObject, ObservableObject {
    @Published var devices: [PHYBLEModel] = []      //未升级时显示扫描到的设备数据
    @Published var otaDevices: [PHYBLEModel] = []   //开始升级后显示OTA中的设备数据
    
    @Published var message: String = "请打开手机蓝牙"

    //扫描和开始OTA两个阶段界面显示的数据不同
    @Published var isScanning: Bool = false     //扫描时认定为没有开始OTA
    @Published var isInOTAMode: Bool = false    //是否开始OTA
    
    public var isTestMode: Bool = false     //是否为压力测试模式
    public var isBurnInMode: Bool = false   //是否为烧录式OTA模式
    
    // 添加日志管理器
    let logManager = LogManager()
    
    // 压力测试和烧录式OTA对象
    let stressTestManager = StressTestManager()
    let burnInManager = BurnInOTAManager()
    
    // 库文件中的BLE处理类
    private let bleManager = PHYBLEManager.shareInstance()
    
    // 当前选择的待升级设备
    private var selectedDeviceUUIDs: Set<String> = []
    
    // 可选类型，通过 setup 方法注入
    private weak var filesManager: OTAFileManager?
    
    var selectedDevicesCount: Int {
        selectedDeviceUUIDs.count
    }
    
    //未升级时显示扫描到的设备，开始升级后显示OTA中的设备
    var currentDeviceList: [PHYBLEModel] {
        isInOTAMode ? otaDevices : devices
    }
    
    var selectedDevices: [PHYBLEModel] {
        devices.filter { selectedDeviceUUIDs.contains($0.peripheral.identifier.uuidString) }
    }
    
    override init() {
        super.init()
        bleManager.delegate = self
        
        // 添加初始化日志
        logManager.addLog(level: .info, source: "BluetoothManager", message: "蓝牙管理器初始化完成")
    }
    
    func startScan() {
        bleManager.startScan()
        isScanning = true
        isInOTAMode = false
        message = "扫描已开始"
        devices.removeAll()
        selectedDeviceUUIDs.removeAll()
        
        logManager.addLog(level: .info, source: "BluetoothManager", message: message)
    }
    
    func stopScan() {
        bleManager.stopScan()
        isScanning = false
        message = "扫描已停止"
        
        logManager.addLog(level: .info, source: "BluetoothManager", message: message)
    }
    
    // 从扫描到的列表中，选择或取消某个设备
    func toggleDeviceSelection(_ uuid: String) {
        if selectedDeviceUUIDs.contains(uuid) {
            selectedDeviceUUIDs.remove(uuid)
            logManager.addLog(level: .info, source: "BluetoothManager",
                            message: "取消选择设备", deviceID: uuid)
            print("取消选择设备")
        } else {
            selectedDeviceUUIDs.insert(uuid)
            if let device = devices.first(where: { $0.peripheral.identifier.uuidString == uuid }) {
                logManager.addLog(level: .info, source: "BluetoothManager",
                                message: "选择设备: \(device.realName)",
                                deviceID: uuid, deviceName: device.realName)
            }
            print("选择设备")
        }
        
        message = "已选择 \(selectedDeviceUUIDs.count) 个设备"
    }
    
    func isDeviceSelected(_ uuid: String) -> Bool {
        selectedDeviceUUIDs.contains(uuid)
    }
    
    // 添加 setup 方法
    func setup(filesManager: OTAFileManager) {
        self.filesManager = filesManager
        stressTestManager.setupDependencies(bluetoothManager: self, filesManager: filesManager)
        burnInManager.setupDependencies(bluetoothManager: self, filesManager: filesManager, logManager: logManager)
        logManager.addLog(level: .info, source: "BluetoothManager", message: "蓝牙管理器配置完成")
    }
    
    func startOTA(with filePath: String) {
        guard !selectedDeviceUUIDs.isEmpty else {
            message = "请先选择要升级的设备"
            logManager.addLog(level: .warning, source: "BluetoothManager", message: message)
            return
        }
        
        // 检查文件管理器是否已设置
        guard filesManager != nil else {
            message = "升级文件未配置"
            logManager.addLog(level: .error, source: "BluetoothManager", message: message)
            return
        }
        
        logManager.addLog(level: .info, source: "BluetoothManager",
                         message: "开始OTA升级，文件: \(filePath)")
        
        bleManager.selectFilePath(filePath)
        let uuids = Array(selectedDeviceUUIDs)
        let success = bleManager.addDevices(uuids)
        
        if success {
            isInOTAMode = true
            otaDevices = bleManager.deviceArray as? [PHYBLEModel] ?? []
            message = "正在升级 \(selectedDeviceUUIDs.count) 个设备..."
            
            logManager.addLog(level: .info, source: "BluetoothManager",
                            message: "OTA升级已启动，设备数: \(selectedDeviceUUIDs.count)")
        }
    }
    
    func stopOTA() {
        bleManager.stopOTA()
        
        isTestMode = false
        isBurnInMode = false
        isInOTAMode = false
        selectedDeviceUUIDs.removeAll()
        
        logManager.addLog(level: .info, source: "BluetoothManager",
                         message: "停止OTA升级")
    }
    
    // 为压力测试设置设备选择（只选择一个设备）
    func setStressTestDevice(_ uuid: String) {
        selectedDeviceUUIDs.removeAll()
        selectedDeviceUUIDs.insert(uuid)
        isTestMode = true
        if let device = devices.first(where: { $0.peripheral.identifier.uuidString == uuid }) {
            logManager.addLog(level: .info, source: "StressTest",
                              message: "压力测试选择设备: \(device.realName)",
                              deviceID: uuid, deviceName: device.realName)
        }
    }
    
    func setBurnInDevices(_ devices: [BurnInDeviceInfo]) {
        selectedDeviceUUIDs.removeAll()
        for device in devices {
            selectedDeviceUUIDs.insert(device.uuid)
        }
    }
}

// MARK: - PHYBLEManagerDelegate
extension BluetoothManager: PHYBLEManagerDelegate {
    
    func centerMessage(_ message: String, code: UInt) {
        switch code {
        case OTASwiftConstants.BLENOTActive:
            self.stopScan()
            self.logManager.addLog(level: .error, source: "BLE", message: "蓝牙未开启")
        case OTASwiftConstants.BLEActive:
            self.logManager.addLog(level: .info, source: "BLE", message: "蓝牙已开启")
        case OTASwiftConstants.FileVersion:
            self.logManager.addLog(level: .info, source: "File", message: "文件版本: \(message)")
        case OTASwiftConstants.RESCANStart:
            self.logManager.addLog(level: .info, source: "BLE", message: "SBK升级开始二次扫描OTA模式设备")
        case OTASwiftConstants.OTAEnd:
            self.logManager.addLog(level: .info, source: "OTA", message: "OTA升级结束")
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.isInOTAMode = false
                self.selectedDeviceUUIDs.removeAll()
                print("OTA升级完成 开始扫描")
                if !self.isTestMode && !self.isBurnInMode {
                    self.startScan()
                }
            }
            if self.isBurnInMode {
                burnInManager.pendingDevicesOTAEnd(bleManager.deviceArray as? [PHYBLEModel] ?? [] )
            }
        default:
            // 记录日志
            self.logManager.addLog(level: .info, source: "BLE-Center", message: message)
            break
        }
    }
    
    func deviceFound(_ devicesArray: [Any]) {
        if !isInOTAMode {
            if let bleDevices = devicesArray as? [PHYBLEModel] {
                self.devices = bleDevices
                if !bleDevices.isEmpty {
                    self.logManager.addLog(level: .debug, source: "BLE-Scan",
                                         message: "发现 \(bleDevices.count) 个设备")
                }
            }
        }
        
        if isTestMode {
            self.stressTestManager.deviceFound(devicesArray as! [PHYBLEModel])
        }
        
        if isBurnInMode {
            self.burnInManager.deviceFound(devicesArray as! [PHYBLEModel])
        }
    }
    
    func listenNotify(_ peripheral: CBPeripheral, message: String, code: UInt) {
        
        if code == OTASwiftConstants.DeviceVersion {
            self.logManager.addBLELog(level: .info, message: "设备固件版本: \(message)", peripheral: peripheral)
        } else if code == OTASwiftConstants.ProgressCallBack {
            // 进度更新
            if let progress = Float(message) {
                self.logManager.addBLELog(level: .debug, message: "进度: \(progress)%", peripheral: peripheral)
            }
        } else if code == OTASwiftConstants.OTAFailed {
            self.logManager.addBLELog(level: .error, message: "OTA升级失败: \(message)", peripheral: peripheral)
        } else if code == OTASwiftConstants.OTAComplete {
            self.logManager.addBLELog(level: .info, message: "OTA升级成功", peripheral: peripheral)
        } else {
            // 记录设备特定的日志
            self.logManager.addBLELog(level: .info, message: message, peripheral: peripheral)
        }
        
        // 更新OTA设备列表
        self.otaDevices = self.bleManager.deviceArray as? [PHYBLEModel] ?? []
        
        if isTestMode {
            self.stressTestManager.listenNotify(peripheral, message: message, code: code)
        }
        
        if isBurnInMode {
            self.burnInManager.listenNotify(peripheral, message, code)
        }
    }
    
}
