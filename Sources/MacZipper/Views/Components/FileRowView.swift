import SwiftUI

struct FileRowView: View {
    let entry: ZipEntryNode
    let selectionState: SelectionState
    let isActivated: Bool
    let onToggle: () -> Void
    let onActivate: () -> Void
    @State private var isHovering = false
    
    var body: some View {
        HStack(spacing: 8) {
            Button(action: onToggle) {
                Image(systemName: selectionState.imageName)
                    .foregroundColor(.accentColor)
                    .frame(width: 20, height: 20)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(4)
            
            Image(systemName: iconForFile(entry))
                .foregroundColor(iconColor(for: entry))
                .frame(width: 20)
            
            Text(entry.name)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // Compressed size
            if !entry.isDirectory && entry.compressedSize > 0 {
                VStack(alignment: .trailing, spacing: 0) {
                    Text(formatBytes(entry.compressedSize))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    if let ratio = entry.compressionRatio, ratio < 1.0 {
                        Text("\(Int((1.0 - ratio) * 100))% smaller")
                            .font(.caption2)
                            .foregroundColor(.green)
                    }
                }
                .frame(width: 90, alignment: .trailing)
            } else {
                Spacer()
                    .frame(width: 90)
            }
            
            // Uncompressed size
            Text(formatBytes(entry.size))
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 80, alignment: .trailing)
            
            if let date = entry.modificationDate {
                Text(formatDate(date))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(width: 120, alignment: .trailing)
            } else {
                Spacer()
                    .frame(width: 120)
            }
        }
        .padding(.vertical, 2)
        .background(backgroundColor)
        .onHover { hovering in
            isHovering = hovering
        }
    }

    private var backgroundColor: Color {
        if isActivated {
            return Color.accentColor.opacity(0.2)
        }
        return isHovering ? Color.accentColor.opacity(0.1) : Color.clear
    }
    
    private func iconForFile(_ entry: ZipEntryNode) -> String {
        if entry.isDirectory {
            return "folder.fill"
        }
        
        let ext = (entry.name as NSString).pathExtension.lowercased()
        
        // Images
        let imageExtensions = ["jpg", "jpeg", "png", "gif", "bmp", "tiff", "webp", "heic", "raw", "svg", "ico"]
        if imageExtensions.contains(ext) {
            return "photo.fill"
        }
        
        // PDFs
        if ext == "pdf" {
            return "doc.text.fill"
        }
        
        // Text/Document files
        let docExtensions = ["txt", "md", "rtf", "doc", "docx", "pages", "odt"]
        if docExtensions.contains(ext) {
            return "doc.fill"
        }
        
        // Code files
        let codeExtensions = ["swift", "py", "js", "html", "css", "json", "xml", "yaml", "yml", "cpp", "c", "h", "java", "kt", "rs", "go", "rb", "php", "sh", "bash", "zsh"]
        if codeExtensions.contains(ext) {
            return "chevron.left.forwardslash.chevron.right"
        }
        
        // Audio
        let audioExtensions = ["mp3", "wav", "aac", "flac", "m4a", "ogg", "wma"]
        if audioExtensions.contains(ext) {
            return "music.note"
        }
        
        // Video
        let videoExtensions = ["mp4", "mov", "avi", "mkv", "wmv", "flv", "m4v", "webm"]
        if videoExtensions.contains(ext) {
            return "film.fill"
        }
        
        // Archives
        let archiveExtensions = ["zip", "tar", "gz", "bz2", "7z", "rar", "xz"]
        if archiveExtensions.contains(ext) {
            return "doc.zipper"
        }
        
        // Database
        let dbExtensions = ["db", "sqlite", "sql", "mdb", "accdb"]
        if dbExtensions.contains(ext) {
            return "cylinder.fill"
        }
        
        // Executables
        if ext == "app" || ext == "exe" || ext == "dmg" || ext == "pkg" {
            return "app.fill"
        }
        
        // Spreadsheets
        let spreadsheetExtensions = ["xls", "xlsx", "numbers", "ods", "csv"]
        if spreadsheetExtensions.contains(ext) {
            return "tablecells.fill"
        }
        
        // Presentations
        let presentationExtensions = ["ppt", "pptx", "key", "odp"]
        if presentationExtensions.contains(ext) {
            return "play.rectangle.fill"
        }
        
        // Default
        return "doc.fill"
    }
    
    private func iconColor(for entry: ZipEntryNode) -> Color {
        if entry.isDirectory {
            return .blue
        }
        
        let ext = (entry.name as NSString).pathExtension.lowercased()
        
        // Images - purple
        let imageExtensions = ["jpg", "jpeg", "png", "gif", "bmp", "tiff", "webp", "heic", "raw", "svg", "ico"]
        if imageExtensions.contains(ext) {
            return .purple
        }
        
        // PDFs - red
        if ext == "pdf" {
            return .red
        }
        
        // Code - orange
        let codeExtensions = ["swift", "py", "js", "html", "css", "json", "xml", "yaml", "yml", "cpp", "c", "h", "java", "kt", "rs", "go", "rb", "php", "sh", "bash", "zsh"]
        if codeExtensions.contains(ext) {
            return .orange
        }
        
        // Audio - pink
        let audioExtensions = ["mp3", "wav", "aac", "flac", "m4a", "ogg", "wma"]
        if audioExtensions.contains(ext) {
            return .pink
        }
        
        // Video - indigo
        let videoExtensions = ["mp4", "mov", "avi", "mkv", "wmv", "flv", "m4v", "webm"]
        if videoExtensions.contains(ext) {
            return .indigo
        }
        
        // Archives - yellow
        let archiveExtensions = ["zip", "tar", "gz", "bz2", "7z", "rar", "xz"]
        if archiveExtensions.contains(ext) {
            return .yellow
        }
        
        // Executables - green
        if ext == "app" || ext == "exe" || ext == "dmg" || ext == "pkg" {
            return .green
        }
        
        return .secondary
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
