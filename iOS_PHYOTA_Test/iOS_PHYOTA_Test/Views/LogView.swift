//
//  LogView.swift
//  iOS_PHYOTA_Test
//
//  Created by di lu on 2026/1/26.
//

import SwiftUI

struct LogView: View {
    @EnvironmentObject var bluetoothManager: BluetoothManager
    @State private var searchText = ""
    @State private var showingClearAlert = false
    
    var filteredLogs: [LogEntry] {
        if searchText.isEmpty {
            return bluetoothManager.logManager.logs
        } else {
            return bluetoothManager.logManager.logs.filter {
                $0.message.localizedCaseInsensitiveContains(searchText) ||
                $0.source.localizedCaseInsensitiveContains(searchText) ||
                ($0.deviceName?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 搜索栏
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                
                TextField("搜索日志...", text: $searchText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
            .padding()
            .background(Color(.systemBackground))
            
            // 统计信息
            HStack {
                VStack(alignment: .leading) {
                    Text("总日志数: \(bluetoothManager.logManager.logs.count)")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                if !searchText.isEmpty {
                    Text("找到 \(filteredLogs.count) 条")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(.systemGray6))
            
            // 日志列表
            if filteredLogs.isEmpty {
                EmptyStateView(
                    icon: "doc.text.magnifyingglass",
                    title: "暂无日志",
                    message: searchText.isEmpty ?
                        "开始BLE交互后日志将显示在这里" :
                        "没有找到匹配的日志"
                )
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(filteredLogs) { log in
                                LogEntryView(entry: log)
                                    .id(log.id)
                                    .padding(.vertical, 4)
                                    .padding(.horizontal)
                            }
                        }
                        .padding(.top, 8)
                    }
                    .onAppear {
                        if let firstLog = filteredLogs.first {
                            proxy.scrollTo(firstLog.id, anchor: .top)
                        }
                    }
                }
            }
        }
        .navigationTitle("交互日志")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Button(action: { showingClearAlert = true }) {
                    Image(systemName: "trash")
                }
                .alert(isPresented: $showingClearAlert) {
                    Alert(
                        title: Text("清空日志"),
                        message: Text("确定要清空所有日志记录吗？此操作不可撤销。\n当前日志数：\(bluetoothManager.logManager.logs.count)"),
                        primaryButton: .destructive(Text("清空")) {
                            bluetoothManager.logManager.clearLogs()
                        },
                        secondaryButton: .cancel()
                    )
                }
            }
        }
    }
    
}

// 日志条目视图
struct LogEntryView: View {
    let entry: LogEntry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                // 日志级别标签
                Text(entry.level.rawValue)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(levelColor.opacity(0.2))
                    .foregroundColor(levelColor)
                    .cornerRadius(4)
                
                // 时间戳
                Text(entry.formattedTimestamp)
                    .font(.caption2)
                    .foregroundColor(.gray)
                
                Spacer()
                
                // 来源
                Text(entry.source)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // 设备信息
            if let deviceName = entry.deviceName {
                HStack {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .font(.caption2)
                        .foregroundColor(.blue)
                    
                    Text(deviceName)
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
            
            // 消息内容
            Text(entry.message)
                .font(.caption)
                .foregroundColor(.primary)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(backgroundColor)
        )
    }
    
    private var levelColor: Color {
        switch entry.level {
        case .debug: return .gray
        case .info: return .blue
        case .warning: return .orange
        case .error: return .red
        case .critical: return .purple
        }
    }
    
    private var backgroundColor: Color {
        Color(.systemBackground)
            .opacity(0.9)
    }
}

// 空状态视图
struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 50))
                .foregroundColor(.gray.opacity(0.5))
            
            Text(title)
                .font(.headline)
                .foregroundColor(.gray)
            
            Text(message)
                .font(.caption)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// 日志级别
enum LogLevel: String, Codable {
    case debug = "DEBUG"
    case info = "INFO"
    case warning = "WARNING"
    case error = "ERROR"
    case critical = "CRITICAL"
}

// 日志条目
struct LogEntry: Identifiable, Codable {
    let id: UUID
    let timestamp: Date
    let level: LogLevel
    let source: String
    let message: String
    let deviceID: String?
    let deviceName: String?
    
    init(id: UUID = UUID(), timestamp: Date = Date(), level: LogLevel,
         source: String, message: String, deviceID: String? = nil, deviceName: String? = nil) {
        self.id = id
        self.timestamp = timestamp
        self.level = level
        self.source = source
        self.message = message
        self.deviceID = deviceID
        self.deviceName = deviceName
    }
    
    var formattedTimestamp: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter.string(from: timestamp)
    }
}
