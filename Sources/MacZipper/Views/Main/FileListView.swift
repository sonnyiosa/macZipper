import SwiftUI

struct FileListView: View {
    @ObservedObject var viewModel: ZipBrowserViewModel
    @Binding var searchText: String
    
    var filteredEntries: [ZipEntryNode] {
        let entries = viewModel.currentEntries
        if searchText.isEmpty {
            return entries
        }
        return entries.filter { entry in
            entry.name.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Name")
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("Size")
                    .frame(width: 100, alignment: .trailing)
                Text("Modified")
                    .frame(width: 150, alignment: .trailing)
            }
            .font(.caption)
            .foregroundColor(.secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            
            Divider()
            
            // File list
            List {
                ForEach(filteredEntries) { entry in
                    FileRowView(
                        entry: entry,
                        selectionState: viewModel.selectionState(for: entry.path),
                        onToggle: {
                            viewModel.toggleSelection(for: entry.path)
                        }
                    )
                    .onTapGesture(count: 2) {
                        // Double-click to preview
                        if !entry.isDirectory {
                            Task {
                                await viewModel.previewEntry(at: entry.path)
                            }
                        }
                    }
                }
            }
            .listStyle(.plain)
        }
    }
}
