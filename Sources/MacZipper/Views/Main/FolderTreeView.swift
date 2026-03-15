import SwiftUI

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

struct FolderNodeView: View {
    @ObservedObject var node: ZipEntryNode
    @ObservedObject var viewModel: ZipBrowserViewModel
    let level: Int
    let searchText: String
    
    var shouldShow: Bool {
        if searchText.isEmpty { return true }
        return node.name.localizedCaseInsensitiveContains(searchText) || hasMatchingDescendant
    }
    
    var hasMatchingDescendant: Bool {
        guard let children = node.children else { return false }
        return children.contains { child in
            child.name.localizedCaseInsensitiveContains(searchText) ||
            (child.children?.contains { $0.name.localizedCaseInsensitiveContains(searchText) } ?? false)
        }
    }
    
    private var isSelected: Bool {
        viewModel.currentFolder?.id == node.id
    }
    
    var body: some View {
        if shouldShow {
            HStack(spacing: 4) {
                Button(action: {
                    viewModel.toggleSelection(for: node.path)
                }) {
                    Image(systemName: viewModel.selectionState(for: node.path).imageName)
                        .foregroundColor(.accentColor)
                        .frame(width: 20, height: 20)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(4)
                
                if node.isDirectory {
                    Image(systemName: node.isExpanded ? "folder.fill" : "folder")
                        .foregroundColor(.accentColor)
                } else {
                    Image(systemName: iconForFile(node.name))
                        .foregroundColor(.secondary)
                }
                
                Text(node.name.isEmpty ? "Archive" : node.name)
                    .lineLimit(1)
                
                Spacer()
                
                if node.isDirectory && node.children != nil {
                    Button(action: {
                        node.isExpanded.toggle()
                    }) {
                        Image(systemName: node.isExpanded ? "chevron.down" : "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.leading, CGFloat(level * 16))
            .padding(.vertical, 2)
            .padding(.horizontal, 4)
            .contentShape(Rectangle())
            .background(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
            .cornerRadius(4)
            .onTapGesture {
                if node.isDirectory {
                    viewModel.selectFolder(node)
                }
            }
            .contextMenu {
                if node.isDirectory {
                    Button {
                        viewModel.selectFolder(node)
                        viewModel.navigateToFolder(node)
                    } label: {
                        Label("Go to", systemImage: "folder")
                    }
                }
            }
            
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
        }
    }
    
    private func iconForFile(_ filename: String) -> String {
        let ext = (filename as NSString).pathExtension.lowercased()
        switch ext {
        case "pdf":
            return "doc.text"
        case "jpg", "jpeg", "png", "gif", "bmp", "tiff":
            return "photo"
        case "txt", "md", "rtf":
            return "doc.plaintext"
        case "swift", "py", "js", "html", "css", "json":
            return "doc.text.fill"
        default:
            return "doc"
        }
    }
}
