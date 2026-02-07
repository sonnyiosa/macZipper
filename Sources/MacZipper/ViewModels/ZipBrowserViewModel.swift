import SwiftUI
import ZIPFoundation

enum ZipperError: Error, LocalizedError {
    case invalidArchive
    case extractionFailed
    case fileNotFound
    case previewFailed
    
    var errorDescription: String? {
        switch self {
        case .invalidArchive:
            return "The selected file is not a valid ZIP archive."
        case .extractionFailed:
            return "Failed to extract files. Please check permissions and available disk space."
        case .fileNotFound:
            return "The requested file was not found in the archive."
        case .previewFailed:
            return "Failed to preview file."
        }
    }
}

@MainActor
class ZipBrowserViewModel: ObservableObject {
    @Published var rootNode: ZipEntryNode?
    @Published var currentFolder: ZipEntryNode?
    @Published var selectedPaths: Set<String> = []
    @Published var isLoaded = false
    @Published var extractDestination: URL?
    @Published var isExtracting = false
    @Published var extractionProgress: Double = 0
    @Published var archiveURL: URL?
    @Published var errorMessage: String?
    @Published var showError = false
    @Published var lastError: Error?
    @Published var isLoading = false
    
    @AppStorage("lastExtractDestination") private var lastExtractDestinationBookmark: Data?
    @AppStorage("windowWidth") private var windowWidth: Double = 1000
    @AppStorage("windowHeight") private var windowHeight: Double = 700
    
    private let zipService = ZipService()
    private let previewService = FilePreviewService()
    private var allEntries: [ZipEntry] = []
    
    var windowSize: CGSize {
        get { CGSize(width: windowWidth, height: windowHeight) }
        set {
            windowWidth = newValue.width
            windowHeight = newValue.height
        }
    }
    
    func loadLastDestination() -> URL? {
        guard let bookmark = lastExtractDestinationBookmark else { return nil }
        var isStale = false
        return try? URL(resolvingBookmarkData: bookmark, bookmarkDataIsStale: &isStale)
    }
    
    func saveDestination(_ url: URL) {
        if let bookmark = try? url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil) {
            lastExtractDestinationBookmark = bookmark
        }
    }
    
    var currentEntries: [ZipEntryNode] {
        if let folder = currentFolder {
            return folder.children?.sorted { ($0.isDirectory ? 0 : 1) < ($1.isDirectory ? 0 : 1) } ?? []
        }
        return rootNode?.children?.sorted { ($0.isDirectory ? 0 : 1) < ($1.isDirectory ? 0 : 1) } ?? []
    }
    
    var selectedSize: UInt64 {
        selectedPaths.reduce(0) { total, path in
            if let entry = allEntries.first(where: { $0.path == path }) {
                return total + entry.size
            }
            return total
        }
    }
    
    func loadArchive(from url: URL) async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            archiveURL = url
            try await zipService.openArchive(at: url)
            allEntries = try await zipService.loadEntries()
            rootNode = buildTree(from: allEntries)
            currentFolder = rootNode
            isLoaded = true
            selectedPaths.removeAll()
            
            // Set default extract destination: last used location, or zip's folder
            if let lastDest = loadLastDestination() {
                extractDestination = lastDest
            } else {
                extractDestination = url.deletingLastPathComponent()
            }
        } catch {
            lastError = error
            errorMessage = "Failed to load archive: \(error.localizedDescription)"
            showError = true
            isLoaded = false
        }
    }
    
    func previewEntry(at path: String) async {
        guard let archiveURL = archiveURL,
              let entry = allEntries.first(where: { $0.path == path }),
              !entry.isDirectory else { return }
        
        do {
            try await previewService.previewFile(entry: entry, from: archiveURL, using: zipService)
        } catch {
            lastError = error
            errorMessage = "Failed to preview file: \(error.localizedDescription)"
            showError = true
        }
    }
    
    func selectFolder(_ node: ZipEntryNode) {
        currentFolder = node
        node.isExpanded.toggle()
    }
    
    func selectionState(for path: String) -> SelectionState {
        if path.isEmpty {
            // Root node - check all children
            guard let children = rootNode?.children, !children.isEmpty else { return .none }
            let allSelected = children.allSatisfy { isPathSelected($0.path) }
            let anySelected = children.contains { isPathSelected($0.path) || selectionState(for: $0.path) != .none }
            if allSelected { return .all }
            if anySelected { return .partial }
            return .none
        }
        
        if let node = findNode(at: path) {
            if node.isDirectory, let children = node.children {
                let allSelected = children.allSatisfy { isPathSelected($0.path) }
                let anySelected = children.contains { isPathSelected($0.path) || selectionState(for: $0.path) != .none }
                if allSelected { return .all }
                if anySelected { return .partial }
                return .none
            }
        }
        
        return isPathSelected(path) ? .all : .none
    }
    
    func toggleSelection(for path: String) {
        let currentlySelected = isPathSelected(path)
        
        if currentlySelected {
            // Deselect this path and all children
            if let node = findNode(at: path) {
                for childPath in node.allEntries.map(\.path) {
                    selectedPaths.remove(childPath)
                }
            } else {
                selectedPaths.remove(path)
            }
        } else {
            // Select this path and all children
            if let node = findNode(at: path) {
                for childPath in node.allEntries.map(\.path) {
                    selectedPaths.insert(childPath)
                }
            } else {
                selectedPaths.insert(path)
            }
        }
    }
    
    func isPathSelected(_ path: String) -> Bool {
        return selectedPaths.contains(path)
    }
    
    func selectAll() {
        for entry in allEntries where !entry.isDirectory {
            selectedPaths.insert(entry.path)
        }
    }
    
    func deselectAll() {
        selectedPaths.removeAll()
    }
    
    func extractAll() async {
        let entriesToExtract = allEntries.filter { !$0.isDirectory }
        await extractEntries(entriesToExtract)
    }
    
    func extractSelected() async {
        let entriesToExtract = allEntries.filter { entry in
            selectedPaths.contains(entry.path) && !entry.isDirectory
        }
        await extractEntries(entriesToExtract)
    }
    
    private func extractEntries(_ entries: [ZipEntry]) async {
        guard let destination = extractDestination, !entries.isEmpty else {
            errorMessage = "No destination folder selected."
            showError = true
            return
        }
        
        isExtracting = true
        extractionProgress = 0
        
        defer {
            isExtracting = false
        }
        
        do {
            let progress = Progress()
            progress.totalUnitCount = Int64(entries.reduce(0) { $0 + $1.size })
            
            try await zipService.extract(entries: entries, to: destination, progress: progress)
            extractionProgress = 1.0
            
            // Save this destination for next time
            saveDestination(destination)
        } catch {
            lastError = error
            errorMessage = "Extraction failed: \(error.localizedDescription)"
            showError = true
        }
    }
    
    private func buildTree(from entries: [ZipEntry]) -> ZipEntryNode {
        let root = ZipEntryNode.root()
        var pathToNode: [String: ZipEntryNode] = ["": root]
        
        let sortedEntries = entries.sorted { $0.path < $1.path }
        
        for entry in sortedEntries {
            let components = entry.path.split(separator: "/").map(String.init)
            var currentPath = ""
            var parentNode = root
            
            for (index, component) in components.enumerated() {
                let isLast = index == components.count - 1
                currentPath = currentPath.isEmpty ? component : currentPath + "/" + component
                
                if let existingNode = pathToNode[currentPath] {
                    parentNode = existingNode
                } else {
                    let newNode = ZipEntryNode(
                        path: currentPath,
                        name: component,
                        isDirectory: entry.isDirectory || !isLast,
                        size: isLast ? entry.size : 0,
                        modificationDate: isLast ? entry.modificationDate : nil
                    )
                    pathToNode[currentPath] = newNode
                    
                    if parentNode.children == nil {
                        parentNode.children = []
                    }
                    parentNode.children?.append(newNode)
                    parentNode = newNode
                }
            }
        }
        
        return root
    }
    
    private func findNode(at path: String) -> ZipEntryNode? {
        guard let root = rootNode else { return nil }
        if path.isEmpty { return root }
        return findNodeRecursive(node: root, targetPath: path)
    }
    
    private func findNodeRecursive(node: ZipEntryNode, targetPath: String) -> ZipEntryNode? {
        if node.path == targetPath {
            return node
        }
        guard let children = node.children else { return nil }
        for child in children {
            if let found = findNodeRecursive(node: child, targetPath: targetPath) {
                return found
            }
        }
        return nil
    }
}
