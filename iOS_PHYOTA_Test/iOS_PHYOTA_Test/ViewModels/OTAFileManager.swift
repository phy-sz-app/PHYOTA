//
//  OTAFileManager.swift
//  iOS_PHYOTA_Test
//
//  Created by di lu on 2026/1/19.
//

import Foundation
import Combine
import SwiftUI

class OTAFileManager: NSObject, ObservableObject {
    @Published var selectedFiles: [OTAFileModel] = []
    @Published var availableFiles: [OTAFileModel] = []
    
    
    private let fileManager = FileManager.default
    
    override init() {
        super.init()
        loadAvailableFiles()
    }
    
    // MARK: - 文件处理
    func handleIncomingFile(url: URL) -> Bool {
        print("收到共享文件，URL scheme: \(url.scheme ?? "无")  URL path: \(url.path)")
        
        // 检查是否是文件
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) else {
            print("文件不存在")
            return false
        }
        
        if isDirectory.boolValue {
            print("不支持文件夹")
            return false
        }
        
        // 检查文件扩展名（只接受固件文件）
        let allowedExtensions = ["hex", "bin", "hex16", "hex4", "res", "hexe16"]
        let fileExtension = url.pathExtension.lowercased()
        
        if !allowedExtensions.contains(fileExtension) {
            print("不支持的文件类型: \(fileExtension)")
            return false
        }
        
        do {
            let attributes = try fileManager.attributesOfItem(atPath: url.path)
            let fileSize = attributes[.size] as? Int ?? 0
            
            let model = OTAFileModel()
            model.fileName = url.lastPathComponent
            model.fileAbsolutePath = url.path
            model.fileSize = fileSize
            model.filemTime = attributes[.creationDate] as? Date ?? Date()
            
            // 在主线程更新UI
            DispatchQueue.main.async { [weak self] in
                self?.addFileToAvailable(model)
            }
            
            return true
        } catch {
            print("❌ 获取文件信息失败: \(error)")
            return false
        }
    }
    
    private func addFileToAvailable(_ fileModel: OTAFileModel) {
        print("收到新文件: \(fileModel.fileName)")
        
        // 检查是否已存在（避免重复）
        if !self.availableFiles.contains(where: { $0.fileAbsolutePath == fileModel.fileAbsolutePath }) {
            self.availableFiles.insert(fileModel, at: 0) // 新文件放在最前面
            print("✅ 已添加到文件列表")
        }
    }
    
    func loadAvailableFiles() {
        let inboxPath = documentDirectory().appendingPathComponent("Inbox")
        
        var allFiles: [OTAFileModel] = []
        
        if fileManager.fileExists(atPath: inboxPath.path) {
            let files = loadFilesFromDirectory(inboxPath)
            allFiles.append(contentsOf: files)
        }
        
        // 按时间排序，最新的文件在前面
        availableFiles = allFiles.sorted {
            ($0.filemTime ?? Date.distantPast) > ($1.filemTime ?? Date.distantPast)
        }
        
        print("✅ 加载到 \(availableFiles.count) 个可用文件")
        
    }
    
    private func loadFilesFromDirectory(_ directory: URL) -> [OTAFileModel] {
        do {
            let fileURLs = try fileManager.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: [
                    .creationDateKey,
                    .fileSizeKey,
                    .contentModificationDateKey,
                    .nameKey
                ],
                options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants]
            )
            
            var files: [OTAFileModel] = []
            
            for url in fileURLs {
                // 只接受固件文件
                let allowedExtensions = ["hex", "bin", "hex16", "hex4", "res", "hexe16"]
                let fileExtension = url.pathExtension.lowercased()
                
                if allowedExtensions.contains(fileExtension) {
                    do {
                        let resourceValues = try url.resourceValues(
                            forKeys: [
                                .creationDateKey,
                                .fileSizeKey,
                                .contentModificationDateKey,
                                .nameKey
                            ]
                        )
                        
                        let model = OTAFileModel()
                        model.fileName = url.lastPathComponent
                        model.fileAbsolutePath = url.path
                        model.filemTime = resourceValues.creationDate ?? resourceValues.contentModificationDate
                        model.fileSize = resourceValues.fileSize ?? 0
                        
                        files.append(model)
                        print("找到文件: \(model.fileName), 大小: \(model.fileSize), 路径: \(model.fileAbsolutePath)")
                        
                    } catch {
                        print("读取文件属性失败: \(url.lastPathComponent), 错误: \(error)")
                    }
                }
            }
            
            return files
            
        } catch {
            print("读取目录失败: \(directory.path), 错误: \(error)")
            return []
        }
    }
    
    func selectFiles(_ files: [OTAFileModel]) {
        selectedFiles = files
    }
    
    func deleteFile(_ file: OTAFileModel) -> Bool {
        do {
            try fileManager.removeItem(atPath: file.fileAbsolutePath)
            
            // 从列表中移除
            availableFiles.removeAll { $0.fileAbsolutePath == file.fileAbsolutePath }
            
            // 如果文件在选中列表中，也要移除
            if selectedFiles.contains(where: { $0.fileAbsolutePath == file.fileAbsolutePath }) {
                selectedFiles.removeAll { $0.fileAbsolutePath == file.fileAbsolutePath }
            }
            
            print("✅ 已删除文件: \(file.fileName)")
            
            return true
        } catch {
            print("Error deleting file: \(error)")
            return false
        }
    }
    
    private func documentDirectory() -> URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
    }
}

// 文件模型
class OTAFileModel: NSObject {
    var fileName: String = ""
    var fileOwner: String = ""
    var filemTime: Date?
    var fileSize: Int = 0
    var fileAbsolutePath: String = ""
}

