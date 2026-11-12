import Foundation
import ZIPFoundation
import ZipArchive

enum ZipError: LocalizedError, Equatable {
    case invalidArchive
    case extractionFailed
    case fileNotFound
    case passwordRequired
    case incorrectPassword

    var errorDescription: String? {
        switch self {
        case .invalidArchive: return "The selected file is not a valid ZIP archive."
        case .extractionFailed: return "Could not extract the selected files."
        case .fileNotFound: return "The file was not found in the archive."
        case .passwordRequired: return "This archive requires a password."
        case .incorrectPassword: return "Incorrect password. Please try again."
        }
    }
}

actor ZipService {
    private var archive: Archive?
    private var extractedRoot: URL?

    deinit {
        if let extractedRoot { try? FileManager.default.removeItem(at: extractedRoot) }
    }
    
    func openArchive(at url: URL, password: String? = nil) throws {
        closeArchive()
        let encrypted = SSZipArchive.isFilePasswordProtected(atPath: url.path)
        if encrypted {
            guard let password, !password.isEmpty else { throw ZipError.passwordRequired }
            guard SSZipArchive.isPasswordValidForArchive(atPath: url.path, password: password, error: nil) else {
                throw ZipError.incorrectPassword
            }
            let root = FileManager.default.temporaryDirectory.appendingPathComponent("MacZipper_\(UUID().uuidString)")
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            var error: NSError?
            let succeeded = SSZipArchive.unzipFile(atPath: url.path, toDestination: root.path,
                                                   preserveAttributes: true, overwrite: true,
                                                   password: password, error: &error, delegate: nil)
            guard succeeded else {
                try? FileManager.default.removeItem(at: root)
                throw error ?? ZipError.extractionFailed
            }
            extractedRoot = root.resolvingSymlinksInPath()
            return
        }
        guard let archive = Archive(url: url, accessMode: .read) else {
            throw ZipError.invalidArchive
        }
        self.archive = archive
    }
    
    func closeArchive() {
        archive = nil
        if let extractedRoot { try? FileManager.default.removeItem(at: extractedRoot) }
        extractedRoot = nil
    }
    
    func loadEntries() throws -> [ZipEntry] {
        if let extractedRoot {
            guard let enumerator = FileManager.default.enumerator(at: extractedRoot,
                                                                  includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey]) else {
                throw ZipError.invalidArchive
            }
            return try enumerator.compactMap { item -> ZipEntry? in
                guard let url = item as? URL else { return nil }
                let values = try url.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey])
                guard let rootIndex = url.pathComponents.firstIndex(of: extractedRoot.lastPathComponent) else {
                    throw ZipError.invalidArchive
                }
                let path = url.pathComponents.dropFirst(rootIndex + 1).joined(separator: "/")
                return ZipEntry(path: path, name: url.lastPathComponent,
                                size: UInt64(values.fileSize ?? 0), compressedSize: 0,
                                isDirectory: values.isDirectory ?? false,
                                modificationDate: values.contentModificationDate, crc32: 0)
            }
        }
        guard let archive = archive else {
            throw ZipError.invalidArchive
        }
        
        var entries: [ZipEntry] = []
        for entry in archive {
            let zipEntry = ZipEntry(
                path: entry.path,
                name: (entry.path as NSString).lastPathComponent,
                size: entry.uncompressedSize,
                compressedSize: entry.compressedSize,
                isDirectory: entry.type == .directory,
                modificationDate: entry.fileAttributes[.modificationDate] as? Date,
                crc32: entry.checksum
            )
            entries.append(zipEntry)
        }
        return entries
    }
    
    func extract(entry: ZipEntry, to destination: URL, progress: Progress) throws {
        if let extractedRoot {
            let source = extractedRoot.appendingPathComponent(entry.path)
            guard FileManager.default.fileExists(atPath: source.path) else { throw ZipError.fileNotFound }
            try FileManager.default.copyItem(at: source, to: destination)
            progress.completedUnitCount = progress.totalUnitCount
            return
        }
        guard let archive = archive else {
            throw ZipError.invalidArchive
        }
        
        guard let zipEntry = archive[entry.path] else {
            throw ZipError.fileNotFound
        }
        
        try archive.extract(zipEntry, to: destination, progress: progress)
    }
    
    func extract(entries: [ZipEntry], to destination: URL, progress: Progress? = nil) async throws {
        if let extractedRoot {
            let totalSize = entries.reduce(0) { $0 + Int64($1.size) }
            progress?.totalUnitCount = totalSize
            var extractedSize: Int64 = 0
            for entry in entries {
                let source = extractedRoot.appendingPathComponent(entry.path)
                guard FileManager.default.fileExists(atPath: source.path) else { throw ZipError.fileNotFound }
                let target = destination.appendingPathComponent(entry.path)
                try FileManager.default.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
                try FileManager.default.copyItem(at: source, to: target)
                extractedSize += Int64(entry.size)
                progress?.completedUnitCount = extractedSize
            }
            return
        }
        guard let archive = archive else {
            throw ZipError.invalidArchive
        }
        
        let totalSize = entries.reduce(0) { $0 + Int64($1.size) }
        progress?.totalUnitCount = totalSize
        
        var extractedSize: Int64 = 0
        
        for entry in entries {
            guard let zipEntry = archive[entry.path] else { continue }
            
            let entryURL = destination.appendingPathComponent(entry.path)
            let entryDir = entryURL.deletingLastPathComponent()
            
            try FileManager.default.createDirectory(
                at: entryDir,
                withIntermediateDirectories: true,
                attributes: nil
            )
            
            try archive.extract(zipEntry, to: entryURL, progress: nil)
            extractedSize += Int64(entry.size)
            progress?.completedUnitCount = extractedSize
        }
    }
    
    func extractToTemporary(entry: ZipEntry) throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        
        let destination = tempDir.appendingPathComponent(entry.name)
        try extract(entry: entry, to: destination, progress: Progress())
        
        return destination
    }

}
