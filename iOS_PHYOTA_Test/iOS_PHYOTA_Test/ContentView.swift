//
//  ContentView.swift
//  iOS_PHYOTA_Test
//
//  Created by di lu on 2026/1/16.
//

import SwiftUI
import CoreBluetooth

struct ContentView: View {
    @EnvironmentObject var bluetoothManager: BluetoothManager
    @EnvironmentObject var fileManager: OTAFileManager
    
    @State private var showingFileSelection = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 顶部状态栏
                StatusHeaderView()
                    .padding(.bottom, 8)
                
                // 文件选择和升级按钮区域
                ControlButtonsView(showingFileSelection: $showingFileSelection)
                    .padding(.horizontal)
                    .padding(.bottom, 12)
                
                // 选择的文件显示区域（有文件时才显示）
                if !fileManager.selectedFiles.isEmpty {
                    SelectedFilesView()
                        .padding(.horizontal)
                        .padding(.bottom, 12)
                }
                
                // 设备列表区域
                DeviceListView()
                    .animation(.easeInOut, value: bluetoothManager.isInOTAMode)
                
                Spacer()
            }
            .navigationTitle("OTA测试")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    NavigationLink(destination: SettingsView()) {
                        Image(systemName: "gear")
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    ScanButtonView()
                }
            }
            .background(
                NavigationLink(
                    destination: FileSelectionView(isPresented: $showingFileSelection),
                    isActive: $showingFileSelection,
                    label: { EmptyView() }
                )
            )
        }
    }
}

// 顶部状态栏
struct StatusHeaderView: View {
    @EnvironmentObject var bluetoothManager: BluetoothManager
    
    var body: some View {
        HStack(spacing: 12) {
            // 状态指示灯
            Circle()
                .fill(bluetoothManager.isInOTAMode ? Color.orange : (bluetoothManager.isScanning ? Color.green : Color.red))
                .frame(width: 10, height: 10)
            
            // 状态消息
            Text(bluetoothManager.message)
                .font(.caption)
                .foregroundColor(.gray)
                .lineLimit(2)
                .padding(.vertical, 2)
            
            Spacer()
            
            // 模式标签
            if bluetoothManager.isInOTAMode {
                ModeTagView(text: "升级中", color: .orange)
            } else if bluetoothManager.isScanning {
                ModeTagView(text: "扫描中", color: .green)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
    }
}

// 控制按钮区域
struct ControlButtonsView: View {
    @EnvironmentObject var bluetoothManager: BluetoothManager
    @EnvironmentObject var fileManager: OTAFileManager
    @Binding var showingFileSelection: Bool
    @State private var showingUpgradeAlert = false
    @State private var showingFileSelector = false  // 显示文件选择器（用于单次升级）
    
    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                // 文件选择按钮
                Button(action: {
                    showingFileSelection = true
                }) {
                    HStack {
                        Image(systemName: "doc.badge.plus")
                        Text("选择文件")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(ControlButtonStyle(
                    backgroundColor: fileManager.selectedFiles.isEmpty ? Color.blue : Color.green,
                    isDisabled: false
                ))
                
                // 开始升级按钮
                Button(action: {
                    if bluetoothManager.selectedDevicesCount > 0 && !fileManager.selectedFiles.isEmpty {
                        if fileManager.selectedFiles.count == 1 {
                            // 只有一个文件，直接升级
                            showingUpgradeAlert = true
                        } else {
                            // 有多个文件，让用户选择用哪个文件升级
                            showingFileSelector = true
                        }
                    }
                }) {
                    HStack {
                        Image(systemName: "arrow.up.circle")
                        Text("开始升级")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(ControlButtonStyle(
                    backgroundColor: Color(red: 0, green: 0x9C/255.0, blue: 0x3A/255.0),
                    isDisabled: bluetoothManager.selectedDevicesCount == 0 || fileManager.selectedFiles.isEmpty
                ))
                .disabled(bluetoothManager.selectedDevicesCount == 0 || fileManager.selectedFiles.isEmpty)
            }
        }
        .alert("确认升级", isPresented: $showingUpgradeAlert) {
            Button("取消", role: .cancel) { }
            Button("确定") {
                if let file = fileManager.selectedFiles.first {
                    bluetoothManager.startOTA(with: file.fileAbsolutePath)
                }
            }
        } message: {
            if let file = fileManager.selectedFiles.first {
                Text("将为 \(bluetoothManager.selectedDevicesCount) 个设备进行固件升级\n使用文件: \(file.fileName)")
            } else {
                Text("将为 \(bluetoothManager.selectedDevicesCount) 个设备进行固件升级")
            }
        }
        .actionSheet(isPresented: $showingFileSelector) {
            ActionSheet(
                title: Text("选择升级文件"),
                message: Text("请选择要使用的固件文件"),
                buttons: fileSelectionButtons()
            )
        }
    }
    
    // 生成文件选择按钮（用于多个文件时的选择）
    private func fileSelectionButtons() -> [ActionSheet.Button] {
        var buttons: [ActionSheet.Button] = fileManager.selectedFiles.map { file in
            .default(Text(file.fileName)) {
                bluetoothManager.startOTA(with: file.fileAbsolutePath)
            }
        }
        buttons.append(.cancel(Text("取消")))
        return buttons
    }
}

// 已选择文件显示区域
struct SelectedFilesView: View {
    @EnvironmentObject var fileManager: OTAFileManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 标题栏
            HStack {
                Image(systemName: "doc.fill")
                    .foregroundColor(.blue)
                
                Text("已选择 \(fileManager.selectedFiles.count) 个文件")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                // 总大小
                Text(totalSizeFormatted)
                    .font(.caption)
                    .foregroundColor(.gray)
                
            }
            
            // 文件列表
            VStack(spacing: 6) {
                ForEach(Array(fileManager.selectedFiles.enumerated()), id: \.element.fileAbsolutePath) { index, file in
                    HStack {
                        Text("\(index + 1).")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .frame(width: 25, alignment: .trailing)
                        
                        Text(file.fileName)
                            .font(.caption)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        
                        Spacer()
                        
                        Text(formatFileSize(file.fileSize))
                            .font(.caption2)
                            .foregroundColor(.gray)
                        
                    }
                    .padding(.vertical, 2)
                }
            }
            .padding(.leading, 4)
            .padding(.top, 4)
            
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.blue.opacity(0.1))
        .cornerRadius(8)
    }
    
    private var totalSizeFormatted: String {
        let totalSize = fileManager.selectedFiles.reduce(0) { $0 + $1.fileSize }
        return formatFileSize(totalSize)
    }
    
    private func formatFileSize(_ size: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(size))
    }
    
}

// 设备列表（合并扫描和OTA显示）
struct DeviceListView: View {
    @EnvironmentObject var bluetoothManager: BluetoothManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 列表标题
            HStack {
                Text(bluetoothManager.isInOTAMode ? "升级设备状态" : "扫描到的设备")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                // 统计信息
                Text(bluetoothManager.isInOTAMode ?
                     "\(bluetoothManager.otaDevices.count) 个设备" :
                     "\(bluetoothManager.devices.count) 个设备")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .padding(.horizontal)
            
            // 设备列表
            if bluetoothManager.currentDeviceList.isEmpty {
                // 空状态提示
                EmptyDeviceListView()
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(bluetoothManager.currentDeviceList, id: \.peripheral.identifier) { device in
                            DeviceItemView(device: device)
                                .padding(.horizontal)
                        }
                    }
                    .padding(.top, 4)
                }
            }
        }
    }
}

// 空设备列表提示
struct EmptyDeviceListView: View {
    @EnvironmentObject var bluetoothManager: BluetoothManager
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: bluetoothManager.isInOTAMode ? "arrow.triangle.2.circlepath" : "antenna.radiowaves.left.and.right")
                .font(.system(size: 40))
                .foregroundColor(.gray.opacity(0.5))
            
            Text(bluetoothManager.isInOTAMode ?
                 "暂无升级中的设备" :
                 (bluetoothManager.isScanning ? "正在搜索设备..." : "点击右上角搜索按钮开始扫描"))
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
            
            if !bluetoothManager.isScanning && !bluetoothManager.isInOTAMode {
                Text("请确保蓝牙已打开并靠近设备")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .background(Color(.systemGray6).opacity(0.3))
    }
}

// 单个设备项
struct DeviceItemView: View {
    let device: PHYBLEModel
    @EnvironmentObject var bluetoothManager: BluetoothManager
    @State private var showCustomNameSheet = false
    @State private var customName: String = ""
    
    var body: some View {
        HStack(spacing: 12) {
            // 扫描模式：选择框
            if !bluetoothManager.isInOTAMode {
                Circle()
                    .stroke(bluetoothManager.isDeviceSelected(device.peripheral.identifier.uuidString) ?
                            Color.green : Color.gray.opacity(0.5), lineWidth: 2)
                    .frame(width: 20, height: 20)
                    .overlay(
                        bluetoothManager.isDeviceSelected(device.peripheral.identifier.uuidString) ?
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.green) : nil
                    )
            }
            
            // 中间：设备信息
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(deviceName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    // 信号强度或状态文本
                    if !bluetoothManager.isInOTAMode {
                        Text("\(device.rssi.stringValue)dBm")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                if bluetoothManager.isInOTAMode {
                    Text(device.otaMessage)
                        .font(.caption)
                        .foregroundColor(.gray)
                }else {
                    Text(device.adverMacAddr.count>0 ? device.adverMacAddr : device.peripheral.identifier.uuidString)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
            }
            
            // 右侧：操作按钮
            if !bluetoothManager.isInOTAMode {
                Button(action: {
                    showCustomNameSheet = true
                    customName = loadCustomName()
                }) {
                    Image(systemName: "pencil.circle")
                        .foregroundColor(.blue)
                        .font(.system(size: 18))
                }
                .buttonStyle(BorderlessButtonStyle())
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(bluetoothManager.isDeviceSelected(device.peripheral.identifier.uuidString) && !bluetoothManager.isInOTAMode ?
                      Color.green.opacity(0.1) : Color(.systemBackground))
                .shadow(color: .gray.opacity(0.1), radius: 2, x: 0, y: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            if !bluetoothManager.isInOTAMode {
                bluetoothManager.toggleDeviceSelection(device.peripheral.identifier.uuidString)
                
                // 选择设备后，如果正在扫描则停止扫描
                if bluetoothManager.isScanning {
                    bluetoothManager.stopScan()
                }
            }
        }
        .sheet(isPresented: $showCustomNameSheet) {
            CustomNameSheet(device: device, customName: $customName)
        }
    }
    
    private var deviceName: String {
        if !bluetoothManager.isInOTAMode {
            let uuid = device.peripheral.identifier.uuidString
            if let savedName = UserDefaults.standard.string(forKey: uuid), !savedName.isEmpty {
                return savedName
            }
        }
        return device.realName
    }
    
    private func loadCustomName() -> String {
        let uuid = device.peripheral.identifier.uuidString
        return UserDefaults.standard.string(forKey: uuid) ?? ""
    }
    
    private func getProgress(from message: String?) -> Float? {
        guard let message = message,
              let range = message.range(of: "\\d+(\\.\\d+)?%", options: .regularExpression) else {
            return nil
        }
        
        let percentageString = String(message[range].dropLast()) // 去掉最后的 "%"
        return Float(percentageString).map { $0 / 100.0 }
    }
    
    private func progressColor(device: PHYBLEModel) -> Color {
        switch UInt(device.otaType) {
        case OTASwiftConstants.OTAComplete:
            return .green
        case OTASwiftConstants.OTAFailed:
            return .red
        default:
            return .blue
        }
    }
}

// 扫描按钮视图
struct ScanButtonView: View {
    @EnvironmentObject var bluetoothManager: BluetoothManager
    
    var body: some View {
        Button(action: {
            if bluetoothManager.isScanning {
                bluetoothManager.stopScan()
            } else {
                bluetoothManager.startScan()
            }
        }) {
            Image(systemName: bluetoothManager.isScanning ? "stop.circle.fill" : "magnifyingglass.circle.fill")
            .foregroundColor(.white)
            .background(
                Capsule()
                    .fill(bluetoothManager.isScanning ? Color.red : Color.blue)
            )
        }
    }
}

// 模式标签视图
struct ModeTagView: View {
    let text: String
    let color: Color
    
    var body: some View {
        Text(text)
            .font(.caption2)
            .fontWeight(.medium)
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(
                Capsule()
                    .fill(color)
            )
    }
}

// 自定义名称弹窗
struct CustomNameSheet: View {
    let device: PHYBLEModel
    @Binding var customName: String
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // 添加顶部间距，使TextField和导航条之间保持8的间距
                Spacer()
                    .frame(height: 8)
                
                TextField("输入设备别名", text: $customName)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                    .padding(.horizontal)
                
                Spacer()
            }
            .navigationTitle("自定义设备名称")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        let uuid = device.peripheral.identifier.uuidString
                        if customName.isEmpty {
                            UserDefaults.standard.removeObject(forKey: uuid)
                        } else {
                            UserDefaults.standard.set(customName, forKey: uuid)
                        }
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
}

// 控制按钮样式
struct ControlButtonStyle: ButtonStyle {
    let backgroundColor: Color
    let isDisabled: Bool
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .medium))
            .foregroundColor(.white)
            .frame(height: 40)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isDisabled ? backgroundColor.opacity(0.5) : backgroundColor)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

