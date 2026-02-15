import SwiftUI
import AppKit

struct WindowAccessor: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let window = view.window {
                window.setFrameAutosaveName("MacZipperMainWindow")
            }
        }
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {}
}
