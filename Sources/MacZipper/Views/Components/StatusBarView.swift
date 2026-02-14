import SwiftUI

struct StatusBarView: View {
    @ObservedObject var viewModel: ZipBrowserViewModel
    
    var body: some View {
        VStack(spacing: 0) {
            if viewModel.isExtracting {
                ProgressView(value: viewModel.extractionProgress)
                    .progressViewStyle(LinearProgressViewStyle())
                    .padding(.horizontal, 12)
                    .padding(.top, 6)
            }
            
            HStack(spacing: 16) {
                HStack(spacing: 4) {
                    Image(systemName: "doc.on.doc")
                        .font(.caption)
                    Text("\(viewModel.selectedPaths.count) selected")
                        .font(.caption)
                }
                
                Divider()
                    .frame(height: 12)
                
                HStack(spacing: 4) {
                    Image(systemName: "externaldrive")
                        .font(.caption)
                    Text("Total: \(formatBytes(viewModel.selectedSize))")
                        .font(.caption)
                }
                
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(NSColor.controlBackgroundColor))
        }
    }
    
    private func formatBytes(_ bytes: UInt64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useAll]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }
}
