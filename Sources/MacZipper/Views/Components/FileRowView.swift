import SwiftUI

struct FileRowView: View {
    let entry: ZipEntryNode
    let selectionState: SelectionState
    let onToggle: () -> Void
    
    var body: some View {
        HStack(spacing: 8) {
            Button(action: onToggle) {
                Image(systemName: selectionState.imageName)
                    .foregroundColor(.accentColor)
            }
            .buttonStyle(.plain)
            
            Image(systemName: iconForFile(entry.name))
                .foregroundColor(.secondary)
                .frame(width: 20)
            
            Text(entry.name)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Text(formatBytes(entry.size))
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 100, alignment: .trailing)
            
            if let date = entry.modificationDate {
                Text(formatDate(date))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(width: 150, alignment: .trailing)
            } else {
                Spacer()
                    .frame(width: 150)
            }
        }
        .padding(.vertical, 2)
    }
    
    private func iconForFile(_ filename: String) -> String {
        if entry.isDirectory {
            return "folder"
        }
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
    
    private func formatBytes(_ bytes: UInt64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useAll]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
