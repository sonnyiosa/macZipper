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
            // Navigation bar
            HStack(spacing: 4) {
                Button(action: { viewModel.navigateBack() }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
                .disabled(!viewModel.canGoBack)

                Button(action: { viewModel.navigateForward() }) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
                .disabled(!viewModel.canGoForward)

                // Current path breadcrumb
                Text(viewModel.breadcrumbPath)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 4)

            Divider()
            
            // Header with sort controls
            HStack {
                sortButton(for: .name, title: "Name", width: nil)
                
                Spacer()
                
                Text("Compressed")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(width: 90, alignment: .trailing)
                
                sortButton(for: .size, title: "Size", width: 80)
                
                sortButton(for: .date, title: "Modified", width: 120)
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
                        if entry.isDirectory {
                            // Double-click folder → navigate into it
                            viewModel.navigateToFolder(entry)
                        } else {
                            // Double-click file → preview
                            Task {
                                await viewModel.previewEntry(at: entry.path)
                            }
                        }
                    }
                }
            }
            .listStyle(.plain)
            .padding(.bottom, 32)
        }
    }
    
    private func sortButton(for option: SortOption, title: String, width: CGFloat?) -> some View {
        Button(action: {
            if viewModel.sortOption == option {
                viewModel.sortOrder.toggle()
            } else {
                viewModel.sortOption = option
                viewModel.sortOrder = .ascending
            }
        }) {
            HStack(spacing: 4) {
                Text(title)
                if viewModel.sortOption == option {
                    Image(systemName: viewModel.sortOrder.iconName)
                        .font(.caption2)
                }
            }
        }
        .buttonStyle(.plain)
        .foregroundColor(viewModel.sortOption == option ? .accentColor : .secondary)
        .frame(width: width, alignment: width != nil ? .trailing : .leading)
    }
}
