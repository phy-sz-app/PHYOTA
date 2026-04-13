//
//  LogManager.swift
//  iOS_PHYOTA_Test
//
//  Created by di lu on 2026/2/28.
//

import Foundation
import Combine


// 交互日志管理器
class LogManager: ObservableObject {
    @Published var logs: [LogEntry] = []
    private let maxLogCount = 2000
    
    init() {
        // 加载之前保存的日志
        loadLogs()
    }
    
    // 添加日志
    func addLog(level: LogLevel, source: String, message: String, deviceID: String? = nil, deviceName: String? = nil) {
        let entry = LogEntry(level: level, source: source, message: message,
                             deviceID: deviceID, deviceName: deviceName)
        
        DispatchQueue.main.async {
            self.logs.insert(entry, at: 0)
            
            // 限制日志数量
            if self.logs.count > self.maxLogCount {
                self.logs.removeLast(self.logs.count - self.maxLogCount)
            }
            
            // 保存到持久化存储
            self.saveLogs()
        }
    }
    
    // 添加BLE交互日志
    func addBLELog(level: LogLevel, message: String, peripheral: CBPeripheral? = nil) {
        let deviceID = peripheral?.identifier.uuidString
        let deviceName = peripheral?.name ?? peripheral?.identifier.uuidString
        addLog(level: level, source: "BLE", message: message,
               deviceID: deviceID, deviceName: deviceName)
    }
    
    // 清空日志
    func clearLogs() {
        logs.removeAll()
        saveLogs()
    }
    
    // 保存日志到UserDefaults
    private func saveLogs() {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(Array(logs.prefix(maxLogCount)))
            UserDefaults.standard.set(data, forKey: "ble_interaction_logs")
        } catch {
            print("保存日志失败: \(error)")
        }
    }
    
    // 从UserDefaults加载日志
    private func loadLogs() {
        guard let data = UserDefaults.standard.data(forKey: "ble_interaction_logs") else { return }
        
        do {
            let decoder = JSONDecoder()
            let loadedLogs = try decoder.decode([LogEntry].self, from: data)
            logs = loadedLogs
        } catch {
            print("加载日志失败: \(error)")
        }
    }
    
    // 导出日志为文本
    func exportLogs() -> String {
        var exportText = "BLE交互日志\n"
        exportText += "导出时间: \(Date())\n"
        exportText += "=" * 40 + "\n\n"
        
        for log in logs.sorted(by: { $0.timestamp < $1.timestamp }) {
            let deviceInfo = log.deviceName != nil ? "[\(log.deviceName!)]" : ""
            exportText += "[\(log.formattedTimestamp)] [\(log.level.rawValue)] \(deviceInfo) \(log.source): \(log.message)\n"
        }
        
        return exportText
    }
}

// 字符串重复运算符
extension String {
    static func *(left: String, right: Int) -> String {
        return String(repeating: left, count: right)
    }
}
