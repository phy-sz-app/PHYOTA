//
//  BurnInOTAView.swift
//  iOS_PHYOTA_Test
//
//  Created by di lu on 2026/4/9.
//

import SwiftUI

struct BurnInOTAView: View {
    @EnvironmentObject var bluetoothManager: BluetoothManager
    
    @State private var showingRuleSheet = false
    
    var body: some View {
        VStack(spacing: 0) {
            // 状态卡片
            statusCard
            
            // 当前使用文件
            currentFileSection
            
            // 规则摘要
            ruleSummarySection
            
            // 设备列表
            deviceListSection
            
            // 底部按钮
            bottomButton
        }
        .navigationTitle("烧录式OTA")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showingRuleSheet = true }) {
                    Image(systemName: "slider.horizontal.3")
                }
            }
        }
        .sheet(isPresented: $showingRuleSheet) {
            BurnInRuleSheet(manager: bluetoothManager.burnInManager)
        }
        .onDisappear {
            if bluetoothManager.burnInManager.state != .idle && bluetoothManager.burnInManager.state != .completed {
                bluetoothManager.burnInManager.stopBurnIn()
            }
        }
    }
    
    // 状态卡片
    private var statusCard: some View {
        VStack(spacing: 12) {
            // 状态图标
            ZStack {
                Circle()
                    .fill(statusColor.opacity(0.15))
                    .frame(width: 60, height: 60)
                
                Image(systemName: statusIcon)
                    .font(.system(size: 28))
                    .foregroundColor(statusColor)
            }
            
            // 状态文字
            Text(bluetoothManager.burnInManager.stateMessage)
                .font(.headline)
                .multilineTextAlignment(.center)
            
            // 进度信息
            if bluetoothManager.burnInManager.state == .scanning {
                HStack(spacing: 20) {
                    Label("第\(bluetoothManager.burnInManager.currentScanCount)轮", systemImage: "arrow.triangle.2.circlepath")
                    Label("\(bluetoothManager.burnInManager.scanTimeRemaining)秒", systemImage: "timer")
                }
                .font(.subheadline)
                .foregroundColor(.secondary)
            }
            
            if bluetoothManager.burnInManager.state == .upgrading || bluetoothManager.burnInManager.state == .waitingForReboot {
                HStack(spacing: 20) {
                    Label("已升级\(bluetoothManager.burnInManager.totalUpgradedCount)个", systemImage: "checkmark.circle")
                }
                .font(.subheadline)
                .foregroundColor(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(.systemBackground))
    }
    
    // 当前使用文件
    private var currentFileSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("升级文件")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding(.horizontal)
            
            if let selectedFile = bluetoothManager.burnInManager.getFirstFile() {
                HStack {
                    Image(systemName: "doc.fill")
                        .foregroundColor(.blue)
                    Text(selectedFile.fileName)
                        .font(.caption)
                    Spacer()
                    Text(formatFileSize(selectedFile.fileSize))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
                .padding(.horizontal)
            } else {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text("请先在主页面选择升级文件")
                        .font(.caption)
                        .foregroundColor(.orange)
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(8)
                .padding(.horizontal)
            }
        }
        .padding(.vertical, 8)
        .background(Color(.secondarySystemBackground))
    }
    
    // 规则摘要
    private var ruleSummarySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("蓝牙名前缀：\(bluetoothManager.burnInManager.rule.namePrefix.isEmpty ? "空" : bluetoothManager.burnInManager.rule.namePrefix)", systemImage: "tag")
            Label("信号强度 ≥\(bluetoothManager.burnInManager.rule.minRSSI)dBm", systemImage: "antenna.radiowaves.left.and.right")
            Label("扫描\(bluetoothManager.burnInManager.rule.scanDuration)秒", systemImage: "clock")
        }
        .font(.caption)
        .foregroundColor(.secondary)
        .padding(.vertical, 8)
    }
    
    // 设备列表
    private var deviceListSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            if bluetoothManager.burnInManager.state == .scanning && !bluetoothManager.burnInManager.discoveredDevices.isEmpty {
                HStack {
                    Text("发现设备")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(bluetoothManager.burnInManager.discoveredDevices.count)个")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
            }
            
            if bluetoothManager.burnInManager.discoveredDevices.isEmpty && bluetoothManager.burnInManager.upgradedDevices.isEmpty {
                emptyDeviceView
            } else {
                List {
                    // 当前扫描发现的设备
                    if !bluetoothManager.burnInManager.discoveredDevices.isEmpty {
                        Section(header: Text("当前扫描发现")) {
                            ForEach(bluetoothManager.burnInManager.discoveredDevices) { device in
                                deviceRow(device)
                            }
                        }
                    }
                    
                    // 已升级设备
                    if !bluetoothManager.burnInManager.upgradedDevices.isEmpty {
                        Section(header: Text("已升级设备 (\(bluetoothManager.burnInManager.upgradedDevices.count))")) {
                            ForEach(bluetoothManager.burnInManager.upgradedDevices) { device in
                                upgradedDeviceRow(device)
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
    }
    
    private var emptyDeviceView: some View {
        VStack(spacing: 12) {
            Image(systemName: "wifi.slash")
                .font(.system(size: 40))
                .foregroundColor(.gray.opacity(0.5))
            
            if bluetoothManager.burnInManager.state == .scanning {
                Text("扫描中...")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else if bluetoothManager.burnInManager.state == .idle {
                Text("点击开始按钮开始烧录")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                Text("暂无设备")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 60)
    }
    
    private func deviceRow(_ device: BurnInDeviceInfo) -> some View {
        HStack {
            // 信号强度图标
            Image(systemName: rssiIcon(device.rssi))
                .foregroundColor(rssiColor(device.rssi))
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(device.name)
                    .font(.subheadline)
                if !device.mac.isEmpty {
                    Text(device.mac)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Text("\(device.rssi) dBm")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
    
    private func upgradedDeviceRow(_ device: BurnInDeviceInfo) -> some View {
        HStack {
            Image(systemName: device.upgradeSuccess ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(device.upgradeSuccess ? .green : .red)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(device.name)
                    .font(.subheadline)
                if let reason = device.failReason {
                    Text(reason)
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
            
            Spacer()
            
            Text(device.upgradeSuccess ? "成功" : "失败")
                .font(.caption)
                .foregroundColor(device.upgradeSuccess ? .green : .red)
        }
        .padding(.vertical, 4)
    }
    
    private var bottomButton: some View {
        VStack(spacing: 8) {
            if bluetoothManager.burnInManager.state == .completed {
                HStack(spacing: 12) {
                    Button(action: { bluetoothManager.burnInManager.startBurnIn() }) {
                        Label("重新开始", systemImage: "arrow.clockwise")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    
                    Button(action: { bluetoothManager.burnInManager.state = .idle }) {
                        Label("完成", systemImage: "checkmark")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
            } else if bluetoothManager.burnInManager.state == .idle {
                Button(action: { bluetoothManager.burnInManager.startBurnIn() }) {
                    Label("开始烧录", systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
                .disabled(bluetoothManager.burnInManager.getFirstFile() == nil)
            } else if bluetoothManager.burnInManager.state != .idle {
                Button(action: { bluetoothManager.burnInManager.stopBurnIn() }) {
                    Label("停止烧录", systemImage: "stop.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
            }
        }
        .padding()
        .background(Color(.systemBackground))
    }
    
    private var statusColor: Color {
        switch bluetoothManager.burnInManager.state {
        case .idle: return .gray
        case .scanning: return .blue
        case .upgrading: return .orange
        case .waitingForReboot: return .purple
        case .completed: return .green
        case .failed: return .red
        }
    }
    
    private var statusIcon: String {
        switch bluetoothManager.burnInManager.state {
        case .idle: return "play.circle"
        case .scanning: return "magnifyingglass"
        case .upgrading: return "arrow.up.circle"
        case .waitingForReboot: return "arrow.clockwise.circle"
        case .completed: return "checkmark.circle"
        case .failed: return "exclamationmark.circle"
        }
    }
    
    private func rssiIcon(_ rssi: Int) -> String {
        if rssi > -60 { return "wifi" }
        if rssi > -70 { return "wifi" }
        return "wifi.exclamationmark"
    }
    
    private func rssiColor(_ rssi: Int) -> Color {
        if rssi > -60 { return .green }
        if rssi > -70 { return .orange }
        return .red
    }
    
    private func formatFileSize(_ size: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(size))
    }
}

// 规则配置弹窗
struct BurnInRuleSheet: View {
    @ObservedObject var manager: BurnInOTAManager
    @Environment(\.dismiss) private var dismiss
    @State private var namePrefix: String = ""
    @State private var minRSSI: String = ""
    @State private var scanDuration: String = ""
    @State private var maxEmptyScanCount: String = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("设备筛选规则")) {
                    HStack {
                        Text("名称前缀")
                        Spacer()
                        TextField("留空则不筛选", text: $namePrefix)
                            .multilineTextAlignment(.trailing)
                            .autocapitalization(.none)
                    }
                    
                    HStack {
                        Text("最小信号强度")
                        Spacer()
                        TextField("-70", text: $minRSSI)
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.numbersAndPunctuation)
                        Text("dBm")
                            .foregroundColor(.secondary)
                    }
                }
                
                Section(header: Text("扫描设置")) {
                    HStack {
                        Text("扫描时长")
                        Spacer()
                        TextField("15", text: $scanDuration)
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.numberPad)
                        Text("秒")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("最大空扫描次数")
                        Spacer()
                        TextField("4", text: $maxEmptyScanCount)
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.numberPad)
                        Text("次")
                            .foregroundColor(.secondary)
                    }
                }
                
                Section(footer: Text("连续扫描设定次数后仍未发现设备时，自动停止烧录")) {
                    EmptyView()
                }
            }
            .navigationTitle("烧录规则")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        saveRule()
                        dismiss()
                    }
                    .font(.system(size: 16, weight: .medium))
                }
            }
            .onAppear {
                loadRule()
            }
        }
    }
    
    private func loadRule() {
        namePrefix = manager.rule.namePrefix
        minRSSI = String(manager.rule.minRSSI)
        scanDuration = String(manager.rule.scanDuration)
        maxEmptyScanCount = String(manager.rule.maxEmptyScanCount)
    }
    
    private func saveRule() {
        manager.rule.namePrefix = namePrefix.trimmingCharacters(in: .whitespaces)
        manager.rule.minRSSI = Int(minRSSI) ?? -70
        manager.rule.scanDuration = Int(scanDuration) ?? 15
        manager.rule.maxEmptyScanCount = Int(maxEmptyScanCount) ?? 4
        manager.saveRule()
    }
}


