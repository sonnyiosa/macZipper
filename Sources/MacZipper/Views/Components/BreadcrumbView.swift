import SwiftUI

struct BreadcrumbView: View {
    let segments: [(name: String, node: ZipEntryNode?)]
    let onNavigate: (ZipEntryNode?) -> Void
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(Array(segments.enumerated()), id: \.offset) { index, segment in
                if index > 0 {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary.opacity(0.6))
                }
                
                BreadcrumbSegmentView(
                    name: segment.name,
                    isLast: index == segments.count - 1,
                    onTap: { onNavigate(segment.node) }
                )
            }
        }
    }
}

struct BreadcrumbSegmentView: View {
    let name: String
    let isLast: Bool
    let onTap: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Text(name)
            .font(.caption)
            .foregroundColor(isLast ? .primary : .secondary)
            .background(isHovered && !isLast ? Color.secondary.opacity(0.1) : Color.clear)
            .cornerRadius(2)
            .contentShape(Rectangle())
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.1)) {
                    isHovered = hovering
                }
            }
            .onTapGesture {
                if !isLast {
                    onTap()
                }
            }
            .help(isLast ? "" : "Navigate to \(name)")
            .accessibilityHint(isLast ? "Current location" : "Double-click to navigate to \(name)")
    }
}

#if DEBUG
struct BreadcrumbView_Previews: PreviewProvider {
    static var previews: some View {
        let mockSegments: [(String, ZipEntryNode?)] = [
            ("Archive", nil),
            ("Documents", nil),
            ("Projects", nil)
        ]
        
        VStack(spacing: 20) {
            BreadcrumbView(segments: mockSegments) { _ in }
                .padding()
            
            BreadcrumbView(segments: [("Archive", nil)]) { _ in }
                .padding()
        }
    }
}
#endif
