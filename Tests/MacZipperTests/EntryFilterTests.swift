import XCTest
@testable import MacZipper

class EntryFilterTests: XCTestCase {
    
    func testMacOSMetadataFilterExcludesMACOSXFolder() {
        let filter = MacOSMetadataFilter()
        filter.isEnabled = true
        
        XCTAssertFalse(filter.shouldInclude(path: "__MACOSX"))
        XCTAssertFalse(filter.shouldInclude(path: "__MACOSX/somefile"))
        XCTAssertFalse(filter.shouldInclude(path: "folder/__MACOSX/file"))
    }
    
    func testMacOSMetadataFilterExcludesDSStore() {
        let filter = MacOSMetadataFilter()
        filter.isEnabled = true
        
        XCTAssertFalse(filter.shouldInclude(path: ".DS_Store"))
        XCTAssertFalse(filter.shouldInclude(path: "folder/.DS_Store"))
        XCTAssertFalse(filter.shouldInclude(path: "path/to/.DS_Store"))
    }
    
    func testMacOSMetadataFilterExcludesResourceForks() {
        let filter = MacOSMetadataFilter()
        filter.isEnabled = true
        
        XCTAssertFalse(filter.shouldInclude(path: "._filename"))
        XCTAssertFalse(filter.shouldInclude(path: "folder/._otherfile"))
        XCTAssertFalse(filter.shouldInclude(path: "path/to/._document.txt"))
    }
    
    func testMacOSMetadataFilterIncludesNormalFiles() {
        let filter = MacOSMetadataFilter()
        filter.isEnabled = true
        
        XCTAssertTrue(filter.shouldInclude(path: "document.txt"))
        XCTAssertTrue(filter.shouldInclude(path: "folder/file.pdf"))
        XCTAssertTrue(filter.shouldInclude(path: "path/to/image.jpg"))
        XCTAssertTrue(filter.shouldInclude(path: "normal_file"))
    }
    
    func testMacOSMetadataFilterDisabled() {
        let filter = MacOSMetadataFilter()
        filter.isEnabled = false
        
        // When disabled, should not filter anything
        XCTAssertTrue(filter.shouldInclude(path: "__MACOSX"))
        XCTAssertTrue(filter.shouldInclude(path: ".DS_Store"))
        XCTAssertTrue(filter.shouldInclude(path: "._filename"))
    }
    
    func testHiddenFilesFilter() {
        let filter = HiddenFilesFilter()
        filter.isEnabled = true
        
        XCTAssertFalse(filter.shouldInclude(path: ".hidden"))
        XCTAssertFalse(filter.shouldInclude(path: ".gitignore"))
        XCTAssertFalse(filter.shouldInclude(path: "folder/.hidden"))
        
        XCTAssertTrue(filter.shouldInclude(path: "visible"))
        XCTAssertTrue(filter.shouldInclude(path: "file.txt"))
        XCTAssertTrue(filter.shouldInclude(path: "folder/file"))
    }
    
    func testVersionControlFilter() {
        let filter = VersionControlFilter()
        filter.isEnabled = true
        
        XCTAssertFalse(filter.shouldInclude(path: ".git"))
        XCTAssertFalse(filter.shouldInclude(path: ".git/config"))
        XCTAssertFalse(filter.shouldInclude(path: "project/.git/HEAD"))
        XCTAssertFalse(filter.shouldInclude(path: ".svn"))
        XCTAssertFalse(filter.shouldInclude(path: ".svn/entries"))
        XCTAssertFalse(filter.shouldInclude(path: ".hg"))
        
        XCTAssertTrue(filter.shouldInclude(path: "git-tutorial.txt"))
        XCTAssertTrue(filter.shouldInclude(path: "project/file.txt"))
    }
    
    func testGlobMatching() {
        // Test basic glob patterns
        XCTAssertTrue("test.log".matchesGlob("*.log"))
        XCTAssertTrue("file.txt".matchesGlob("*.txt"))
        XCTAssertFalse("file.pdf".matchesGlob("*.txt"))
        
        XCTAssertTrue("doc".matchesGlob("doc"))
        XCTAssertTrue("a".matchesGlob("?"))
        XCTAssertFalse("ab".matchesGlob("?"))
    }
}

class FilterManagerTests: XCTestCase {
    
    @MainActor
    func testFilterManagerFiltersEntries() {
        let manager = FilterManager()
        manager.macOSFilter.isEnabled = true
        manager.hiddenFilesFilter.isEnabled = false
        manager.versionControlFilter.isEnabled = false
        
        let entries = [
            ZipEntry(path: "file.txt", name: "file.txt", size: 100, compressedSize: 50, isDirectory: false, modificationDate: nil, crc32: 0),
            ZipEntry(path: "__MACOSX", name: "__MACOSX", size: 0, compressedSize: 0, isDirectory: true, modificationDate: nil, crc32: 0),
            ZipEntry(path: "__MACOSX/file", name: "file", size: 50, compressedSize: 25, isDirectory: false, modificationDate: nil, crc32: 0),
            ZipEntry(path: "folder/.DS_Store", name: ".DS_Store", size: 10, compressedSize: 5, isDirectory: false, modificationDate: nil, crc32: 0),
            ZipEntry(path: "document.pdf", name: "document.pdf", size: 200, compressedSize: 100, isDirectory: false, modificationDate: nil, crc32: 0)
        ]
        
        let filtered = manager.filter(entries: entries)
        
        XCTAssertEqual(filtered.count, 2)
        XCTAssertTrue(filtered.contains { $0.path == "file.txt" })
        XCTAssertTrue(filtered.contains { $0.path == "document.pdf" })
        XCTAssertFalse(filtered.contains { $0.path == "__MACOSX" })
        XCTAssertFalse(filtered.contains { $0.path == "__MACOSX/file" })
        XCTAssertFalse(filtered.contains { $0.path == "folder/.DS_Store" })
    }
    
    @MainActor
    func testFilterManagerCalculatesHiddenCount() {
        let manager = FilterManager()
        manager.macOSFilter.isEnabled = true
        
        let entries = [
            ZipEntry(path: "file.txt", name: "file.txt", size: 100, compressedSize: 50, isDirectory: false, modificationDate: nil, crc32: 0),
            ZipEntry(path: "__MACOSX", name: "__MACOSX", size: 0, compressedSize: 0, isDirectory: true, modificationDate: nil, crc32: 0),
            ZipEntry(path: "__MACOSX/file", name: "file", size: 50, compressedSize: 25, isDirectory: false, modificationDate: nil, crc32: 0),
            ZipEntry(path: ".DS_Store", name: ".DS_Store", size: 10, compressedSize: 5, isDirectory: false, modificationDate: nil, crc32: 0)
        ]
        
        let _ = manager.filter(entries: entries)
        
        XCTAssertEqual(manager.hiddenCount, 3) // __MACOSX folder, __MACOSX/file, and .DS_Store
    }
    
    @MainActor
    func testFilterManagerActiveState() {
        let manager = FilterManager()
        
        // Initially macOS filter is enabled
        XCTAssertTrue(manager.areFiltersActive)
        
        // Disable all
        manager.disableAllFilters()
        XCTAssertFalse(manager.areFiltersActive)
        
        // Enable one - allow Combine to process the change
        manager.macOSFilter.isEnabled = true
        // Run the runloop to allow Combine to process the change
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.01))
        XCTAssertTrue(manager.areFiltersActive)
    }
    
    @MainActor
    func testFilterEntryMethod() {
        let manager = FilterManager()
        manager.macOSFilter.isEnabled = true
        
        let entry1 = ZipEntry(path: "file.txt", name: "file.txt", size: 100, compressedSize: 50, isDirectory: false, modificationDate: nil, crc32: 0)
        let entry2 = ZipEntry(path: "__MACOSX/file", name: "file", size: 50, compressedSize: 25, isDirectory: false, modificationDate: nil, crc32: 0)
        
        XCTAssertTrue(manager.shouldInclude(entry: entry1))
        XCTAssertFalse(manager.shouldInclude(entry: entry2))
    }
}
