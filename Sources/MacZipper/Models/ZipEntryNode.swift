import Foundation

class ZipEntryNode: Identifiable, ObservableObject {
    let id = UUID()
    let path: String
    let name: String
    let isDirectory: Bool
    let size: UInt64
    let modificationDate: Date?
    
    @Published var children: [ZipEntryNode]?
    @Published var isExpanded: Bool = false
    
    var allEntries: [ZipEntryNode] {
        if let children = children {
            return [self] + children.flatMap { $0.allEntries }
        }
        return [self]
    }
    
    var totalSize: UInt64 {
        if let children = children {
            return children.reduce(0) { $0 + $1.totalSize }
        }
        return size
    }
    
    init(path: String, name: String, isDirectory: Bool = false, size: UInt64 = 0, modificationDate: Date? = nil) {
        self.path = path
        self.name = name
        self.isDirectory = isDirectory
        self.size = size
        self.modificationDate = modificationDate
    }
    
    static func root() -> ZipEntryNode {
        return ZipEntryNode(path: "", name: "", isDirectory: true)
    }
}

enum SelectionState {
    case none, partial, all
    
    var isSelected: Bool {
        self == .all
    }
    
    var imageName: String {
        switch self {
        case .none:
            return "square"
        case .partial:
            return "minus.square"
        case .all:
            return "checkmark.square"
        }
    }
}
