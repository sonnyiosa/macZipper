import Foundation
import AppKit

actor FilePreviewService {
    private let tempDirectory: URL
    private let fileManager = FileManager.default
    
    init() {
        // Create a dedicated temp directory for previews
        let baseTempDir = fileManager.temporaryDirectory
        tempDirectory = baseTempDir.appendingPathComponent("MacZipper_Preview_\(UUID().uuidString)")
        
        do {
            try fileManager.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        } catch {
            print("Failed to create temp directory: \(error)")
        }
    }
    
    func previewFile(entry: ZipEntry, from archiveURL: URL, using zipService: ZipService) async throws {
        // Create a unique temp directory for this preview
        let entryTempDir = tempDirectory.appendingPathComponent(UUID().uuidString)
        try fileManager.createDirectory(at: entryTempDir, withIntermediateDirectories: true)
        
        // Determine the destination file URL
        let destinationURL = entryTempDir.appendingPathComponent(entry.name)
        
        // Extract the file
        let progress = Progress()
        try await zipService.extract(entry: entry, to: destinationURL, progress: progress)
        
        // Open the file with the default application
        await MainActor.run {
            NSWorkspace.shared.open(destinationURL)
        }
    }
    
    func cleanup() {
        do {
            try fileManager.removeItem(at: tempDirectory)
        } catch {
            print("Failed to cleanup temp directory: \(error)")
        }
    }
}
