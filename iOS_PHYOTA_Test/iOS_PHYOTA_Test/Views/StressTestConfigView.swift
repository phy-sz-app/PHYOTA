//
//  StressTestConfigView.swift
//  iOS_PHYOTA_Test
//
//  Created by di lu on 2026/3/3.
//

import SwiftUI

struct StressTestConfigView: View {
    @EnvironmentObject var bluetoothManager: BluetoothManager
    @Environment(\.dismiss) var dismiss
    @State private var localConfig: StressTestConfig
    
    init() {
        _localConfig = State(initialValue: StressTestConfig())
    }
    
    var body: some View {
        Form {
            
            Section(header: Text("测试设置")) {
                HStack {
                    Text("最大迭代次数")
                    Spacer()
                    TextField("次数",
                              value: $localConfig.maxIterations,  // 修改：使用 $config 而不是 $localConfig
                              formatter: NumberFormatter.integerFormatter)
                    .keyboardType(.numberPad)
                    .frame(width: 100)
                    .multilineTextAlignment(.trailing)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                }
            }
            
            
            Section {
                Button("保存配置") {
                    bluetoothManager.stressTestManager.currentConfig = localConfig
                    bluetoothManager.stressTestManager.saveTestResults()
                    dismiss()
                }
                .frame(maxWidth: .infinity)
            }
        }
        .navigationTitle("测试配置")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            localConfig = bluetoothManager.stressTestManager.currentConfig
        }
    }
}

extension NumberFormatter {

    
    static var integerFormatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .none
        formatter.maximum = 100000
        formatter.minimum = 1
        return formatter
    }
}
