import Foundation
import ZIPFoundation

enum ZipError: Error {
    case invalidArchive
    case extractionFailed
    case fileNotFound
}

actor ZipService {
    private var archive: Archive?
    
    func openArchive(at url: URL) throws {
        guard let archive = Archive(url: url, accessMode: .read) else {
            throw ZipError.invalidArchive
        }
        self.archive = archive
    }
    
    func closeArchive() {
        archive = nil
    }
    
    func loadEntries() throws -> [ZipEntry] {
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
        guard let archive = archive else {
            throw ZipError.invalidArchive
        }
        
        guard let zipEntry = archive[entry.path] else {
            throw ZipError.fileNotFound
        }
        
        try archive.extract(zipEntry, to: destination, progress: progress)
    }
    
    func extract(entries: [ZipEntry], to destination: URL, progress: Progress? = nil) async throws {
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
