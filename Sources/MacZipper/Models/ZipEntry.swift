import Foundation

struct ZipEntry: Identifiable, Equatable {
    let id = UUID()
    let path: String
    let name: String
    let size: UInt64
    let compressedSize: UInt64
    let isDirectory: Bool
    let modificationDate: Date?
    let crc32: UInt32
}
