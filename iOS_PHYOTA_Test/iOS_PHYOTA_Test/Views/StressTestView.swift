//
//  StressTestView.swift
//  iOS_PHYOTA_Test
//
//  Created by di lu on 2026/1/26.
//

import SwiftUI

struct StressTestView: View {
    @EnvironmentObject var bluetoothManager: BluetoothManager
    @State private var navigateToConfig = false
    @State private var showingDeviceAlert = false
    @State private var showingTestRecords = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                CurrentTestView()
                StatsView()
                StressTestProgressView()
                TestControlsView()
                
                // 测试记录快捷入口
                NavigationLink(destination: TestRecordsView(),
                               isActive: $showingTestRecords) {
                    EmptyView()
                }
                
                Button(action: {
                    showingTestRecords = true
                }) {
                    HStack {
                        Text("查看详细测试记录")
                            .font(.headline)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                    .padding(.horizontal)
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.top, 8)
            }
            .padding(.bottom, 20)
        }
        .navigationTitle("压力测试")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                NavigationLink(destination: StressTestConfigView()) {
                    Image(systemName: "gear")
                }
            }
        }
        .alert("设备选择", isPresented: $showingDeviceAlert) {
            Button("确定") { }
        } message: {
            Text("压力测试将使用第一个选中的设备进行测试")
        }
        .onAppear {
            if bluetoothManager.selectedDevicesCount > 1 {
                showingDeviceAlert = true
            }
        }
    }
}

struct CurrentTestView: View {
    @EnvironmentObject var bluetoothManager: BluetoothManager
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Circle()
                    .fill(bluetoothManager.stressTestManager.isTesting ? Color.green : Color.gray)
                    .frame(width: 12, height: 12)
                    .overlay(
                        Circle()
                            .stroke(Color.white, lineWidth: 2)
                    )
                
                Text(bluetoothManager.stressTestManager.isTesting ? "测试进行中" : "测试未开始")
                    .font(.headline)
                
                Spacer()
                
                if bluetoothManager.stressTestManager.isTesting {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            
            if bluetoothManager.stressTestManager.isTesting {
                Text("第 \(bluetoothManager.stressTestManager.currentTestNumber) 次测试")
                    .font(.subheadline)
                    .foregroundColor(.blue)
                
                Text(bluetoothManager.stressTestManager.currentTestStatus)
                    .font(.caption)
                    .foregroundColor(.gray)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                
                // 显示测试设备
                if !bluetoothManager.stressTestManager.currentTestDeviceName.isEmpty {
                    Text("测试设备: \(bluetoothManager.stressTestManager.currentTestDeviceName)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else if bluetoothManager.selectedDevicesCount > 0 {
                let deviceName = bluetoothManager.selectedDevices.first?.realName ?? "未知设备"
                Text("准备测试: \(deviceName)")
                    .font(.caption)
                    .foregroundColor(.blue)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
        .padding()
    }
}

// MARK: - 统计视图
struct StatsView: View {
    @EnvironmentObject var bluetoothManager: BluetoothManager
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("测试统计")
                    .font(.headline)
                Spacer()
            }
            .padding(.horizontal)
            
            HStack {
                StatItemView(
                    title: "成功率",
                    value: String(format: "%.1f%%", bluetoothManager.stressTestManager.currentStats.successRate),
                    color: .green
                )
                
                StatItemView(
                    title: "总次数",
                    value: "\(bluetoothManager.stressTestManager.currentStats.totalTests)",
                    color: .blue
                )
            }
            .padding(.horizontal)
            
            HStack {
                StatItemView(
                    title: "平均耗时",
                    value: String(format: "%.2fs", bluetoothManager.stressTestManager.currentStats.averageDuration),
                    color: .orange
                )
                
                StatItemView(
                    title: "成功数",
                    value: "\(bluetoothManager.stressTestManager.currentStats.successfulTests)",
                    color: .purple
                )
            }
            .padding(.horizontal)
        }
    }
}

struct StressTestProgressView: View {
    @EnvironmentObject var bluetoothManager: BluetoothManager
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("测试进度")
                    .font(.headline)
                Spacer()
                
                if bluetoothManager.stressTestManager.isTesting {
                    Text("\(Int(bluetoothManager.stressTestManager.currentTestProgress * 100))%")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
            .padding(.horizontal)
            .padding(.top, 16)
            
            if bluetoothManager.stressTestManager.isTesting {
                // 进度条
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(height: 6)
                            .cornerRadius(3)
                        
                        Rectangle()
                            .fill(Color.blue)
                            .frame(width: geometry.size.width * CGFloat(bluetoothManager.stressTestManager.currentTestProgress), height: 6)
                            .cornerRadius(3)
                            .animation(.easeInOut, value: bluetoothManager.stressTestManager.currentTestProgress)
                    }
                }
                .frame(height: 6)
                .padding(.horizontal)
                
                // 进度标签
                HStack {
                    Text("已完成: \(bluetoothManager.stressTestManager.testIterationsCompleted)")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    Spacer()
                    
                    Text("总计: \(bluetoothManager.stressTestManager.currentConfig.maxIterations)")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .padding(.horizontal)
            } else {
                Text("点击开始测试按钮开始压力测试")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .padding()
            }
        }
        .padding(.bottom)
    }
}

// MARK: - 测试控制视图
struct TestControlsView: View {
    @EnvironmentObject var bluetoothManager: BluetoothManager
    @EnvironmentObject var fileManager: OTAFileManager
    @State private var showingStartAlert = false
    
    var body: some View {
        VStack(spacing: 12) {
            // 开始/停止测试按钮
            Button(action: {
                if bluetoothManager.stressTestManager.isTesting {
                    bluetoothManager.stressTestManager.stopStressTest()
                } else {
                    showingStartAlert = true
                }
            }) {
                HStack {
                    Image(systemName: bluetoothManager.stressTestManager.isTesting ?
                          "stop.circle.fill" : "play.circle.fill")
                    .font(.title3)
                    
                    Text(bluetoothManager.stressTestManager.isTesting ? "停止测试" : "开始测试")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .foregroundColor(.white)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(bluetoothManager.stressTestManager.isTesting ? Color.red : Color.green)
                )
            }
            .padding(.horizontal)
            .disabled((bluetoothManager.selectedDevicesCount == 0 || fileManager.selectedFiles.isEmpty) && !bluetoothManager.isTestMode )
            .opacity(((bluetoothManager.selectedDevicesCount == 0 || fileManager.selectedFiles.isEmpty) && !bluetoothManager.isTestMode ) ? 0.5 : 1)

        }
        .padding(.vertical)
        .alert("开始压力测试", isPresented: $showingStartAlert) {
            Button("取消", role: .cancel) { }
            Button("开始") {
                bluetoothManager.stressTestManager.startStressTest()
            }
        } message: {
            if let device = bluetoothManager.selectedDevices.first {
                let iterations = bluetoothManager.stressTestManager.currentConfig.maxIterations
                Text("将对设备 [\(device.realName)] 进行 \(iterations) 次循环升级测试")
            }
        }
    }
}

struct StatItemView: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundColor(.gray)
            
            Text(value)
                .font(.title2)
                .bold()
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
}
