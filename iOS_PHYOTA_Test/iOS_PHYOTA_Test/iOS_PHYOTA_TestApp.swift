//
//  iOS_PHYOTA_TestApp.swift
//  iOS_PHYOTA_Test
//
//  Created by di lu on 2026/1/16.
//

import SwiftUI

@main
struct iOS_PHYOTA_TestApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var filesManager = OTAFileManager()  // 添加文件管理器
    @StateObject private var bluetoothManager = BluetoothManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(filesManager)  // 传递文件管理器
                .environmentObject(bluetoothManager)
                .onOpenURL { url in
                    _ = filesManager.handleIncomingFile(url: url)
                }
                .onAppear {
                    // 确保压力测试管理器有正确的依赖
                    bluetoothManager.setup(filesManager: filesManager)
                }
        }
    }
    
}


// AppDelegate 处理应用生命周期
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        // 配置导航栏外观
        let appearance = UINavigationBarAppearance()
        appearance.backgroundColor = UIColor(red: 0, green: 0x9C/255.0, blue: 0x3A/255.0, alpha: 1)
        appearance.titleTextAttributes = [.foregroundColor: UIColor.white]
        appearance.largeTitleTextAttributes = [.foregroundColor: UIColor.white]
        
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
        
        return true
    }
}
