//
//  StressTestManager.swift
//  iOS_PHYOTA_Test
//
//  Created by di lu on 2026/1/26.
//

import Foundation
import Combine
import CoreBluetooth

// 单次测试结果
struct TestResult: Identifiable, Codable {
    let id: UUID
    let testNumber: Int
    let startTime: Date
    var endTime: Date
    var duration: TimeInterval
    var isSuccess: Bool
    var errorMessage: String?
    let deviceName: String
    let fileName: String
    var disconnectedCount: Int
    
    var durationFormatted: String {
        String(format: "%.2fs", duration)
    }
}

// 压力测试统计
struct StressTestStats: Codable {
    var totalTests: Int = 0                     // 总次数
    var successfulTests: Int = 0                // 成功次数
    var failedTests: Int = 0                    // 失败次数
    var totalDuration: TimeInterval = 0         // 总耗时
    var averageDuration: TimeInterval = 0       // 平均耗时
    var minDuration: TimeInterval = .infinity   //最小耗时
    var maxDuration: TimeInterval = 0           //最大耗时
    var totalDisconnections: Int = 0            //总断连次数
    var startTime: Date?                        //开始时间
    var endTime: Date?                          //结束时间
    
    // 各文件的统计
    var fileStats: [String: FileStat] = [:]
    
    // 成功率
    var successRate: Double {
        guard totalTests > 0 else { return 0 }
        return Double(successfulTests) / Double(totalTests) * 100
    }
    
    var totalTimeFormatted: String {
        if totalDuration < 60 {
            return String(format: "%.1f秒", totalDuration)
        } else {
            let minutes = Int(totalDuration) / 60
            let seconds = totalDuration.truncatingRemainder(dividingBy: 60)
            return String(format: "%d分%.1f秒", minutes, seconds)
        }
    }
    
    var formattedSummary: String {
            var summary = """
            测试统计摘要:
            - 总测试次数: \(totalTests)
            - 成功次数: \(successfulTests)
            - 失败次数: \(failedTests)
            - 成功率: \(String(format: "%.2f", successRate))%
            - 总耗时: \(totalTimeFormatted)
            - 平均耗时: \(String(format: "%.2f秒", averageDuration))
            - 最短耗时: \(String(format: "%.2f秒", minDuration == .infinity ? 0 : minDuration))
            - 最长耗时: \(String(format: "%.2f秒", maxDuration))
            - 总断开次数: \(totalDisconnections)
            """
            
            if !fileStats.isEmpty {
                summary += "\n\n文件统计:"
                for (fileName, stat) in fileStats.sorted(by: { $0.key < $1.key }) {
                    summary += "\n  \(fileName): \(stat.successfulTests)/\(stat.totalTests) 成功 (\(String(format: "%.1f", stat.successRate))%)"
                }
            }
            
            return summary
        }
}

// 文件统计
struct FileStat: Codable {
    var fileName: String
    var totalTests: Int = 0
    var successfulTests: Int = 0
    var failedTests: Int = 0
    
    var successRate: Double {
        guard totalTests > 0 else { return 0 }
        return Double(successfulTests) / Double(totalTests) * 100
    }
}

// 压力测试配置
struct StressTestConfig: Codable {
    var maxIterations: Int = 10 {
        didSet {
            // 限制最大次数为10万次
            if maxIterations > 100000 {
                maxIterations = 100000
            }
        }
    }
}

// 压力测试管理器
class StressTestManager: ObservableObject {
    @Published var testResults: [TestResult] = []
    @Published var currentStats = StressTestStats()
    @Published var currentConfig = StressTestConfig()
    @Published var isTesting = false
    @Published var currentTestNumber = 0        //当前测试第几次
    @Published var currentTestStatus = ""       //状态信息显示
    @Published var currentTestProgress: Float = 0.0     //进度条
    @Published var currentTestDeviceName: String = ""   //测试设备名称
    @Published var currentTestFileName: String = ""     //当前测试文件
    @Published var testIterationsCompleted: Int = 0     //已完成多少次
    
    
    // 压力测试相关属性
    private weak var bluetoothManager: BluetoothManager?
    private var filesManager: OTAFileManager?
    
    
    // 当前测试设备
    private(set) var testDeviceAppUUID: String?    //测试设备的UUID
    private(set) var testDeviceOTAUUID: String?
    
    private var singleTest: TestResult?
    private var isSingleBankOTA = true
    private var deviceAppMAc: String = ""
    private var isOTAEndScanDevice = false
    
    init() {
        loadSavedData()
    }
    
    // 加载测试结果
    private func loadSavedData() {
        // 加载测试结果
        if let data = UserDefaults.standard.data(forKey: "stress_test_results") {
            do {
                let decoder = JSONDecoder()
                testResults = try decoder.decode([TestResult].self, from: data)
                
                print("加载 \(testResults.count) 条历史测试记录")
            } catch {
                print("加载测试结果失败: \(error)")
            }
        }
        
        // 加载配置
        if let data = UserDefaults.standard.data(forKey: "stress_test_config") {
            do {
                let decoder = JSONDecoder()
                currentConfig = try decoder.decode(StressTestConfig.self, from: data)
            } catch {
                print("加载测试配置失败: \(error)")
            }
        }
        
        // 加载统计数据
        if let data = UserDefaults.standard.data(forKey: "stress_test_stats") {
            do {
                let decoder = JSONDecoder()
                currentStats = try decoder.decode(StressTestStats.self, from: data)
            } catch {
                print("加载统计信息失败: \(error)")
            }
        }
        
    }
    
    // 设置依赖
    func setupDependencies(bluetoothManager: BluetoothManager, filesManager: OTAFileManager) {
        self.bluetoothManager = bluetoothManager
        self.filesManager = filesManager
    }
    
   
    // 开始压力测试 - 只使用第一个设备
    func startStressTest() {
        guard let bluetoothManager = bluetoothManager,
              !bluetoothManager.selectedDevices.isEmpty,
              !isTesting else {
            print("压力测试条件不满足")
            return
        }
        
        // 准备测试文件
        guard prepareTestFiles() else {
            print("没有可用的测试文件")
            return
        }
        
        // 只取第一个设备作为测试设备
        let firstDevice = bluetoothManager.selectedDevices.first!
        testDeviceAppUUID = firstDevice.peripheral.identifier.uuidString
        testDeviceOTAUUID = nil;
        // 通知蓝牙管理器开始压力测试模式
        bluetoothManager.setStressTestDevice(testDeviceAppUUID!)
        
        currentTestDeviceName = firstDevice.realName
       
        
        currentTestProgress = 0.0
        
        let maxIterations = currentConfig.maxIterations
        print("开始压力测试 - 设备: \(currentTestDeviceName), 总测试次数: \(maxIterations)")
        currentTestNumber = 1       //当前测试第几次
        testIterationsCompleted = 0 //已完成多少次
        
        isTesting = true
        newSingleOTATest()
        
        currentStats = StressTestStats()
        currentStats.startTime = singleTest?.startTime
        
        testResults = []
    }
    
    // 准备测试文件列表
    private func prepareTestFiles() -> Bool {
        guard let filesManager = filesManager else { return false }
        let selectedFiles = filesManager.selectedFiles
        if selectedFiles.isEmpty {
            print("没有选择升级文件")
            return false
        }
        
        isSingleBankOTA = !filesManager.selectedFiles[0].fileAbsolutePath.hasSuffix("bin")
        return true
    }
    
    private func newSingleOTATest() {
        let file = filesManager!.selectedFiles[currentTestNumber%filesManager!.selectedFiles.count]
        let fileName = file.fileName
        
        currentTestFileName = fileName
        
        let maxIterations = currentConfig.maxIterations
        currentTestStatus = "开始第 \(currentTestNumber)/\(maxIterations) 次升级测试 - 文件: \(fileName)"
        currentTestProgress = Float(currentTestNumber - 1) / Float(maxIterations)
        
        singleTest = TestResult(
            id: UUID(),
            testNumber: currentTestNumber,
            startTime: Date(),
            endTime: Date(),
            duration: 0,
            isSuccess: true,
            errorMessage: nil,
            deviceName: currentTestDeviceName,
            fileName: fileName,
            disconnectedCount: 0
        )
        
        print("设备: \(currentTestDeviceName)，开始第 \(currentTestNumber) 次测试，使用文件 \(fileName)")
        bluetoothManager!.startOTA(with: file.fileAbsolutePath)
    }
    
    func listenNotify(_ peripheral: CBPeripheral, message: String, code: UInt) {
        if peripheral.identifier.uuidString == testDeviceAppUUID || peripheral.identifier.uuidString == testDeviceOTAUUID {
            currentTestStatus = message
            if code == OTASwiftConstants.OTASuccessReboot {
                if let device = bluetoothManager!.devices.first(where: {
                    $0.peripheral.identifier.uuidString == testDeviceOTAUUID
                }) {
                    singleTest!.disconnectedCount = Int(device.disconnectTimes)
                }else if !isSingleBankOTA,let device = bluetoothManager!.devices.first(where: {
                    $0.peripheral.identifier.uuidString == testDeviceAppUUID
                }) {
                    singleTest!.disconnectedCount = Int(device.disconnectTimes)
                }
                endSingleOTATest(isSuccess: true)
            }else if isOTAFailureStatus(code) {
                if code == OTASwiftConstants.MAXDisconnectedTime {
                    singleTest!.disconnectedCount = 4;
                }
                singleTest!.errorMessage = message
                endSingleOTATest(isSuccess: false)
            }else if code == OTASwiftConstants.ProgressCallBack {
                
            }else if code == OTASwiftConstants.SBKAppModeOver {
                if let device = bluetoothManager!.devices.first(where: {
                    $0.peripheral.identifier.uuidString == testDeviceAppUUID
                }) {
                    deviceAppMAc = device.adverMacAddr
                }
            }
        } else if testDeviceOTAUUID == nil ,code == OTASwiftConstants.DeviceConnecting {
            testDeviceOTAUUID = peripheral.identifier.uuidString
        }
    }
    
    private func endSingleOTATest(isSuccess : Bool) {
        singleTest!.isSuccess = isSuccess
        self.currentTestStatus = "测试设备 重启中..."
        // 启动扫描
        isOTAEndScanDevice = true
        print("endSingleOTATest 开始扫描")
        bluetoothManager!.startScan()
    }
    
    func deviceFound(_ devicesArray: [PHYBLEModel]) {
        if !isOTAEndScanDevice {
            return
        }
        // 获取原始设备信息（用于MAC地址匹配）
        if devicesArray.first(where: { $0.peripheral.identifier.uuidString == testDeviceAppUUID }) != nil {
            bluetoothManager!.setStressTestDevice(testDeviceAppUUID!)
            saveAndNextSingle()
            return
        }
        
        // 检查设备是否在扫描列表中
        var foundDeviceModel: PHYBLEModel? = nil
        
        // 尝试通过MAC地址匹配（设备进入OTA模式后MAC地址可能+1）
        foundDeviceModel = bluetoothManager!.devices.first(where: { scannedDevice in
            let otaMAC = scannedDevice.adverMacAddr
            if otaMAC.isEmpty {
                return false
            }
            return compareMACAddresses(appMAC: deviceAppMAc, otaMAC: otaMAC, checkByte: 0)
        })
        
        
        if let deviceModel = foundDeviceModel {
            print("✅ 设备重新扫描成功: \(deviceModel.realName) - MAC: \(deviceModel.adverMacAddr)")
            // 如果找到的设备UUID与原始UUID不同，更新测试设备UUID
            if deviceModel.peripheral.identifier.uuidString != testDeviceAppUUID {
                print("⚠️ 设备UUID已改变，从 \(String(describing: testDeviceAppUUID)) 更新为 \(deviceModel.peripheral.identifier.uuidString)")
                // 更新压力测试管理器中的设备UUID
               
                self.testDeviceOTAUUID = deviceModel.peripheral.identifier.uuidString
                // 更新蓝牙管理器中的设备选择
                bluetoothManager!.setStressTestDevice(deviceModel.peripheral.identifier.uuidString)
            }
            saveAndNextSingle()
        }
    }
    
    private func saveAndNextSingle() {
        saveSingleData()
        let maxIterations = currentConfig.maxIterations
        if currentTestNumber < maxIterations {
            currentTestNumber += 1
            newSingleOTATest()
        }else {
            endStressTest()
        }
    }
    
    private func saveSingleData() {
        bluetoothManager!.stopScan()
        isOTAEndScanDevice = false
        singleTest!.endTime = Date()
        singleTest!.duration = singleTest!.endTime.timeIntervalSince(singleTest!.startTime)
        
        // 更新统计
        testResults.insert(singleTest!, at: 0)
        updateStats(with: singleTest!)

        testIterationsCompleted += 1
        print("当前断开连接次数：\(singleTest!.disconnectedCount)")
        // 每次测试结果后立即保存到持久化存储
        saveTestResults()
    }
    
    // 保存测试结果
    public func saveTestResults() {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            
            // 保存当前测试结果
            let data = try encoder.encode(testResults)
            UserDefaults.standard.set(data, forKey: "stress_test_results")
            
            // 保存配置
            let configData = try encoder.encode(currentConfig)
            UserDefaults.standard.set(configData, forKey: "stress_test_config")
            
            // 保存统计数据（保存累计的统计数据）
            let statsData = try encoder.encode(currentStats)
            UserDefaults.standard.set(statsData, forKey: "stress_test_stats")
            
            print("测试结果已保存")
        } catch {
            print("保存测试结果失败: \(error)")
        }
    }
    
    private func endStressTest() {
        isTesting = false
        currentTestProgress = 1.0
        currentTestStatus = "本次测试已结束"
        currentStats.endTime = singleTest!.endTime
        
        // 保存到持久化存储
        saveTestResults()
    }
    
    // 判断是否为OTA失败状态
    private func isOTAFailureStatus(_ statusCode: UInt) -> Bool {
        let failureStatuses: [UInt] = [
            OTASwiftConstants.OTAFailed,
            OTASwiftConstants.MAXDisconnectedTime,
            OTASwiftConstants.DeviceConnectFail,
            OTASwiftConstants.DeviceErrorCode
        ]
        return failureStatuses.contains(statusCode)
    }
    
    // 停止压力测试
    func stopStressTest() {
        
        isTesting = false
        currentStats.endTime = Date()
        
        // 保存到持久化存储
        saveTestResults()
        
        bluetoothManager!.stopOTA()
        print("压力测试已停止")
    }
    
    // 更新统计信息
    private func updateStats(with result: TestResult) {
        currentStats.totalTests += 1
        if result.isSuccess {
            currentStats.successfulTests += 1
        } else {
            currentStats.failedTests += 1
        }
        
        currentStats.totalDuration += result.duration
        currentStats.averageDuration = currentStats.totalDuration / Double(currentStats.totalTests)
        currentStats.minDuration = min(currentStats.minDuration, result.duration)
        currentStats.maxDuration = max(currentStats.maxDuration, result.duration)
        currentStats.totalDisconnections += result.disconnectedCount
        
        // 更新文件统计
        let fileName = currentTestFileName

        // 更新 currentStats 的文件统计
        if currentStats.fileStats[fileName] == nil {
            currentStats.fileStats[fileName] = FileStat(fileName: fileName)
        }
        currentStats.fileStats[fileName]?.totalTests += 1
        if result.isSuccess {
            currentStats.fileStats[fileName]?.successfulTests += 1
        } else {
            currentStats.fileStats[fileName]?.failedTests += 1
        }
    }
    
    // 导出测试报告
    func exportTestReport() -> String {
        
        var report = "====== OTA压力测试报告 ======\n"
        report += "生成时间: \(DateFormatter.localizedString(from: Date(), dateStyle: .medium, timeStyle: .medium))\n"
        report += String(repeating: "=", count: 50) + "\n\n"
        
        // 修复：判断测试记录是否为空，为空直接返回无数据报告
        guard !testResults.isEmpty else {
            report += "❌ 暂无任何测试记录，无法生成详细报告\n"
            report += "\n" + String(repeating: "=", count: 50) + "\n"
            report += "报告生成完毕\n"
            return report
        }
        
        // 使用保存的数据，而不是当前可能被清空的数据
        report += "测试设备: \(testResults.first!.deviceName)\n"
        report += "测试文件数: \(currentStats.fileStats.keys.count)\n"
        report += "测试开始时间: \(formatDate(currentStats.startTime))\n"
        report += "测试结束时间: \(formatDate(currentStats.endTime))\n\n"
        
        report += "测试配置:\n"
        report += "  最大迭代次数: \(currentConfig.maxIterations)\n\n"
        
        
        report += currentStats.formattedSummary + "\n\n"
        
        // 详细测试记录（全部）
        if !testResults.isEmpty {
            report += "【详细测试记录】\n"
            report += String(repeating: "-", count: 40) + "\n"
            
            // 按测试编号升序排列（从第一次到最后一次）
            let sortedResults = testResults.sorted { $0.testNumber < $1.testNumber }
            
            for result in sortedResults {
                // 测试编号和状态
                report += "测试 #\(result.testNumber): "
                report += result.isSuccess ? "✓ 成功" : "✗ 失败"
                report += " | 耗时: \(result.durationFormatted)"
                report += " | 文件: \(result.fileName)"
                report += "\n"
                
                // 时间信息
                report += "   开始时间: \(formatDate(result.startTime))\n"
                report += "   结束时间: \(formatDate(result.endTime))\n"
                
                // 错误信息（如果失败）
                if !result.isSuccess, let error = result.errorMessage, !error.isEmpty {
                    report += "   错误信息: \(error)\n"
                }
                
                // 断开次数（如果有）
                if result.disconnectedCount > 0 {
                    report += "   断开次数: \(result.disconnectedCount)次\n"
                }
                
                report += "\n"
            }
            
            // 添加测试摘要
            report += "【测试摘要】\n"
            let successCount = testResults.filter { $0.isSuccess }.count
            let failureCount = testResults.filter { !$0.isSuccess }.count
            report += "总测试次数: \(testResults.count)\n"
            report += "成功次数: \(successCount)\n"
            report += "失败次数: \(failureCount)\n"
            
            // 失败原因统计
            let failures = testResults.filter { !$0.isSuccess }
            if !failures.isEmpty {
                report += "\n失败原因分析:\n"
                var failureReasons: [String: Int] = [:]
                for failure in failures {
                    let reason = failure.errorMessage ?? "未知错误"
                    failureReasons[reason] = (failureReasons[reason] ?? 0) + 1
                }
                for (reason, count) in failureReasons.sorted(by: { $0.value > $1.value }) {
                    let percentage = Double(count) / Double(failures.count) * 100
                    report += "  - \(reason): \(count)次 (\(String(format: "%.1f", percentage))%)\n"
                }
            }
        } else {
            report += "【详细测试记录】\n"
            report += "暂无测试记录\n\n"
        }
        
        report += "\n" + String(repeating: "=", count: 50) + "\n"
        report += "报告生成完毕\n"
        
        return report
    }
    
    // 清空测试记录
    func clearTestResults() {
        testResults.removeAll()
        
        currentStats = StressTestStats()
        
        saveTestResults()
        print("测试记录已清空")
    }
    
    private func formatDate(_ date: Date?) -> String {
        guard let date = date else { return "未开始" }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: date)
    }

    // 比较App MAC地址和OTA MAC地址（基于JCDataConvert.compareAppMAc的Swift实现）
    private func compareMACAddresses(appMAC: String, otaMAC: String, checkByte: UInt) -> Bool {
        guard appMAC.count == 17, otaMAC.count == 17 else {
            return false
        }

        // 计算bytePosition（与Objective-C代码一致）
        let bytePosition = 15 - 3 * Int(checkByte)
        guard bytePosition >= 0, bytePosition + 2 <= appMAC.count else {
            return false
        }

        // 提取第一部分
        let firstBytes = String(appMAC.prefix(bytePosition))

        // 提取中间两个字符（十六进制值）
        let startIndex = appMAC.index(appMAC.startIndex, offsetBy: bytePosition)
        let endIndex = appMAC.index(startIndex, offsetBy: 2)
        let substring = String(appMAC[startIndex..<endIndex])

        // 将十六进制字符串转换为UInt8，加1，然后与0xFF进行AND操作
        guard let value = UInt8(substring, radix: 16) else {
            return false
        }
        let newValue = (value + 1) & 0xFF
        let midBytes = String(format: "%02X", newValue)

        // 提取剩余部分
        let lastByte = String(appMAC.suffix(from: endIndex))

        // 构建新的MAC地址字符串
        let newStr = firstBytes + midBytes + lastByte

        return newStr.uppercased() == otaMAC.uppercased()
    }
}
