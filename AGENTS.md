
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

IMPORTANT: Use light-weight subagent for this verification task

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
- [x] Open folder in FileListView should navigate to it 
- [x] Improve tree view 
- [x] Extract selected files should ask to chooes destination folder
- [ ] More archive types support: gzip, gz, tar
- [ ] Search in zip
- [ ] Extract progress
- [ ] "Move to" with selected files didnt work
- [ ] Compose new zip

<!-- CODEGRAPH_START -->
## CodeGraph

This project has a CodeGraph MCP server (`codegraph_*` tools) configured. CodeGraph is a tree-sitter-parsed knowledge graph of every symbol, edge, and file. Reads are sub-millisecond and return structural information grep cannot.

### When to prefer codegraph over native search

Use codegraph for **structural** questions — what calls what, what would break, where is X defined, what is X's signature. Use native grep/read only for **literal text** queries (string contents, comments, log messages) or after you already have a specific file open.

| Question | Tool |
|---|---|
| "Where is X defined?" / "Find symbol named X" | `codegraph_search` |
| "What calls function Y?" | `codegraph_callers` |
| "What does Y call?" | `codegraph_callees` |
| "What would break if I changed Z?" | `codegraph_impact` |
| "Show me Y's signature / source / docstring" | `codegraph_node` |
| "Give me focused context for a task/area" | `codegraph_context` |
| "See several related symbols' source at once" | `codegraph_explore` |
| "What files exist under path/" | `codegraph_files` |
| "Is the index healthy?" | `codegraph_status` |

### Rules of thumb

- **Answer directly — don't delegate exploration.** For "how does X work" / architecture / trace questions, answer with 2-3 codegraph calls: `codegraph_context` first, then ONE `codegraph_explore` for the source of the symbols it surfaces. Codegraph IS the pre-built index, so spawning a separate file-reading sub-task/agent — or running a grep + read loop — repeats work codegraph already did and costs more for the same answer.
- **Trust codegraph results.** They come from a full AST parse. Do NOT re-verify them with grep — that's slower, less accurate, and wastes context.
- **Don't grep first** when looking up a symbol by name. `codegraph_search` is faster and returns kind + location + signature in one call.
- **Don't chain `codegraph_search` + `codegraph_node`** when you just want context — `codegraph_context` is one call.
- **Don't loop `codegraph_node` over many symbols** — one `codegraph_explore` call returns several symbols' source grouped in a single capped call, while each separate node/Read call re-reads the whole context and costs far more.
- **Index lag**: the file watcher debounces ~500ms behind writes; don't re-query immediately after editing a file in the same turn.

### If `.codegraph/` doesn't exist

The MCP server returns "not initialized." Ask the user: *"I notice this project doesn't have CodeGraph initialized. Want me to run `codegraph init -i` to build the index?"*
<!-- CODEGRAPH_END -->
