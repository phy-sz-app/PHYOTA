//
//  SettingsView.swift
//  iOS_PHYOTA_Test
//
//  Created by di lu on 2026/1/26.
//

import SwiftUI
import MessageUI

struct SettingsView: View {
    @EnvironmentObject var bluetoothManager: BluetoothManager
    
    var body: some View {
        List {
            // 交互日志
            NavigationLink(destination: LogView()) {
                MenuItemView(
                    icon: "doc.text",
                    iconColor: .blue,
                    title: "交互日志",
                    subtitle: "查看BLE交互记录"
                )
            }
            
            // 压力测试
            NavigationLink(destination: StressTestView()) {
                MenuItemView(
                    icon: "speedometer",
                    iconColor: .orange,
                    title: "压力测试",
                    subtitle: "循环升级测试与统计"
                )
            }
            
            NavigationLink(destination: BurnInOTAView()) {
                MenuItemView(
                    icon: "flame",
                    iconColor: .orange,
                    title: "烧录式OTA",
                    subtitle: "批量自动扫描升级"
                )
            }
            
            // 导出功能
            Section(header: Text("数据导出")) {
                Button(action: {
                    exportAllData()
                }) {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                            .foregroundColor(.green)
                        Text("导出所有数据")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
            }
        }
        .navigationTitle("设置")
        .navigationBarTitleDisplayMode(.inline)
    }

    
    private func exportAllData() {
        // 获取日志数据
        let logText = bluetoothManager.logManager.exportLogs()
        let testReport = bluetoothManager.stressTestManager.exportTestReport()
        
        // 合并数据
        let exportText = """
        ====== OTA测试工具数据导出 ======
        导出时间: \(Date())
        
        \(logText)
        
        \(testReport)
        """
        
        // 创建分享
        let activityVC = UIActivityViewController(
            activityItems: [exportText],
            applicationActivities: nil
        )
        
        // 需要在UIViewController中展示
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            activityVC.popoverPresentationController?.sourceView = rootVC.view
            rootVC.present(activityVC, animated: true)
        }
    }
}

// 菜单项组件
struct MenuItemView: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    
    var body: some View {
        HStack(spacing: 16) {
            // 图标
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(iconColor.opacity(0.1))
                    .frame(width: 40, height: 40)
                
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(iconColor)
            }
            
            // 文本
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Spacer()
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }
}
