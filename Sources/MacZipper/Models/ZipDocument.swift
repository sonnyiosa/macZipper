import SwiftUI
import UniformTypeIdentifiers

struct ZipDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.zip] }
    
    var url: URL?
    var isPlaceholder: Bool = false
    
    init() {
        self.url = nil
        self.isPlaceholder = true
    }
    
    init(configuration: ReadConfiguration) throws {
        // When a file is opened via document-based architecture,
        // we need to get the URL from the file wrapper
        let wrapper = configuration.file
        
        // Store a reference - the actual URL will be resolved later via the DocumentGroup
        self.url = nil
        self.isPlaceholder = false
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        // Zip files are read-only, return empty wrapper
        return FileWrapper(regularFileWithContents: Data())
    }
}
