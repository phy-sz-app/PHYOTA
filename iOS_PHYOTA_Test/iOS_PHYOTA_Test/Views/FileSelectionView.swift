//
//  FileSelectionView.swift
//  iOS_PHYOTA_Test
//
//  Created by di lu on 2026/1/20.
//

import SwiftUI

struct FileSelectionView: View {
    @EnvironmentObject var fileManager: OTAFileManager
    
    @State private var selectedFiles: Set<String> = []  // 临时存储选中的文件路径
    @Binding var isPresented: Bool  // 添加绑定来控制返回
    
    var body: some View {
        VStack(spacing: 0) {
            if fileManager.availableFiles.isEmpty {
                EmptyFileView()
            } else {
                VStack(spacing: 0) {
                    // 多选提示
                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundColor(.blue)
                        Text("可多选文件，压力测试时会循环使用")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Spacer()
                        
                        // 显示已选数量
                        if !selectedFiles.isEmpty {
                            Text("已选 \(selectedFiles.count) 个")
                                .font(.caption)
                                .foregroundColor(.blue)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(4)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(Color(.systemGray6))
                    
                    // 文件列表
                    FileListView(
                        selectedFiles: $selectedFiles
                    )
                }
            }
        }
        .navigationTitle("选择OTA文件")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("完成") {
                    // 将选中的文件转换为 OTAFileModel 数组
                    let selected = fileManager.availableFiles.filter {
                        selectedFiles.contains($0.fileAbsolutePath)
                    }
                    fileManager.selectFiles(selected)
                    isPresented = false  // 使用绑定返回
                }
                .disabled(selectedFiles.isEmpty)
            }
        }
        .onAppear {
            // 初始化时，将已选中的文件同步到临时选中状态
            selectedFiles = Set(fileManager.selectedFiles.map { $0.fileAbsolutePath })
        }
    }
}

// 空文件视图
struct EmptyFileView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "folder.badge.questionmark")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("没有找到升级文件")
                .font(.headline)
                .foregroundColor(.gray)
            
            Text("请从其他应用分享固件文件到此App")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding()
    }
}

// 文件列表视图
struct FileListView: View {
    @EnvironmentObject var fileManager: OTAFileManager
    @Binding var selectedFiles: Set<String>
    
    var body: some View {
        List {
            ForEach(fileManager.availableFiles, id: \.fileAbsolutePath) { file in
                FileSelectRow(
                    file: file,
                    isSelected: selectedFiles.contains(file.fileAbsolutePath),
                    onToggle: {
                        toggleFileSelection(file)
                    },
                    onDelete: {
                        deleteFile(file)
                    }
                )
            }
            .onDelete { indexSet in
                for index in indexSet {
                    if index < fileManager.availableFiles.count {
                        let file = fileManager.availableFiles[index]
                        deleteFile(file)
                    }
                }
            }
        }
        .listStyle(PlainListStyle())
    }
    
    private func toggleFileSelection(_ file: OTAFileModel) {
        if selectedFiles.contains(file.fileAbsolutePath) {
            selectedFiles.remove(file.fileAbsolutePath)
        } else {
            selectedFiles.insert(file.fileAbsolutePath)
        }
    }
    
    private func deleteFile(_ file: OTAFileModel) {
        // 如果文件被选中，先从选中列表中移除
        if selectedFiles.contains(file.fileAbsolutePath) {
            selectedFiles.remove(file.fileAbsolutePath)
        }
        
        // 删除文件
        _ = fileManager.deleteFile(file)
    }
}

// 文件选择行（支持多选）
struct FileSelectRow: View {
    let file: OTAFileModel
    let isSelected: Bool
    let onToggle: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // 选择框（多选）
            Button(action: onToggle) {
                ZStack {
                    Circle()
                        .stroke(isSelected ? Color.green : Color.gray.opacity(0.5), lineWidth: 2)
                        .frame(width: 22, height: 22)
                    
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundColor(.green)
                    }
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            // 文件信息
            VStack(alignment: .leading, spacing: 4) {
                Text(file.fileName)
                    .font(.headline)
                    .lineLimit(2)
                    .truncationMode(.middle)
                
                HStack {
                    if let date = file.filemTime {
                        Text(formatDate(date))
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    
                    Text("·")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    Text("大小: \(formatFileSize(file.fileSize))")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onToggle()
        }
        .contextMenu {
            Button(action: onToggle) {
                Label(isSelected ? "取消选择" : "选择",
                      systemImage: isSelected ? "circle" : "checkmark.circle")
            }
            
            Button(role: .destructive, action: onDelete) {
                Label("删除", systemImage: "trash")
            }
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.string(from: date)
    }
    
    private func formatFileSize(_ size: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(size))
    }
}
