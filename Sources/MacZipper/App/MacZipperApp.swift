import SwiftUI
import UniformTypeIdentifiers

@main
struct MacZipperApp: App {
    var body: some Scene {
        DocumentGroup(newDocument: ZipDocument()) { file in
            ContentView(document: file.$document, fileURL: file.fileURL)
        }
        .commands {
            CommandGroup(replacing: .newItem) {
                // Disable new document since we're viewer-only
                EmptyView()
            }
            
            CommandMenu("Archive") {
                Button("Extract All") {
                    // This will be handled by the active window's view model
                    NotificationCenter.default.post(name: .extractAll, object: nil)
                }
                .keyboardShortcut("e", modifiers: .command)
                
                Button("Extract Selected") {
                    NotificationCenter.default.post(name: .extractSelected, object: nil)
                }
                .keyboardShortcut("e", modifiers: [.command, .shift])
                
                Divider()
                
                Button("Select All") {
                    NotificationCenter.default.post(name: .selectAllFiles, object: nil)
                }
                .keyboardShortcut("a", modifiers: .command)
                
                Button("Deselect All") {
                    NotificationCenter.default.post(name: .deselectAllFiles, object: nil)
                }
                .keyboardShortcut("d", modifiers: .command)
                
                Divider()
                
                Button("Set Destination...") {
                    NotificationCenter.default.post(name: .setDestination, object: nil)
                }
                .keyboardShortcut("t", modifiers: .command)
            }
        }
    }
}

extension Notification.Name {
    static let extractAll = Notification.Name("extractAll")
    static let extractSelected = Notification.Name("extractSelected")
    static let selectAllFiles = Notification.Name("selectAllFiles")
    static let deselectAllFiles = Notification.Name("deselectAllFiles")
    static let setDestination = Notification.Name("setDestination")
}
