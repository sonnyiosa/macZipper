# MacZipper - Comprehensive Development Plan

## Overview

Building a native macOS zip file extractor using **Swift 5.9+**, **SwiftUI**, and **ZIPFoundation** with project management via **XcodeGen**.

## Technology Stack

- **Language**: Swift 5.9+
- **UI Framework**: SwiftUI (modern, declarative UI)
- **Zip Handling**: ZIPFoundation
- **Minimum Target**: macOS 13.0
- **Project Setup**: XcodeGen

## Design Decisions

Based on user preferences:

1. **Multiple Window Support** - Each archive opens in its own window (standard macOS document-based app behavior)
2. **Default Extraction Destination** - Same folder as the source .zip file
3. **Persistence** - Use `@AppStorage`/`UserDefaults` for window state and preferences

## Phase 1: Project Setup & Foundation

### 1.1 Project Structure

```
macos_zipper/
├── project.yml                 # XcodeGen spec
├── Package.swift               # SPM for ZIPFoundation dependency
├── Sources/
│   └── MacZipper/
│       ├── App/
│       │   └── MacZipperApp.swift
│       ├── Models/
│       │   ├── ArchiveEntry.swift
│       │   ├── ArchiveFolder.swift
│       │   └── SelectionState.swift
│       ├── ViewModels/
│       │   └── ArchiveViewModel.swift
│       ├── Views/
│       │   ├── MainWindow/
│       │   │   ├── ContentView.swift
│       │   │   ├── ToolbarView.swift
│       │   │   └── StatusBarView.swift
│       │   ├── Sidebar/
│       │   │   ├── FolderTreeView.swift
│       │   │   └── FolderRowView.swift
│       │   ├── FileList/
│       │   │   ├── FileListView.swift
│       │   │   └── FileRowView.swift
│       │   └── Shared/
│       │       ├── FileIconView.swift
│       │       └── CheckboxView.swift
│       ├── Services/
│       │   ├── ZipService.swift
│       │   └── FilePreviewService.swift
│       ├── Extensions/
│       │   └── Entry+Extensions.swift
│       └── Resources/
│           └── Assets.xcassets
├── Tests/
│   └── MacZipperTests/
│       ├── ZipServiceTests.swift
│       └── ArchiveViewModelTests.swift
└── .gitignore
```

### 1.2 XcodeGen Configuration

**project.yml:**

```yaml
name: MacZipper
options:
  bundleIdPrefix: com.yourcompany
  deploymentTarget:
    macOS: "13.0"
  xcodeVersion: "15.0"
  generateEmptyDirectories: true

packages:
  ZIPFoundation:
    url: https://github.com/weichsel/ZIPFoundation.git
    from: 0.9.20

targets:
  MacZipper:
    type: application
    platform: macOS
    sources:
      - Sources/MacZipper
    dependencies:
      - package: ZIPFoundation
    settings:
      base:
        PRODUCT_NAME: MacZipper
        INFOPLIST_FILE: Sources/MacZipper/Resources/Info.plist
        MACOSX_DEPLOYMENT_TARGET: "13.0"
        SWIFT_VERSION: "5.9"
    info:
      path: Sources/MacZipper/Resources/Info.plist
      properties:
        CFBundleDisplayName: MacZipper
        CFBundleShortVersionString: "1.0"
        CFBundleVersion: "1"
        LSMinimumSystemVersion: "13.0"
        NSHumanReadableCopyright: "Copyright 2026"
        CFBundleDocumentTypes:
          - CFBundleTypeName: ZIP Archive
            CFBundleTypeRole: Viewer
            LSItemContentTypes:
              - public.zip-archive
              - com.pkware.zip-archive

  MacZipperTests:
    type: bundle.unit-test
    platform: macOS
    sources:
      - Tests/MacZipperTests
    dependencies:
      - target: MacZipper
```

## Phase 2: Data Models

### 2.1 Core Models

**ArchiveEntry.swift** - Represents a single file/folder in the archive:
- `path: String` - Full path within archive
- `name: String` - File/folder name
- `isDirectory: Bool`
- `uncompressedSize: UInt64`
- `compressedSize: UInt64`
- `modificationDate: Date?`
- `isSelected: Bool` - Selection state for extraction

**ArchiveFolder.swift** - Tree structure for folder hierarchy:
- `name: String`
- `path: String`
- `children: [ArchiveFolder]`
- `files: [ArchiveEntry]`
- `isExpanded: Bool`
- `selectionState: SelectionState` (none, partial, all)

**SelectionState.swift** - Enum for checkbox tri-state:

```swift
enum SelectionState {
    case none
    case partial
    case all
}
```

## Phase 3: Core Services

### 3.1 ZipService

The service layer wrapping ZIPFoundation:

```swift
class ZipService {
    // Open and parse archive
    func openArchive(at url: URL) async throws -> [ArchiveEntry]
    
    // Build folder tree from flat entry list
    func buildFolderTree(from entries: [ArchiveEntry]) -> ArchiveFolder
    
    // Extract selected entries
    func extractEntries(
        _ entries: [ArchiveEntry],
        from archiveURL: URL,
        to destinationURL: URL,
        progress: Progress
    ) async throws
    
    // Extract single entry for preview (temp directory)
    func extractForPreview(
        entry: ArchiveEntry,
        from archiveURL: URL
    ) async throws -> URL
}
```

**Key ZIPFoundation APIs to use:**
- `Archive(url:accessMode:)` - Open archive
- `archive[path]` - Access entry by path
- `archive.extract(entry:to:)` - Extract individual entry
- Iterate via `Sequence` conformance

### 3.2 FilePreviewService

Handle double-click preview functionality:

```swift
class FilePreviewService {
    // Extract to temp directory and open with default app
    func previewEntry(_ entry: ArchiveEntry, from archive: URL) async throws
    
    // Clean up temp files on app quit
    func cleanupTempFiles()
}
```

## Phase 4: ViewModel Architecture

### 4.1 ArchiveViewModel (Main ViewModel)

```swift
@MainActor
class ArchiveViewModel: ObservableObject {
    // State
    @Published var archiveURL: URL?
    @Published var rootFolder: ArchiveFolder?
    @Published var selectedFolder: ArchiveFolder?
    @Published var allEntries: [ArchiveEntry] = []
    @Published var searchText: String = ""
    @Published var isLoading: Bool = false
    @Published var extractionProgress: Progress?
    @Published var errorMessage: String?
    
    // Computed
    var currentFolderFiles: [ArchiveEntry]  // Files in selected folder
    var selectedEntries: [ArchiveEntry]      // All selected entries
    var selectedCount: Int
    var selectedTotalSize: UInt64
    var destinationURL: URL                  // Default: Same folder as archive
    
    // Actions
    func openArchive(at url: URL) async
    func toggleSelection(for entry: ArchiveEntry)
    func toggleFolderSelection(for folder: ArchiveFolder)
    func selectAll()
    func deselectAll()
    func extractSelected(to destination: URL) async
    func extractAll(to destination: URL) async
    func previewEntry(_ entry: ArchiveEntry) async
}
```

## Phase 5: SwiftUI Views

### 5.1 Main Window Layout

```
┌─────────────────────────────────────────────────────────────┐
│                      ToolbarView                            │
│  [Open] [Extract All] [Extract Selected] [🔍 Search...]    │
├──────────────────┬──────────────────────────────────────────┤
│                  │                                          │
│  FolderTreeView  │         FileListView                    │
│  (NavigationView │    (Table with checkboxes)              │
│   Sidebar)       │                                          │
│                  │                                          │
├──────────────────┴──────────────────────────────────────────┤
│                     StatusBarView                           │
│  "23 files selected | 15.7 MB | Extract to: ~/Downloads"   │
└─────────────────────────────────────────────────────────────┘
```

### 5.2 View Components

**ContentView.swift** - Main container:

```swift
struct ContentView: View {
    @StateObject var viewModel = ArchiveViewModel()
    
    var body: some View {
        NavigationSplitView {
            FolderTreeView(viewModel: viewModel)
        } detail: {
            FileListView(viewModel: viewModel)
        }
        .toolbar { ToolbarView(viewModel: viewModel) }
        .safeAreaInset(edge: .bottom) {
            StatusBarView(viewModel: viewModel)
        }
    }
}
```

**FolderTreeView.swift** - Sidebar folder tree:
- `OutlineGroup` or `List` with `DisclosureGroup`
- Recursive folder display
- Tri-state checkboxes
- Selection highlighting

**FileListView.swift** - Main file list:
- macOS `Table` view with columns:
  - Checkbox
  - Icon + Name
  - Size
  - Date Modified
- Sorting support
- Search filtering
- Double-click handler for preview

**ToolbarView.swift** - Top toolbar:
- Open button (file picker)
- Extract All button
- Extract Selected button (disabled when nothing selected)
- Search field

**StatusBarView.swift** - Bottom status:
- Selection count & total size
- Extraction destination (clickable to change)
- Progress bar during extraction

## Phase 6: Key Features Implementation

### 6.1 Selection System

**Tri-state Checkbox Logic:**

1. File checkbox: simple toggle
2. Folder checkbox:
   - If `none` -> select all descendants
   - If `partial` or `all` -> deselect all descendants
3. Parent folder state updates propagate upward

**Implementation approach:**
- Store selection in `Set<String>` (paths) for O(1) lookup
- Compute folder states dynamically from children
- Use `@Published` for reactive updates

### 6.2 Double-Click Preview

```swift
func previewEntry(_ entry: ArchiveEntry) async {
    let tempURL = try await zipService.extractForPreview(entry, from: archiveURL)
    NSWorkspace.shared.open(tempURL)
}
```

### 6.3 Extraction with Progress

```swift
func extractSelected(to destination: URL) async {
    let progress = Progress(totalUnitCount: Int64(selectedEntries.count))
    extractionProgress = progress
    
    do {
        try await zipService.extractEntries(
            selectedEntries,
            from: archiveURL,
            to: destination,
            progress: progress
        )
    } catch {
        errorMessage = error.localizedDescription
    }
    
    extractionProgress = nil
}
```

## Phase 7: macOS Integration

### 7.1 Document-Based Architecture

For multiple window support:

```swift
@main
struct MacZipperApp: App {
    var body: some Scene {
        DocumentGroup(viewing: ZipDocument.self) { file in
            ContentView(document: file.document)
        }
        .commands {
            // Custom menu commands
        }
    }
}

// ZipDocument conforms to FileDocument
struct ZipDocument: FileDocument {
    static var readableContentTypes: [UTType] = [.zip]
    var archiveURL: URL
    // ...
}
```

This gives us:
- Native multiple window support
- Recent Documents menu
- Standard File > Open behavior
- Proper window lifecycle management

### 7.2 File Associations

In `Info.plist`:

```xml
<key>CFBundleDocumentTypes</key>
<array>
    <dict>
        <key>CFBundleTypeName</key>
        <string>ZIP Archive</string>
        <key>CFBundleTypeRole</key>
        <string>Viewer</string>
        <key>LSItemContentTypes</key>
        <array>
            <string>public.zip-archive</string>
            <string>com.pkware.zip-archive</string>
        </array>
    </dict>
</array>
```

### 7.3 Drag & Drop Support

```swift
.onDrop(of: [.fileURL], isTargeted: nil) { providers in
    // Handle dropped zip files
}
```

### 7.4 Menu Bar Integration

```swift
@main
struct MacZipperApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Open...") { /* open file picker */ }
                    .keyboardShortcut("o")
            }
        }
    }
}
```

## Phase 8: Development Milestones

| Phase | Description | Estimated Effort |
|-------|-------------|------------------|
| 1 | Project setup (XcodeGen, structure, dependencies) | 1-2 hours |
| 2 | ZipDocument (document-based foundation) | 1-2 hours |
| 3 | Data models & ZipService | 2-3 hours |
| 4 | ArchiveViewModel (core logic) | 3-4 hours |
| 5 | FolderTreeView (sidebar) | 2-3 hours |
| 6 | FileListView (main content) | 2-3 hours |
| 7 | Toolbar & StatusBar | 1-2 hours |
| 8 | Selection system (tri-state) | 2-3 hours |
| 9 | Extraction functionality | 2-3 hours |
| 10 | Double-click preview | 1-2 hours |
| 11 | Persistence (@AppStorage) | 1-2 hours |
| 12 | Polish & macOS integration | 2-3 hours |
| 13 | Testing & bug fixes | 2-3 hours |

**Total estimated: ~20-30 hours**

## Implementation Order

1. **Project scaffolding** - XcodeGen, folder structure, dependencies
2. **ZipDocument** - Document-based app foundation
3. **Models** - ArchiveEntry, ArchiveFolder, SelectionState
4. **ZipService** - Core zip operations with ZIPFoundation
5. **ArchiveViewModel** - State management & business logic
6. **FolderTreeView** - Sidebar with folder hierarchy
7. **FileListView** - Main content area with file table
8. **ToolbarView** - Actions toolbar
9. **StatusBarView** - Selection info & progress
10. **Selection system** - Tri-state checkbox propagation
11. **Extraction** - With progress tracking
12. **Preview** - Double-click to open
13. **Persistence** - AppStorage for preferences
14. **Polish** - Drag/drop, keyboard shortcuts, error handling

## ZIPFoundation Key Features

From the library documentation:

- Modern Swift API
- High Performance Compression and Decompression (uses Apple's libcompression)
- Large File Support
- In-Memory Archives
- Deterministic Memory Consumption
- No 3rd party dependencies on Apple platforms
- Progress Tracking and Cancellation support

### Key APIs

```swift
// Opening an archive
let archive = try Archive(url: archiveURL, accessMode: .read)

// Accessing entries by path
if let entry = archive["path/to/file.txt"] {
    // Access entry properties
    let uncompressedSize = entry.uncompressedSize
    let modificationDate = entry.modificationDate
}

// Extracting single entry
try archive.extract(entry, to: destinationURL)

// Iterating all entries
for entry in archive {
    print(entry.path)
}

// Progress tracking
let progress = Progress(totalUnitCount: 100)
try archive.extract(entry, to: destinationURL, progress: progress)
```

## Notes

- ZIPFoundation requires iOS 12.0+ / macOS 10.11+ (we target 13.0)
- ZIPFoundation 0.9.20 is the latest stable release
- XcodeGen 2.44.1 is the latest stable release
