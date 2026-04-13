//
//  TestRecordsView.swift
//  iOS_PHYOTA_Test
//
//  Created by di lu on 2026/3/6.
//

import SwiftUI

// MARK: - 测试记录视图（新页面）
struct TestRecordsView: View {
    @EnvironmentObject var bluetoothManager: BluetoothManager
    @Environment(\.dismiss) var dismiss
    @State private var showingClearAlert = false
    @State private var searchText = ""
    @State private var selectedFilter: RecordFilter = .all
    
    enum RecordFilter {
        case all, success, failure
        
        var title: String {
            switch self {
            case .all: return "全部"
            case .success: return "成功"
            case .failure: return "失败"
            }
        }
        
        var icon: String {
            switch self {
            case .all: return "list.bullet"
            case .success: return "checkmark.circle"
            case .failure: return "xmark.circle"
            }
        }
        
        var color: Color {
            switch self {
            case .all: return .blue
            case .success: return .green
            case .failure: return .red
            }
        }
    }
    
    var filteredResults: [TestResult] {
        var results = bluetoothManager.stressTestManager.testResults
        
        // 按状态筛选
        switch selectedFilter {
        case .success:
            results = results.filter { $0.isSuccess }
        case .failure:
            results = results.filter { !$0.isSuccess }
        case .all:
            break
        }
        
        // 按搜索文本筛选
        if !searchText.isEmpty {
            results = results.filter {
                $0.deviceName.localizedCaseInsensitiveContains(searchText) ||
                $0.fileName.localizedCaseInsensitiveContains(searchText) ||
                ($0.errorMessage?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }
        
        return results
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 搜索栏
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                
                TextField("搜索设备、文件名或错误信息...", text: $searchText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                }
            }
            .padding()
            .background(Color(.systemBackground))
            
            // 筛选和操作按钮栏
            VStack(spacing: 12) {
                // 第一行：筛选按钮（全部、成功、失败）
                HStack(spacing: 12) {
                    ForEach([RecordFilter.all, .success, .failure], id: \.title) { filter in
                        FilterButton(
                            title: filter.title,
                            icon: filter.icon,
                            count: getCountForFilter(filter),
                            isSelected: selectedFilter == filter,
                            color: filter.color
                        ) {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                selectedFilter = filter
                            }
                        }
                    }
                    
                    Spacer()
                }
                
                // 第二行：操作按钮（导出、清空）
                HStack(spacing: 12) {
                    Spacer()
                    
                    // 导出按钮
                    Button(action: { exportReport() }) {
                        HStack(spacing: 6) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.caption)
                            Text("导出")
                                .font(.caption)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.blue.opacity(0.1))
                        .foregroundColor(.blue)
                        .cornerRadius(8)
                    }
                    
                    // 清空按钮
                    Button(action: { showingClearAlert = true }) {
                        HStack(spacing: 6) {
                            Image(systemName: "trash")
                                .font(.caption)
                            Text("清空")
                                .font(.caption)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.red.opacity(0.1))
                        .foregroundColor(.red)
                        .cornerRadius(8)
                    }
                }
                
                // 搜索结果提示
                if !searchText.isEmpty || selectedFilter != .all {
                    HStack {
                        Text("找到 \(filteredResults.count) 条记录")
                            .font(.caption)
                            .foregroundColor(.blue)
                        
                        Spacer()
                        
                        Button(action: {
                            searchText = ""
                            selectedFilter = .all
                        }) {
                            Text("清除筛选")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                    }
                    .padding(.top, 4)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
            .background(Color(.systemGray6))
            
            // 测试记录列表
            if filteredResults.isEmpty {
                VStack(spacing: 20) {
                    Image(systemName: getEmptyStateIcon())
                        .font(.system(size: 50))
                        .foregroundColor(.gray.opacity(0.5))
                    
                    Text(getEmptyStateTitle())
                        .font(.headline)
                        .foregroundColor(.gray)
                    
                    Text(getEmptyStateMessage())
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(filteredResults) { result in
                            TestRecordDetailView(result: result)
                                .padding(.horizontal)
                        }
                    }
                    .padding(.vertical, 12)
                }
            }
        }
        .navigationTitle("测试记录")
        .navigationBarTitleDisplayMode(.inline)
        .alert("清空测试记录", isPresented: $showingClearAlert) {
            Button("取消", role: .cancel) { }
            Button("清空", role: .destructive) {
                withAnimation {
                    bluetoothManager.stressTestManager.clearTestResults()
                }
            }
        } message: {
            Text("确定要清空所有测试记录吗？此操作不可撤销。")
        }
    }
    
    private func getCountForFilter(_ filter: RecordFilter) -> Int {
        let total = bluetoothManager.stressTestManager.testResults.count
        let success = bluetoothManager.stressTestManager.testResults.filter { $0.isSuccess }.count
        let failure = total - success
        
        switch filter {
        case .all:
            return total
        case .success:
            return success
        case .failure:
            return failure
        }
    }
    
    private func getEmptyStateIcon() -> String {
        if searchText.isEmpty && selectedFilter == .all {
            return "doc.text.magnifyingglass"
        } else if !searchText.isEmpty {
            return "magnifyingglass"
        } else {
            return selectedFilter == .success ? "checkmark.circle" : "xmark.circle"
        }
    }
    
    private func getEmptyStateTitle() -> String {
        if searchText.isEmpty && selectedFilter == .all {
            return "暂无测试记录"
        } else if !searchText.isEmpty {
            return "没有找到匹配的记录"
        } else {
            return selectedFilter == .success ? "没有成功的记录" : "没有失败的记录"
        }
    }
    
    private func getEmptyStateMessage() -> String {
        if searchText.isEmpty && selectedFilter == .all {
            return "开始压力测试后，记录将显示在这里"
        } else if !searchText.isEmpty {
            return "尝试使用不同的关键词搜索"
        } else {
            return selectedFilter == .success ? "暂无成功的测试记录" : "暂无失败的测试记录"
        }
    }
    
    private func exportReport() {
        let report = bluetoothManager.stressTestManager.exportTestReport()
        
        let activityVC = UIActivityViewController(
            activityItems: [report],
            applicationActivities: nil
        )
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            activityVC.popoverPresentationController?.sourceView = rootVC.view
            rootVC.present(activityVC, animated: true)
        }
    }
}

// MARK: - 筛选按钮
struct FilterButton: View {
    let title: String
    let icon: String
    let count: Int
    let isSelected: Bool
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                
                Text(title)
                    .font(.caption)
                    .fontWeight(isSelected ? .semibold : .regular)
                
                if count > 0 {
                    Text("(\(count))")
                        .font(.caption2)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? color.opacity(0.2) : Color(.systemGray5))
            )
            .foregroundColor(isSelected ? color : .primary)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - 测试记录详情视图
struct TestRecordDetailView: View {
    let result: TestResult
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 主内容区域
            VStack(alignment: .leading, spacing: 8) {
                // 头部信息
                HStack {
                    // 状态图标
                    ZStack {
                        Circle()
                            .fill(result.isSuccess ? Color.green.opacity(0.2) : Color.red.opacity(0.2))
                            .frame(width: 40, height: 40)
                        
                        Image(systemName: result.isSuccess ? "checkmark" : "xmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(result.isSuccess ? .green : .red)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("测试 #\(result.testNumber)")
                            .font(.headline)
                        
                        HStack(spacing: 8) {
                            Image(systemName: "clock")
                                .font(.caption2)
                                .foregroundColor(.gray)
                            Text(formatDateTime(result.startTime))
                                .font(.caption2)
                                .foregroundColor(.gray)
                        }
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        // 耗时标签
                        HStack(spacing: 4) {
                            Image(systemName: "timer")
                                .font(.caption2)
                            Text(result.durationFormatted)
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(6)
                        
                        // 文件信息
                        HStack(spacing: 4) {
                            Image(systemName: "doc")
                                .font(.caption2)
                            Text(result.fileName)
                                .font(.caption2)
                                .lineLimit(1)
                        }
                        .foregroundColor(.gray)
                    }
                }
                
                Divider()
                    .padding(.vertical, 4)
                
                // 详细信息网格
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    InfoItemView(
                        icon: "iphone.gen2",
                        title: "设备",
                        value: result.deviceName,
                        color: .blue
                    )
                    
                    if result.disconnectedCount > 0 {
                        InfoItemView(
                            icon: "antenna.radiowaves.left.and.right.slash",
                            title: "断开次数",
                            value: "\(result.disconnectedCount)次",
                            color: .orange
                        )
                    }
                    
                    InfoItemView(
                        icon: "calendar",
                        title: "结束时间",
                        value: formatDateTime(result.endTime),
                        color: .gray
                    )
                }
            }
            .padding()
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    isExpanded.toggle()
                }
            }
            
            // 展开的详细信息
            if isExpanded && !result.isSuccess {
                VStack(alignment: .leading, spacing: 12) {
                    Divider()
                        .padding(.horizontal)
                    
                    // 错误信息
                    if let error = result.errorMessage {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.red)
                                .font(.caption)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("错误信息")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(.red)
                                
                                Text(error)
                                    .font(.caption)
                                    .foregroundColor(.red)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            
                            Spacer()
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 12)
                    }
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.08), radius: 3, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    result.isSuccess ? Color.green.opacity(0.3) : Color.red.opacity(0.3),
                    lineWidth: 1
                )
        )
    }
    
    private func formatDateTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }
}

// MARK: - 信息项视图
struct InfoItemView: View {
    let icon: String
    let title: String
    let value: String
    var color: Color = .primary
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(.gray)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption2)
                    .foregroundColor(.gray)
                
                Text(value)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(color)
                    .lineLimit(2)
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
}
