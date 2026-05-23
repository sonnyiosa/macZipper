# Plan: Quick Look with Activated Item

## Context

The current Quick Look implementation uses the **selection state** (checkbox selection) to determine which file to preview when Space bar is pressed. This creates poor UX because:
- Selection is primarily for extraction operations
- Users must select a file before they can quick look it
- Selection and Quick Look concerns are mixed together

The goal is to introduce an **activated item** concept - a temporary highlight separate from selection that determines which file receives Quick Look when Space is pressed.

## Proposed Solution

Implement a single-item "activation" state that:
- Is visually distinct from selection (checkbox)
- Can be set by single-clicking a row (optional UX enhancement)
- Is used by Space bar for Quick Look instead of selection
- Only one item can be activated at a time

## Implementation Details

### 1. ViewModel Changes (`ZipBrowserViewModel.swift`)

Add activated item tracking:
```swift
@Published var activatedPath: String? = nil

func activateEntry(at path: String) {
    activatedPath = path
}

func getActivatedEntry() -> ZipEntry? {
    guard let path = activatedPath else { return nil }
    return allEntries.first { $0.path == path && !$0.isDirectory }
}
```

Update `quickLookEntry()` to not require a path parameter - use activated item instead:
```swift
func quickLookActivatedEntry() async {
    guard let entry = getActivatedEntry() else { return }
    // ... existing quick look logic
}
```

### 2. FileRowView Changes (`FileRowView.swift`)

Add activation state support:
```swift
struct FileRowView: View {
    let entry: ZipEntryNode
    let selectionState: SelectionState
    let isActivated: Bool  // NEW
    let onToggle: () -> Void
    let onActivate: () -> Void  // NEW
    @State private var isHovering = false

    var body: some View {
        HStack {
            // ... existing content
        }
        .background(backgroundColor)
        .onTapGesture {
            onActivate()  // Single click activates
        }
        // ... rest of view
    }

    private var backgroundColor: Color {
        if isActivated {
            return Color.accentColor.opacity(0.2)  // Distinct activation highlight
        }
        return isHovering ? Color.accentColor.opacity(0.1) : Color.clear
    }
}
```

### 3. FileListView Changes (`FileListView.swift`)

Pass activation state and handler to FileRowView:
```swift
ForEach(filteredEntries) { entry in
    FileRowView(
        entry: entry,
        selectionState: viewModel.selectionState(for: entry.path),
        isActivated: viewModel.activatedPath == entry.path,  // NEW
        onToggle: { viewModel.toggleSelection(for: entry.path) },
        onActivate: { viewModel.activateEntry(at: entry.path) }  // NEW
    )
    // ... existing gestures
}
```

### 4. ContentView Changes (`ContentView.swift`)

Update Space bar handler to use activated item:
```swift
// Handle Space bar for Quick Look (uses activated item)
if event.keyCode == 49 { // Space key
    Task {
        await viewModel.quickLookActivatedEntry()
    }
    return nil
}
```

Add Escape key handler to clear activation:
```swift
if event.keyCode == 53 { // Escape key
    viewModel.activatedPath = nil
    return nil
}
```

### 5. Activation Behavior Details

**Visual Design:**
- Activated row: `Color.accentColor.opacity(0.2)` background
- Hover: `Color.accentColor.opacity(0.1)` background (unchanged)
- Selected (checkbox): checkmark in checkbox (unchanged)
- These states are independent - an item can be both activated AND selected

**Interaction Flow:**
1. User single-clicks a file row → item becomes activated
2. User presses Space → Quick Look opens for activated item
3. User presses Escape or clicks another row → activation clears/moves
4. User can still check/uncheck items independently for extraction

**Edge Cases:**
- No item activated + Space pressed: nothing happens
- Activated item is a directory: Quick Look does nothing (files only)
- Archive not loaded: activation does nothing

## Files to Modify

1. `Sources/MacZipper/Models/ZipEntryNode.swift` - No changes needed (SelectionState sufficient)
2. `Sources/MacZipper/ViewModels/ZipBrowserViewModel.swift` - Add activation tracking
3. `Sources/MacZipper/Views/Components/FileRowView.swift` - Add activation UI
4. `Sources/MacZipper/Views/Main/FileListView.swift` - Wire up activation
5. `Sources/MacZipper/Views/Main/ContentView.swift` - Update keyboard handlers

## Verification

1. Open a ZIP archive
2. Single-click a file (not checkbox) - row should highlight with accent color
3. Press Space - Quick Look should open for that file
4. Press Escape - highlight should disappear
5. Check the checkbox - file should still be selected for extraction
6. Verify selection and activation are independent states

## Rollback Plan

If needed, simply remove the `isActivated` parameter from FileRowView and revert keyboard handler to use `getFirstSelectedEntry()` instead of activated entry.
