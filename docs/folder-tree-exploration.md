# Folder Tree View Implementation Documentation

This document provides a comprehensive overview of the folder tree view implementation in MacZipper, including the sidebar navigation system, selection mechanisms, and navigation history.

## Table of Contents

1. [Overview](#overview)
2. [FolderTreeView Structure](#foldertreeview-structure)
3. [FolderNodeView Implementation](#foldernodeview-implementation)
4. [Selection Mechanism](#selection-mechanism)
5. [Navigation System](#navigation-system)
6. [Right-Click Behavior](#right-click-behavior)
7. [File Paths](#file-paths)

---

## Overview

The folder tree view provides a hierarchical sidebar that displays the directory structure of a loaded ZIP archive. It consists of two main components:

- **FolderTreeView**: The container view that renders the entire tree structure
- **FolderNodeView**: Recursive view component that renders individual folder/file nodes

The system supports:
- Visual selection highlighting
- Folder expansion/collapse
- Search-based filtering
- Checkbox-based multi-select
- Navigation history independent of sidebar selection

---

## FolderTreeView Structure

**Location**: `Sources/MacZipper/Views/Main/FolderTreeView.swift`

```swift
struct FolderTreeView: View {
    @ObservedObject var viewModel: ZipBrowserViewModel
    @Binding var searchText: String
    
    var body: some View {
        List {
            if let root = viewModel.rootNode {
                FolderNodeView(
                    node: root,
                    viewModel: viewModel,
                    level: 0,
                    searchText: searchText
                )
            }
        }
        .listStyle(.sidebar)
        .padding(EdgeInsets(top: 0, leading: 0, bottom: 32, trailing: 0))
    }
}
```

### Key Characteristics

- Uses SwiftUI's `.sidebar` list style for a native macOS appearance
- Adds 32pt bottom padding to prevent the last item from being hidden by the status bar
- The tree is rendered recursively starting from the root node
- The `searchText` binding enables real-time filtering of the tree

---

## FolderNodeView Implementation

**Location**: `Sources/MacZipper/Views/Main/FolderTreeView.swift:23-124`

### Properties

```swift
struct FolderNodeView: View {
    @ObservedObject var node: ZipEntryNode        // The current node data
    @ObservedObject var viewModel: ZipBrowserViewModel  // Shared view model
    let level: Int                                // Indentation level (0 = root)
    let searchText: String                        // Filter text
    
    // Computed properties for selection and visibility
    private var isSelected: Bool { ... }
    var shouldShow: Bool { ... }
    var hasMatchingDescendant: Bool { ... }
}
```

### Layout Structure

Each node renders as an `HStack` containing:

1. **Checkbox Button**: Toggle selection state (square/minus-square/checkmark-square)
2. **Icon**: Folder icon (filled when expanded) or file icon based on extension
3. **Name Label**: Displays the entry name (shows "Archive" for root)
4. **Expand/Collapse Button**: Chevron indicator for directories with children
5. **Spacer**: Pushes chevron to the right

```swift
HStack(spacing: 4) {
    // Checkbox
    Button(action: { viewModel.toggleSelection(for: node.path) }) {
        Image(systemName: viewModel.selectionState(for: node.path).imageName)
    }
    
    // Icon
    if node.isDirectory {
        Image(systemName: node.isExpanded ? "folder.fill" : "folder")
    } else {
        Image(systemName: iconForFile(node.name))
    }
    
    // Name
    Text(node.name.isEmpty ? "Archive" : node.name)
    
    Spacer()
    
    // Expansion chevron (directories only)
    if node.isDirectory && node.children != nil {
        Button(action: { node.isExpanded.toggle() }) {
            Image(systemName: node.isExpanded ? "chevron.down" : "chevron.right")
        }
    }
}
.padding(.leading, CGFloat(level * 16))  // Indent based on depth
.background(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
.onTapGesture {
    if node.isDirectory {
        viewModel.selectFolder(node)
    }
}
```

### Recursive Rendering

Child nodes are conditionally rendered when the parent is expanded:

```swift
if node.isExpanded, let children = node.children {
    ForEach(children) { child in
        FolderNodeView(
            node: child,
            viewModel: viewModel,
            level: level + 1,
            searchText: searchText
        )
    }
}
```

### Search Filtering

Nodes are shown if:
- Search is empty (`shouldShow` returns true)
- The node name matches the search text (case-insensitive)
- **OR** any descendant matches the search (parent stays visible to show matching children)

```swift
var shouldShow: Bool {
    if searchText.isEmpty { return true }
    return node.name.localizedCaseInsensitiveContains(searchText) 
        || hasMatchingDescendant
}
```

### File Icon Mapping

```swift
private func iconForFile(_ filename: String) -> String {
    let ext = (filename as NSString).pathExtension.lowercased()
    switch ext {
    case "pdf": return "doc.text"
    case "jpg", "jpeg", "png", "gif", "bmp", "tiff": return "photo"
    case "txt", "md", "rtf": return "doc.plaintext"
    case "swift", "py", "js", "html", "css", "json": return "doc.text.fill"
    default: return "doc"
    }
}
```

---

## Selection Mechanism

### Two Different Behaviors

The sidebar uses **two different methods** for folder interaction:

#### 1. `selectFolder(_:)` - Sidebar Selection

**Purpose**: Updates the sidebar selection state (highlight) and toggles expansion

**Location**: `ZipBrowserViewModel.swift:260-263`

```swift
func selectFolder(_ node: ZipEntryNode) {
    currentFolder = node        // Updates sidebar highlight
    node.isExpanded.toggle()    // Expands/collapses the folder
}
```

**When Called**: 
- Single-tap on a folder in the sidebar (`FolderNodeView.onTapGesture`)

**Effect**:
- Changes the `currentFolder` property, which triggers the selection highlight
- Toggles the folder's expanded state
- Does NOT affect the file list view

#### 2. `navigateToFolder(_:)` - File List Navigation

**Purpose**: Navigates the file list view into a folder (like double-clicking)

**Location**: `ZipBrowserViewModel.swift:267-273`

```swift
func navigateToFolder(_ node: ZipEntryNode) {
    guard node.isDirectory else { return }
    navigationHistory.append(fileListFolder)  // Push current to back-stack
    forwardHistory.removeAll()                // Clear forward history
    fileListFolder = node                     // Navigate to new folder
    node.isExpanded = true                    // Auto-expand the folder
}
```

**When Called**:
- Double-click on a folder in `FileListView`
- Programmatic navigation (e.g., from breadcrumb)

**Effect**:
- Updates `fileListFolder`, which determines what `currentEntries` returns
- Pushes the previous folder to navigation history
- Clears the forward history (standard browser behavior)
- Auto-expands the folder in the sidebar

### Key Differences

| Aspect | `selectFolder` | `navigateToFolder` |
|--------|---------------|-------------------|
| Affects | Sidebar highlight only | File list content |
| History | No | Yes (pushes to back-stack) |
| Forward history | No change | Cleared |
| Expansion | Toggles | Always expands |
| Trigger | Single tap | Double click |

### Published Properties

```swift
@Published var currentFolder: ZipEntryNode?      // Sidebar selection
@Published var fileListFolder: ZipEntryNode?     // File list navigation target
```

### Selection State System

Each node has a checkbox with three states:

```swift
enum SelectionState {
    case none       // Empty square
    case partial    // Minus square (some children selected)
    case all        // Checkmark square (all children selected)
    
    var imageName: String {
        switch self {
        case .none: return "square"
        case .partial: return "minus.square"
        case .all: return "checkmark.square"
        }
    }
}
```

---

## Navigation System

### Navigation History

The file list maintains independent navigation history using two stacks:

```swift
// Navigation history for file list (independent from sidebar)
@Published var fileListFolder: ZipEntryNode?
private var navigationHistory: [ZipEntryNode?] = []  // Back stack
private var forwardHistory: [ZipEntryNode?] = []     // Forward stack

var canGoBack: Bool { !navigationHistory.isEmpty }
var canGoForward: Bool { !forwardHistory.isEmpty }
```

### Navigation Methods

#### Navigate Forward
```swift
func navigateToFolder(_ node: ZipEntryNode) {
    guard node.isDirectory else { return }
    navigationHistory.append(fileListFolder)  // Save current location
    forwardHistory.removeAll()                // Clear forward history
    fileListFolder = node                     // Move to new location
    node.isExpanded = true
}
```

#### Navigate Back
```swift
func navigateBack() {
    guard let previous = navigationHistory.popLast() else { return }
    forwardHistory.append(fileListFolder)     // Save current to forward
    fileListFolder = previous                 // Restore previous
}
```

#### Navigate Forward
```swift
func navigateForward() {
    guard let next = forwardHistory.popLast() else { return }
    navigationHistory.append(fileListFolder)  // Save current to history
    fileListFolder = next                     // Restore next
}
```

### Breadcrumb Navigation

The breadcrumb view provides clickable path navigation:

```swift
var breadcrumbSegments: [(name: String, node: ZipEntryNode?)] {
    var segments: [(String, ZipEntryNode?)] = [("Archive", nil)]
    var current = fileListFolder
    var pathSegments: [(String, ZipEntryNode?)] = []
    
    while let node = current, !node.path.isEmpty {
        pathSegments.append((node.name, node))
        current = findParent(of: node)  // Recursive parent lookup
    }
    
    return segments + pathSegments.reversed()
}
```

**Key Points**:
- Root is represented as `("Archive", nil)` - `nil` node means root
- Clicking a breadcrumb segment navigates to that folder
- Navigation pushes to history stack

### Parent Lookup

```swift
private func findParent(of node: ZipEntryNode) -> ZipEntryNode? {
    guard let root = rootNode else { return nil }
    return findParentRecursive(parent: root, target: node)
}

private func findParentRecursive(parent: ZipEntryNode, target: ZipEntryNode) -> ZipEntryNode? {
    guard let children = parent.children else { return nil }
    for child in children {
        if child.path == target.path { return parent }
        if let found = findParentRecursive(parent: child, target: target) {
            return found
        }
    }
    return nil
}
```

### Navigation UI

Located in `FileListView.swift`:

```swift
HStack(spacing: 4) {
    // Back button
    Button(action: { viewModel.navigateBack() }) {
        Image(systemName: "chevron.left")
    }
    .disabled(!viewModel.canGoBack)
    
    // Forward button
    Button(action: { viewModel.navigateForward() }) {
        Image(systemName: "chevron.right")
    }
    .disabled(!viewModel.canGoForward)
    
    // Clickable breadcrumb
    BreadcrumbView(
        segments: viewModel.breadcrumbSegments,
        onNavigate: { node in viewModel.navigateToBreadcrumb(node) }
    )
}
```

---

## Right-Click Behavior

**Current Status**: No right-click context menu exists

The folder tree view currently has **no right-click functionality**. Users can:
- Single-click to select and expand/collapse folders
- Use checkboxes for multi-selection
- Navigate via breadcrumb or double-click in file list

### Potential Future Enhancements

Common right-click actions that could be added:
- Extract folder contents
- Preview folder (show statistics)
- Copy path to clipboard
- Select all items in folder
- Expand/collapse recursively

---

## File Paths

### Core Implementation Files

| File | Purpose |
|------|---------|
| `Sources/MacZipper/Views/Main/FolderTreeView.swift` | FolderTreeView and FolderNodeView implementation |
| `Sources/MacZipper/ViewModels/ZipBrowserViewModel.swift` | Navigation logic, selection state, history management |
| `Sources/MacZipper/Models/ZipEntryNode.swift` | Tree node model with ObservableObject support |
| `Sources/MacZipper/Views/Main/FileListView.swift` | File list with navigation buttons and double-click handling |
| `Sources/MacZipper/Views/Components/BreadcrumbView.swift` | Clickable breadcrumb navigation component |

### Test Files

| File | Purpose |
|------|---------|
| `Tests/MacZipperTests/NavigationTests.swift` | Comprehensive navigation tests including history, breadcrumbs, and back/forward |

### Supporting Models

**ZipEntryNode** (`Sources/MacZipper/Models/ZipEntryNode.swift`):

```swift
class ZipEntryNode: Identifiable, ObservableObject {
    let id = UUID()
    let path: String
    let name: String
    let isDirectory: Bool
    let size: UInt64
    let compressedSize: UInt64
    let modificationDate: Date?
    
    @Published var children: [ZipEntryNode]?
    @Published var isExpanded: Bool = false
    
    var allEntries: [ZipEntryNode] { ... }  // Flattened list of all descendants
    var totalSize: UInt64 { ... }           // Recursive size calculation
    var totalCompressedSize: UInt64 { ... } // Recursive compressed size
    var compressionRatio: Double? { ... }   // Compression percentage
}
```

### ViewModel Key Properties

**Published Properties** (`ZipBrowserViewModel`):

```swift
@Published var rootNode: ZipEntryNode?           // Root of tree structure
@Published var currentFolder: ZipEntryNode?      // Sidebar selection highlight
@Published var fileListFolder: ZipEntryNode?     // File list current location
@Published var selectedPaths: Set<String> = []   // Paths of selected items
@Published var isLoaded = false                  // Archive loaded state
@Published var sortOption: SortOption = .name    // Current sort field
@Published var sortOrder: SortOrder = .ascending // Current sort direction
@Published var quickLookURL: URL?                // Quick Look preview URL
@Published var showQuickLook = false             // Quick Look visibility
```

### Key Methods Reference

**Navigation**:
- `selectFolder(_:)` - Update sidebar selection
- `navigateToFolder(_:)` - Navigate file list into folder
- `navigateBack()` - Go back in history
- `navigateForward()` - Go forward in history
- `navigateToBreadcrumb(_:)` - Navigate via breadcrumb

**Selection**:
- `toggleSelection(for:)` - Toggle selection with recursive children
- `selectionState(for:)` - Get checkbox state (none/partial/all)
- `selectAll()` / `deselectAll()` - Bulk selection
- `isPathSelected(_:)` - Check if path is selected

**Data Access**:
- `currentEntries` - Computed property returning sorted children of current folder
- `breadcrumbSegments` - Computed property for breadcrumb navigation
- `breadcrumbPath` - String representation of current path
- `findNode(at:)` - Find node by path
- `findParent(of:)` - Find parent of a node

---

## Usage Example

```swift
// In ContentView.swift
NavigationSplitView {
    FolderTreeView(viewModel: viewModel, searchText: $searchText)
        .frame(minWidth: 220)
} detail: {
    FileListView(viewModel: viewModel, searchText: $searchText)
}
```

The folder tree view and file list view share the same `ZipBrowserViewModel` instance, ensuring synchronized state between the sidebar and main content area.

---

## Architecture Notes

1. **Separation of Concerns**: Sidebar selection (`currentFolder`) is separate from file list navigation (`fileListFolder`)
2. **Observable Pattern**: Nodes use `@Published` for reactive UI updates
3. **Recursive Rendering**: Tree view uses recursive `FolderNodeView` calls
4. **History Management**: Standard back/forward stack pattern for navigation
5. **Selection Propagation**: Checkbox selection includes all children recursively
6. **Search Integration**: Search text filters both tree and list views

---

*Document created: 2025*
*Last updated: Reflects current implementation as of commit*
