import XCTest
@testable import MacZipper

@MainActor
class NavigationTests: XCTestCase {
    
    private func makeTestTree() -> ZipEntryNode {
        // Creates: root → [folderA → [folderA1, fileA], folderB → [fileB], fileRoot]
        let root = ZipEntryNode(path: "", name: "Archive", isDirectory: true, size: 0, compressedSize: 0, modificationDate: nil)
        
        let folderA = ZipEntryNode(path: "folderA", name: "folderA", isDirectory: true, size: 0, compressedSize: 0, modificationDate: nil)
        let folderA1 = ZipEntryNode(path: "folderA/folderA1", name: "folderA1", isDirectory: true, size: 0, compressedSize: 0, modificationDate: nil)
        let fileA = ZipEntryNode(path: "folderA/fileA.txt", name: "fileA.txt", isDirectory: false, size: 100, compressedSize: 50, modificationDate: nil)
        folderA.children = [folderA1, fileA]
        
        let folderB = ZipEntryNode(path: "folderB", name: "folderB", isDirectory: true, size: 0, compressedSize: 0, modificationDate: nil)
        let fileB = ZipEntryNode(path: "folderB/fileB.txt", name: "fileB.txt", isDirectory: false, size: 200, compressedSize: 100, modificationDate: nil)
        folderB.children = [fileB]
        
        let fileRoot = ZipEntryNode(path: "fileRoot.txt", name: "fileRoot.txt", isDirectory: false, size: 50, compressedSize: 25, modificationDate: nil)
        
        root.children = [folderA, folderB, fileRoot]
        
        return root
    }
    
    private func createViewModel(with rootNode: ZipEntryNode) -> ZipBrowserViewModel {
        let viewModel = ZipBrowserViewModel()
        // Use reflection to set private properties for testing
        let mirror = Mirror(reflecting: viewModel)
        
        // We need to set these via the @Published properties or through public methods
        // Since fileListFolder is @Published, we can access it if we make the test async
        // For now, we'll test through the public interface
        
        return viewModel
    }
    
    func testNavigateToFolder_updatesFileListFolder() async {
        let viewModel = ZipBrowserViewModel()
        let root = makeTestTree()
        
        // Initialize the view model state
        viewModel.rootNode = root
        viewModel.fileListFolder = root
        
        guard let folderA = root.children?.first(where: { $0.name == "folderA" }) else {
            XCTFail("folderA not found")
            return
        }
        
        viewModel.navigateToFolder(folderA)
        
        XCTAssertEqual(viewModel.fileListFolder?.name, "folderA")
    }
    
    func testNavigateToFolder_ignoresNonDirectory() async {
        let viewModel = ZipBrowserViewModel()
        let root = makeTestTree()
        
        viewModel.rootNode = root
        viewModel.fileListFolder = root
        
        guard let fileRoot = root.children?.first(where: { $0.name == "fileRoot.txt" }) else {
            XCTFail("fileRoot.txt not found")
            return
        }
        
        viewModel.navigateToFolder(fileRoot)
        
        // fileListFolder should remain unchanged
        XCTAssertEqual(viewModel.fileListFolder?.name, "Archive")
    }
    
    func testNavigateToFolder_expandsTargetFolder() async {
        let viewModel = ZipBrowserViewModel()
        let root = makeTestTree()
        
        viewModel.rootNode = root
        viewModel.fileListFolder = root
        
        guard let folderA = root.children?.first(where: { $0.name == "folderA" }) else {
            XCTFail("folderA not found")
            return
        }
        
        folderA.isExpanded = false
        viewModel.navigateToFolder(folderA)
        
        XCTAssertTrue(folderA.isExpanded)
    }
    
    func testNavigateToFolder_pushesHistory() async {
        let viewModel = ZipBrowserViewModel()
        let root = makeTestTree()
        
        viewModel.rootNode = root
        viewModel.fileListFolder = root
        
        guard let folderA = root.children?.first(where: { $0.name == "folderA" }) else {
            XCTFail("folderA not found")
            return
        }
        
        viewModel.navigateToFolder(folderA)
        
        XCTAssertTrue(viewModel.canGoBack)
    }
    
    func testNavigateToFolder_clearsForwardHistory() async {
        let viewModel = ZipBrowserViewModel()
        let root = makeTestTree()
        
        viewModel.rootNode = root
        viewModel.fileListFolder = root
        
        guard let folderA = root.children?.first(where: { $0.name == "folderA" }),
              let folderB = root.children?.first(where: { $0.name == "folderB" }) else {
            XCTFail("Required folders not found")
            return
        }
        
        // Navigate to A, then back
        viewModel.navigateToFolder(folderA)
        viewModel.navigateBack()
        XCTAssertTrue(viewModel.canGoForward)
        
        // Navigate to B - should clear forward history
        viewModel.navigateToFolder(folderB)
        XCTAssertFalse(viewModel.canGoForward)
    }
    
    func testNavigateBack_restoresPreviousFolder() async {
        let viewModel = ZipBrowserViewModel()
        let root = makeTestTree()
        
        viewModel.rootNode = root
        viewModel.fileListFolder = root
        
        guard let folderA = root.children?.first(where: { $0.name == "folderA" }) else {
            XCTFail("folderA not found")
            return
        }
        
        viewModel.navigateToFolder(folderA)
        viewModel.navigateBack()
        
        XCTAssertEqual(viewModel.fileListFolder?.name, "Archive")
    }
    
    func testNavigateBack_pushesToForwardHistory() async {
        let viewModel = ZipBrowserViewModel()
        let root = makeTestTree()
        
        viewModel.rootNode = root
        viewModel.fileListFolder = root
        
        guard let folderA = root.children?.first(where: { $0.name == "folderA" }) else {
            XCTFail("folderA not found")
            return
        }
        
        viewModel.navigateToFolder(folderA)
        viewModel.navigateBack()
        
        XCTAssertTrue(viewModel.canGoForward)
    }
    
    func testNavigateBack_whenNoHistory_doesNothing() async {
        let viewModel = ZipBrowserViewModel()
        let root = makeTestTree()
        
        viewModel.rootNode = root
        viewModel.fileListFolder = root
        
        // Try to go back with empty history
        viewModel.navigateBack()
        
        // Should still be at root
        XCTAssertEqual(viewModel.fileListFolder?.name, "Archive")
        XCTAssertFalse(viewModel.canGoBack)
    }
    
    func testNavigateForward_restoresNextFolder() async {
        let viewModel = ZipBrowserViewModel()
        let root = makeTestTree()
        
        viewModel.rootNode = root
        viewModel.fileListFolder = root
        
        guard let folderA = root.children?.first(where: { $0.name == "folderA" }) else {
            XCTFail("folderA not found")
            return
        }
        
        viewModel.navigateToFolder(folderA)
        viewModel.navigateBack()
        viewModel.navigateForward()
        
        XCTAssertEqual(viewModel.fileListFolder?.name, "folderA")
    }
    
    func testNavigateForward_whenNoForward_doesNothing() async {
        let viewModel = ZipBrowserViewModel()
        let root = makeTestTree()
        
        viewModel.rootNode = root
        viewModel.fileListFolder = root
        
        guard let folderA = root.children?.first(where: { $0.name == "folderA" }) else {
            XCTFail("folderA not found")
            return
        }
        
        viewModel.navigateToFolder(folderA)
        
        // Try to go forward without having gone back
        viewModel.navigateForward()
        
        // Should still be at folderA
        XCTAssertEqual(viewModel.fileListFolder?.name, "folderA")
        XCTAssertFalse(viewModel.canGoForward)
    }
    
    func testMultiLevelNavigation_backTraversesFullHistory() async {
        let viewModel = ZipBrowserViewModel()
        let root = makeTestTree()
        
        viewModel.rootNode = root
        viewModel.fileListFolder = root
        
        guard let folderA = root.children?.first(where: { $0.name == "folderA" }),
              let folderA1 = folderA.children?.first(where: { $0.name == "folderA1" }) else {
            XCTFail("Required folders not found")
            return
        }
        
        // Navigate A → A1
        viewModel.navigateToFolder(folderA)
        viewModel.navigateToFolder(folderA1)
        
        XCTAssertEqual(viewModel.fileListFolder?.name, "folderA1")
        
        // Back to A
        viewModel.navigateBack()
        XCTAssertEqual(viewModel.fileListFolder?.name, "folderA")
        
        // Back to root
        viewModel.navigateBack()
        XCTAssertEqual(viewModel.fileListFolder?.name, "Archive")
        
        XCTAssertFalse(viewModel.canGoBack)
    }
    
    func testCurrentEntries_usesFileListFolder() async {
        let viewModel = ZipBrowserViewModel()
        let root = makeTestTree()
        
        viewModel.rootNode = root
        viewModel.fileListFolder = root
        
        // Initially should show root's children
        var entries = viewModel.currentEntries
        XCTAssertEqual(entries.count, 3)
        
        guard let folderA = root.children?.first(where: { $0.name == "folderA" }) else {
            XCTFail("folderA not found")
            return
        }
        
        // Navigate to folderA
        viewModel.navigateToFolder(folderA)
        
        // Should now show folderA's children
        entries = viewModel.currentEntries
        XCTAssertEqual(entries.count, 2)
        XCTAssertTrue(entries.contains { $0.name == "folderA1" })
        XCTAssertTrue(entries.contains { $0.name == "fileA.txt" })
    }
    
    // MARK: - Breadcrumb Navigation Tests
    
    func testBreadcrumbSegments_atRoot() async {
        let viewModel = ZipBrowserViewModel()
        let root = makeTestTree()
        
        viewModel.rootNode = root
        viewModel.fileListFolder = nil // Root is represented as nil
        
        let segments = viewModel.breadcrumbSegments
        
        XCTAssertEqual(segments.count, 1)
        XCTAssertEqual(segments[0].name, "Archive")
        XCTAssertNil(segments[0].node)
    }
    
    func testBreadcrumbSegments_atDeepLevel() async {
        let viewModel = ZipBrowserViewModel()
        let root = makeTestTree()
        
        viewModel.rootNode = root
        
        guard let folderA = root.children?.first(where: { $0.name == "folderA" }),
              let folderA1 = folderA.children?.first(where: { $0.name == "folderA1" }) else {
            XCTFail("Required folders not found")
            return
        }
        
        viewModel.fileListFolder = folderA1
        
        let segments = viewModel.breadcrumbSegments
        
        XCTAssertEqual(segments.count, 3)
        XCTAssertEqual(segments[0].name, "Archive")
        XCTAssertNil(segments[0].node)
        XCTAssertEqual(segments[1].name, "folderA")
        XCTAssertEqual(segments[1].node?.name, "folderA")
        XCTAssertEqual(segments[2].name, "folderA1")
        XCTAssertEqual(segments[2].node?.name, "folderA1")
    }
    
    func testNavigateToBreadcrumb_toRoot() async {
        let viewModel = ZipBrowserViewModel()
        let root = makeTestTree()
        
        viewModel.rootNode = root
        viewModel.fileListFolder = root
        
        guard let folderA = root.children?.first(where: { $0.name == "folderA" }) else {
            XCTFail("folderA not found")
            return
        }
        
        // Navigate to folderA
        viewModel.navigateToFolder(folderA)
        XCTAssertEqual(viewModel.fileListFolder?.name, "folderA")
        
        // Navigate back to root via breadcrumb (nil node)
        viewModel.navigateToBreadcrumb(nil)
        XCTAssertNil(viewModel.fileListFolder)
        XCTAssertTrue(viewModel.canGoBack)
    }
    
    func testNavigateToBreadcrumb_toMiddleFolder() async {
        let viewModel = ZipBrowserViewModel()
        let root = makeTestTree()
        
        viewModel.rootNode = root
        viewModel.fileListFolder = root
        
        guard let folderA = root.children?.first(where: { $0.name == "folderA" }),
              let folderA1 = folderA.children?.first(where: { $0.name == "folderA1" }) else {
            XCTFail("Required folders not found")
            return
        }
        
        // Navigate deep into the tree
        viewModel.navigateToFolder(folderA)
        viewModel.navigateToFolder(folderA1)
        XCTAssertEqual(viewModel.fileListFolder?.name, "folderA1")
        
        // Navigate back to middle folder via breadcrumb
        viewModel.navigateToBreadcrumb(folderA)
        XCTAssertEqual(viewModel.fileListFolder?.name, "folderA")
        XCTAssertTrue(viewModel.canGoBack)
        XCTAssertFalse(viewModel.canGoForward)
    }
    
    func testNavigateToBreadcrumb_sameLocation_doesNothing() async {
        let viewModel = ZipBrowserViewModel()
        let root = makeTestTree()
        
        viewModel.rootNode = root
        viewModel.fileListFolder = root
        
        guard let folderA = root.children?.first(where: { $0.name == "folderA" }) else {
            XCTFail("folderA not found")
            return
        }
        
        viewModel.navigateToFolder(folderA)
        XCTAssertFalse(viewModel.canGoForward)
        
        // Try to navigate to same location
        viewModel.navigateToBreadcrumb(folderA)
        
        // Should not add to history
        XCTAssertEqual(viewModel.fileListFolder?.name, "folderA")
        // canGoBack should still be true from the original navigation
        XCTAssertTrue(viewModel.canGoBack)
    }
    
    func testNavigateToBreadcrumb_expandsTargetFolder() async {
        let viewModel = ZipBrowserViewModel()
        let root = makeTestTree()
        
        viewModel.rootNode = root
        viewModel.fileListFolder = root
        
        guard let folderA = root.children?.first(where: { $0.name == "folderA" }) else {
            XCTFail("folderA not found")
            return
        }
        
        folderA.isExpanded = false
        
        viewModel.navigateToBreadcrumb(folderA)
        
        XCTAssertTrue(folderA.isExpanded)
    }
    
    func testBreadcrumbPath_atDeepLevel() async {
        let viewModel = ZipBrowserViewModel()
        let root = makeTestTree()
        
        viewModel.rootNode = root
        
        guard let folderA = root.children?.first(where: { $0.name == "folderA" }),
              let folderA1 = folderA.children?.first(where: { $0.name == "folderA1" }) else {
            XCTFail("Required folders not found")
            return
        }
        
        viewModel.fileListFolder = folderA1
        
        // Verify breadcrumbPath is correct
        XCTAssertEqual(viewModel.breadcrumbPath, "Archive > folderA > folderA1")
    }
}
