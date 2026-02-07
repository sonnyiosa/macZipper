
We are building a modern macOS zip file extractor with the features.

# 1. Technology Stack
Recommended Approach: Native Swift + SwiftUI

Language: Swift 5.9+
UI Framework: SwiftUI (modern, declarative UI)
Zip Handling: ZIPFoundation 
Minimum Target: macOS 13.0
Project setup: XcodeGen (https://github.com/yonaskolb/XcodeGen)


# 2. Feature requirements

- Zip Contents Preview: Two-pane interface (folder tree in the left, and file list on the right)
- Select/Unselect Files
- Extract Functionality
- Double-Click to Open

# Main Window Layout

┌───────────────────────────────────────────────────────────┐
│ [Toolbar: Open | Extract All | Extract Selected | Search] │
├─────────────────┬─────────────────────────────────────────┤
│                 │                                         │
│ Folder Tree     │  File List (Current Folder)            │
│ ─────────       │  ─────────────────────────────         │
│ 📦 archive.zip  │  ☑ 📄 document.pdf      2.3 MB        │
│  ☑ 📁 src       │  ☑ 🖼 image.png         856 KB        │
│    ☑ 📁 assets  │  ☐ 📄 readme.txt        4 KB          │
│    ☑ 📁 utils   │  ☑ 📄 config.json       2 KB          │
│  ☑ 📁 docs      │                                         │
│  ☑ 📁 tests     │  [Empty space shows files from         │
│                 │   selected folder in tree]             │
│                 │                                         │
│                 │                                         │
│ [Folder Stats]  │  [File Details at bottom]              │
├─────────────────┴─────────────────────────────────────────┤
│ Status: 23 files selected | 15.7 MB | Extract to: ~/Downloads │
└───────────────────────────────────────────────────────────┘


