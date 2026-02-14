# Double-Click Folder Navigation with Back/Forward History

## Overview

Add folder navigation to the **FileListView** (right pane) so it works **independently** from the sidebar tree. Double-clicking a folder navigates into it, and **Back/Forward** buttons let users move through their navigation history — similar to Finder's navigation.

This decouples the file list from the sidebar: they can show different folders independently.

## Current Behavior

- **Double-click** in FileListView only handles **files** (preview). Folders are ignored.
- **`currentFolder`** is a single `ZipEntryNode?` — no history stack.
- **Sidebar click** calls `selectFolder()` which sets `currentFolder` and toggles expansion.
- The sidebar and file list are tightly coupled — both driven by `currentFolder`.

---

## Proposed Changes

### 1. ViewModel — Navigation History Stack

#### [MODIFY] [ZipBrowserViewModel.swift](file:///Users/kevin/projects/macos_zipper/Sources/MacZipper/ViewModels/ZipBrowserViewModel.swift)

Add navigation history state and methods:

**New properties:**

```swift
// Navigation history for file list (independent from sidebar)
@Published var fileListFolder: ZipEntryNode?      // What the file list shows
private var navigationHistory: [ZipEntryNode?] = [] // Back stack
private var forwardHistory: [ZipEntryNode?] = []    // Forward stack

var canGoBack: Bool { !navigationHistory.isEmpty }
var canGoForward: Bool { !forwardHistory.isEmpty }
```

**New methods:**

```swift
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
```

**Modify `currentEntries`** to use `fileListFolder` instead of `currentFolder`:

```diff
 var currentEntries: [ZipEntryNode] {
     let entries: [ZipEntryNode]
-    if let folder = currentFolder {
+    if let folder = fileListFolder {
         entries = folder.children ?? []
     } else {
         entries = rootNode?.children ?? []
     }
     // ... sorting logic unchanged
 }
```

**Modify `loadArchive()`** — reset navigation history when a new archive is opened:

```diff
 rootNode?.isExpanded = true
-currentFolder = rootNode
+currentFolder = rootNode
+fileListFolder = rootNode
+navigationHistory.removeAll()
+forwardHistory.removeAll()
```

> [!IMPORTANT]
> `currentFolder` remains for sidebar selection. `fileListFolder` is the **independent** driver for the file list content. Sidebar clicks still set `currentFolder` only (tree highlighting). Double-click and back/forward buttons drive `fileListFolder` only.

---

### 2. FileListView — Double-Click + Back/Forward Buttons

#### [MODIFY] [FileListView.swift](file:///Users/kevin/projects/macos_zipper/Sources/MacZipper/Views/Main/FileListView.swift)

**Update double-click handler** (line 51–58):

```diff
 .onTapGesture(count: 2) {
-    // Double-click to preview
-    if !entry.isDirectory {
+    if entry.isDirectory {
+        viewModel.navigateToFolder(entry)
+    } else {
         Task {
             await viewModel.previewEntry(at: entry.path)
         }
     }
 }
```

**Add back/forward navigation bar** above the file list header:

```swift
// Navigation bar
HStack(spacing: 4) {
    Button(action: { viewModel.navigateBack() }) {
        Image(systemName: "chevron.left")
    }
    .buttonStyle(.borderless)
    .disabled(!viewModel.canGoBack)

    Button(action: { viewModel.navigateForward() }) {
        Image(systemName: "chevron.right")
    }
    .buttonStyle(.borderless)
    .disabled(!viewModel.canGoForward)

    // Current path breadcrumb
    Text(viewModel.fileListFolder?.name ?? "Archive")
        .font(.caption)
        .foregroundColor(.secondary)
        .lineLimit(1)

    Spacer()
}
.padding(.horizontal, 12)
.padding(.vertical, 4)
```

This bar sits at the top of the `VStack` in `FileListView`, just before the sort-header `HStack`.

---

### 3. Unit Tests

#### [NEW] [NavigationTests.swift](file:///Users/kevin/projects/macos_zipper/Tests/MacZipperTests/NavigationTests.swift)

New test file following the same conventions as [EntryFilterTests.swift](file:///Users/kevin/projects/macos_zipper/Tests/MacZipperTests/EntryFilterTests.swift) (`XCTest`, `@testable import MacZipper`, `@MainActor`).

**Helper:** Build a simple tree for tests:

```swift
/// Creates: root → [folderA → [folderA1, fileA], folderB → [fileB], fileRoot]
private func makeTestTree() -> ZipEntryNode { ... }
```

**Test cases:**

| # | Test Name | What It Verifies |
|---|-----------|-----------------|
| 1 | `testNavigateToFolder_updatesFileListFolder` | `navigateToFolder(folderA)` sets `fileListFolder` to folderA |
| 2 | `testNavigateToFolder_ignoresNonDirectory` | `navigateToFolder(file)` does nothing — `fileListFolder` unchanged |
| 3 | `testNavigateToFolder_expandsTargetFolder` | After navigate, `node.isExpanded == true` |
| 4 | `testNavigateToFolder_pushesHistory` | After navigate, `canGoBack == true` |
| 5 | `testNavigateToFolder_clearsForwardHistory` | Navigate → back → navigate elsewhere → `canGoForward == false` |
| 6 | `testNavigateBack_restoresPreviousFolder` | Navigate to A → back → `fileListFolder` is root |
| 7 | `testNavigateBack_pushesToForwardHistory` | After back, `canGoForward == true` |
| 8 | `testNavigateBack_whenNoHistory_doesNothing` | `navigateBack()` on empty history keeps `fileListFolder` unchanged |
| 9 | `testNavigateForward_restoresNextFolder` | Navigate → back → forward → `fileListFolder` is A again |
| 10 | `testNavigateForward_whenNoForward_doesNothing` | `navigateForward()` on empty forward stack keeps folder unchanged |
| 11 | `testMultiLevelNavigation_backTraversesFullHistory` | Navigate A → A1 → back → back → at root |
| 12 | `testCurrentEntries_usesFileListFolder` | After `navigateToFolder(folderA)`, `currentEntries` returns folderA's children |
| 13 | `testNavigationHistory_clearedOnNewArchive` | After loading a new archive, `canGoBack` and `canGoForward` are both false |

---

## Summary of Changes

| File | Change | Scope |
|------|--------|-------|
| [ZipBrowserViewModel.swift](file:///Users/kevin/projects/macos_zipper/Sources/MacZipper/ViewModels/ZipBrowserViewModel.swift) | Add `fileListFolder`, navigation history stacks, `navigateToFolder()`, `navigateBack()`, `navigateForward()`, `canGoBack`/`canGoForward` | ~30 new lines |
| [FileListView.swift](file:///Users/kevin/projects/macos_zipper/Sources/MacZipper/Views/Main/FileListView.swift) | Add back/forward nav bar, update double-click handler for folders | ~25 new lines |
| [NEW] [NavigationTests.swift](file:///Users/kevin/projects/macos_zipper/Tests/MacZipperTests/NavigationTests.swift) | 13 unit tests for navigation logic | ~150 new lines |

**Total: ~205 lines across 3 files.**

---

## Verification Plan

### Automated Tests

```bash
cd /Users/kevin/projects/macos_zipper
xcodegen generate --project .
xcodebuild test -scheme MacZipper -destination 'platform=macOS'
```

This runs both the existing `EntryFilterTests` (regression check) and the new `NavigationTests` (13 cases listed above).

### Build Verification

```bash
xcodebuild build -scheme MacZipper
```

### Manual Testing

1. **Open a ZIP file** with nested folders (2+ levels deep)
2. **Double-click a folder** in the file list → file list shows that folder's contents
3. **Verify sidebar is unaffected** → sidebar selection does NOT change when double-clicking in file list
4. **Click Back button (◀)** → file list returns to previous folder
5. **Click Forward button (▶)** → file list goes forward to the folder you just left
6. **Navigate multiple levels deep** via double-click → press Back multiple times → each step goes one level up in history
7. **Navigate back, then double-click a different folder** → forward history should be cleared (Forward button disabled)
8. **Click a folder in the sidebar** → sidebar selection changes, file list remains showing its own folder
9. **Double-click a file** → file preview still works as before
10. **Open a new archive** → history is cleared, Back/Forward buttons disabled
