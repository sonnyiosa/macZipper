
We are building a modern macOS zip file extractor with the features.

# 1. Technology Stack
Recommended Approach: Native Swift + SwiftUI

Language: Swift 5.9+
UI Framework: SwiftUI (modern, declarative UI)
Zip Handling: ZIPFoundation 
Minimum Target: macOS 13.0
Project setup: XcodeGen (https://github.com/yonaskolb/XcodeGen) 
 + Configured at: @project.yml


# 2. Feature requirements

- Zip Contents Preview: Two-pane interface (folder tree in the left, and file list on the right)
- Select/Unselect Files
- Extract Functionality
- Double-Click to Open

# 3. Archive Entry Filtering

Implements a configurable filter layer for excluding unwanted files and folders from archives.

## Filter Types

### Built-in Filters (Phase 1 - Implemented)
| Filter | Pattern | Description | Default |
|--------|---------|-------------|---------|
| **MacOSMetadataFilter** | `__MACOSX/*`, `._*`, `.DS_Store` | macOS resource forks and metadata | ✅ Enabled |
| **HiddenFilesFilter** | `.*` (dot files) | Unix hidden files | ❌ Disabled |
| **VersionControlFilter** | `.git/*`, `.svn/*`, `.hg/*` | Version control folders | ❌ Disabled |
| **CustomPatternFilter** | User-defined | Glob/regex patterns | ✅ Enabled (empty) |

## Key Files

- `Sources/MacZipper/Services/EntryFilter.swift` - Protocol and built-in filter implementations
- `Sources/MacZipper/Services/FilterManager.swift` - Central filter management with persistence
- `Tests/MacZipperTests/EntryFilterTests.swift` - Unit tests for filters

## Usage

Filters are applied at two stages:
1. **Display filtering**: When loading archive entries, `__MACOSX` and other filtered items are hidden from the UI
2. **Extraction filtering**: Filtered items are never extracted to the destination

The filter preferences are automatically persisted to UserDefaults and restored on app launch.

# Project Foundation
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
│       │   └── ZipBrowserViewModel.swift
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
│       │   ├── FilePreviewService.swift
│       │   ├── EntryFilter.swift           # Filter protocols & implementations
│       │   └── FilterManager.swift         # Filter management & persistence
│       ├── Extensions/
│       │   └── Entry+Extensions.swift
│       └── Resources/
│           └── Assets.xcassets
├── Tests/
│   └── MacZipperTests/
│       ├── ZipServiceTests.swift
│       └── EntryFilterTests.swift
└── .gitignore
```

# Build 

IMPORTANT: Use subagent for this verification task

To verify implementation compiles:

```
xcodegen generate --project .  # Regenerate Xcode project if files added
xcodebuild build -scheme MacZipper
```

To run tests:

```
xcodebuild test -scheme MacZipper -destination 'platform=macOS'
```

# Task progress

- [x] File list view scroller is hiding the last item
- [x] Implement archive entry filter layer (__MACOSX, .DS_Store filtering)
- [ ] Improve tree view 
- [ ] Extract selected files should ask to chooes destination folder
- [ ] Compose new zip 
- [ ] More archive types support: gzip, gz, tar
- [ ] Search in zip
- [ ] Open folder in FileListView should navigate to it 
- [ ] Extract progress
- [ ] "Move to" with selected files didnt work

