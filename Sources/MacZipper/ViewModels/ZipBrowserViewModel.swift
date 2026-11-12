import SwiftUI
import ZIPFoundation
import UniformTypeIdentifiers

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
    @Published var showPasswordPrompt = false
    @Published var passwordErrorMessage: String?
    @Published var sortOption: SortOption = .name
    @Published var sortOrder: SortOrder = .ascending
    @Published var quickLookURL: URL?
    @Published var showQuickLook = false
    @Published var selectedEntryForQuickLook: ZipEntry?
    @Published var extractionCompletedMessage: String? = nil
    @Published var activatedPath: String? = nil

    // Navigation history for file list (independent from sidebar)
    @Published var fileListFolder: ZipEntryNode?
    private var navigationHistory: [ZipEntryNode?] = []
    private var forwardHistory: [ZipEntryNode?] = []
    
    var canGoBack: Bool { !navigationHistory.isEmpty }
    var canGoForward: Bool { !forwardHistory.isEmpty }
    
    var breadcrumbPath: String {
        var pathComponents: [String] = []
        var current = fileListFolder
        
        // Collect path components from leaf to root
        while let node = current, !node.path.isEmpty {
            pathComponents.append(node.name)
            current = findParent(of: node)
        }
        
        // Reverse to get root-to-leaf order and prepend Archive
        pathComponents.reverse()
        return (["Archive"] + pathComponents).joined(separator: " > ")
    }
    
    /// Returns breadcrumb segments as tuples of (displayName, node) for clickable navigation.
    /// First segment is always ("Archive", nil) representing the root.
    var breadcrumbSegments: [(name: String, node: ZipEntryNode?)] {
        var segments: [(String, ZipEntryNode?)] = [("Archive", nil)]
        var current = fileListFolder
        var pathSegments: [(String, ZipEntryNode?)] = []
        
        while let node = current, !node.path.isEmpty {
            pathSegments.append((node.name, node))
            current = findParent(of: node)
        }
        
        return segments + pathSegments.reversed()
    }
    
    private func findParent(of node: ZipEntryNode) -> ZipEntryNode? {
        guard let root = rootNode else { return nil }
        return findParentRecursive(parent: root, target: node)
    }
    
    private func findParentRecursive(parent: ZipEntryNode, target: ZipEntryNode) -> ZipEntryNode? {
        guard let children = parent.children else { return nil }
        for child in children {
            if child.path == target.path {
                return parent
            }
            if let found = findParentRecursive(parent: child, target: target) {
                return found
            }
        }
        return nil
    }
    
    @AppStorage("lastExtractDestination") private var lastExtractDestinationBookmark: Data?
    
    private let zipService = ZipService()
    private let previewService = FilePreviewService()
    private let filterManager = FilterManager()
    private var allEntries: [ZipEntry] = []
    
    var filterManagerAccess: FilterManager { filterManager }
    
    var filteredCountInfo: String {
        let visibleCount = allEntries.filter { !$0.isDirectory }.count
        let totalCount = allEntries.count
        return "\(visibleCount) items"
    }
    
    func loadLastDestination() -> URL? {
        guard let bookmark = lastExtractDestinationBookmark else { return nil }
        var isStale = false
        return try? URL(resolvingBookmarkData: bookmark, bookmarkDataIsStale: &isStale)
    }
    
    func reloadWithFilters() async {
        guard let url = archiveURL else { return }
        await loadArchive(from: url)
    }
    
    func saveDestination(_ url: URL) {
        if let bookmark = try? url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil) {
            lastExtractDestinationBookmark = bookmark
        }
    }
    
    var currentEntries: [ZipEntryNode] {
        let entries: [ZipEntryNode]
        if let folder = fileListFolder {
            entries = folder.children ?? []
        } else {
            entries = rootNode?.children ?? []
        }
        
        // Sort directories first, then by selected sort option
        return entries.sorted { a, b in
            // Directories always come first
            if a.isDirectory != b.isDirectory {
                return a.isDirectory
            }
            
            // Apply user-selected sort
            let result: Bool
            switch sortOption {
            case .name:
                result = a.name.localizedStandardCompare(b.name) == .orderedAscending
            case .size:
                result = a.size < b.size
            case .date:
                if let dateA = a.modificationDate, let dateB = b.modificationDate {
                    result = dateA < dateB
                } else if a.modificationDate != nil {
                    result = true
                } else if b.modificationDate != nil {
                    result = false
                } else {
                    result = a.name < b.name
                }
            }
            
            return sortOrder == .ascending ? result : !result
        }
    }
    
    var selectedSize: UInt64 {
        selectedPaths.reduce(0) { total, path in
            if let entry = allEntries.first(where: { $0.path == path }) {
                return total + entry.size
            }
            return total
        }
    }
    
    func loadArchive(from url: URL, password: String? = nil) async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            archiveURL = url
            try await zipService.openArchive(at: url, password: password)
            let rawEntries = try await zipService.loadEntries()
            allEntries = filterManager.filter(entries: rawEntries)
            rootNode = buildTree(from: allEntries)
            rootNode?.isExpanded = true
            currentFolder = rootNode
            fileListFolder = rootNode
            navigationHistory.removeAll()
            forwardHistory.removeAll()
            isLoaded = true
            showPasswordPrompt = false
            passwordErrorMessage = nil
            selectedPaths.removeAll()
            
            // Set default extract destination: last used location, or zip's folder
            if let lastDest = loadLastDestination() {
                extractDestination = lastDest
            } else {
                extractDestination = url.deletingLastPathComponent()
            }
        } catch {
            if let zipError = error as? ZipError,
               zipError == .passwordRequired || zipError == .incorrectPassword {
                isLoaded = false
                showPasswordPrompt = true
                passwordErrorMessage = zipError == .incorrectPassword ? zipError.localizedDescription : nil
                return
            }
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
    
    func quickLookEntry(at path: String) async {
        guard let archiveURL = archiveURL,
              let entry = allEntries.first(where: { $0.path == path }),
              !entry.isDirectory else { return }
        
        do {
            let url = try await previewService.extractForQuickLook(entry: entry, from: archiveURL, using: zipService)
            await MainActor.run {
                self.quickLookURL = url
                self.selectedEntryForQuickLook = entry
                self.showQuickLook = true
            }
        } catch {
            lastError = error
            errorMessage = "Failed to prepare preview: \(error.localizedDescription)"
            showError = true
        }
    }
    
    func getFirstSelectedEntry() -> ZipEntry? {
        guard let firstPath = selectedPaths.first else { return nil }
        return allEntries.first { $0.path == firstPath && !$0.isDirectory }
    }

    func activateEntry(at path: String) {
        activatedPath = path
    }

    func getActivatedEntry() -> ZipEntry? {
        guard let path = activatedPath else { return nil }
        return allEntries.first { $0.path == path && !$0.isDirectory }
    }

    func quickLookActivatedEntry() async {
        guard let entry = getActivatedEntry() else { return }
        await quickLookEntry(at: entry.path)
    }
    
    func selectFolder(_ node: ZipEntryNode) {
        currentFolder = node
        node.isExpanded.toggle()
    }
    
    /// Navigate the file list into a folder (double-click).
    /// Pushes current folder to back-stack, clears forward-stack.
    func navigateToFolder(_ node: ZipEntryNode) {
        guard node.isDirectory else { return }
        navigationHistory.append(fileListFolder)
        forwardHistory.removeAll()
        fileListFolder = node
        node.isExpanded = true
    }
    
    /// Go back to the previous folder in navigation history.
    func navigateBack() {
        guard let previous = navigationHistory.popLast() else { return }
        forwardHistory.append(fileListFolder)
        fileListFolder = previous
    }
    
    /// Go forward in navigation history.
    func navigateForward() {
        guard let next = forwardHistory.popLast() else { return }
        navigationHistory.append(fileListFolder)
        fileListFolder = next
    }
    
    /// Navigate to a specific breadcrumb location.
    /// nil node represents the root (Archive).
    func navigateToBreadcrumb(_ node: ZipEntryNode?) {
        // Don't navigate if already at this location
        if node?.path == fileListFolder?.path {
            return
        }
        
        // Push current to history, clear forward history
        navigationHistory.append(fileListFolder)
        forwardHistory.removeAll()
        fileListFolder = node
        
        // Expand the folder if it exists
        if let node = node {
            node.isExpanded = true
        }
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
        guard let archiveURL = archiveURL else { return }
        
        let destination = archiveURL.deletingLastPathComponent()
        let entriesToExtract = allEntries.filter { !$0.isDirectory }
        await extractEntries(entriesToExtract, to: destination)
    }
    
    func extractSelected() async {
        let entriesToExtract = allEntries.filter { entry in
            selectedPaths.contains(entry.path) && !entry.isDirectory
        }
        await extractEntries(entriesToExtract, to: extractDestination)
    }
    
    func extractSelected(to destination: URL) async {
        let entriesToExtract = allEntries.filter { entry in
            selectedPaths.contains(entry.path) && !entry.isDirectory
        }
        await extractEntries(entriesToExtract, to: destination)
    }
    
    private func extractEntries(_ entries: [ZipEntry], to destination: URL?) async {
        guard let destination = destination, !entries.isEmpty else {
            errorMessage = "No destination folder selected."
            showError = true
            return
        }

        isExtracting = true
        extractionProgress = 0
        extractionCompletedMessage = nil

        defer {
            isExtracting = false
        }

        do {
            let progress = Progress()
            progress.totalUnitCount = Int64(entries.reduce(0) { $0 + $1.size })

            try await zipService.extract(entries: entries, to: destination, progress: progress)
            extractionProgress = 1.0

            // Set completion message
            let itemCount = entries.count
            extractionCompletedMessage = "Extracted \(itemCount) item\(itemCount == 1 ? "" : "s")"

            // Auto-clear after 3 seconds
            Task {
                try? await Task.sleep(for: .seconds(3))
                await MainActor.run {
                    if self.extractionCompletedMessage != nil {
                        self.extractionCompletedMessage = nil
                    }
                }
            }

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
                        compressedSize: isLast ? entry.compressedSize : 0,
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
