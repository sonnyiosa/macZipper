import XCTest
import ZipArchive
@testable import MacZipper

final class PasswordProtectedArchiveTests: XCTestCase {
    func testPasswordProtectedArchiveCanBeOpenedAndExtractedSelectively() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }

        try Data("first file".utf8).write(to: folder.appendingPathComponent("first.txt"))
        try Data("second file".utf8).write(to: folder.appendingPathComponent("second.txt"))
        let archiveURL = folder.appendingPathComponent("protected.zip")
        let zip = Process()
        zip.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        zip.currentDirectoryURL = folder
        zip.arguments = ["-q", "-P", "correct-password", archiveURL.path, "first.txt", "second.txt"]
        try zip.run()
        zip.waitUntilExit()
        XCTAssertEqual(zip.terminationStatus, 0)

        let viewModel = await ZipBrowserViewModel()
        await viewModel.loadArchive(from: archiveURL)
        var requiresPassword = await viewModel.showPasswordPrompt
        XCTAssertTrue(requiresPassword)
        await viewModel.loadArchive(from: archiveURL, password: "wrong-password")
        requiresPassword = await viewModel.showPasswordPrompt
        let passwordError = await viewModel.passwordErrorMessage
        XCTAssertTrue(requiresPassword)
        XCTAssertNotNil(passwordError)
        await viewModel.loadArchive(from: archiveURL, password: "correct-password")
        let isLoaded = await viewModel.isLoaded
        requiresPassword = await viewModel.showPasswordPrompt
        XCTAssertTrue(isLoaded)
        XCTAssertFalse(requiresPassword)

        let service = ZipService()
        do {
            try await service.openArchive(at: archiveURL)
            XCTFail("Expected a password prompt")
        } catch {
            XCTAssertEqual(error as? ZipError, .passwordRequired)
        }
        do {
            try await service.openArchive(at: archiveURL, password: "wrong-password")
            XCTFail("Expected the wrong password to fail")
        } catch {
            XCTAssertEqual(error as? ZipError, .incorrectPassword)
        }

        try await service.openArchive(at: archiveURL, password: "correct-password")
        let entries = try await service.loadEntries()
        XCTAssertEqual(Set(entries.map(\.path)), ["first.txt", "second.txt"])

        let destination = folder.appendingPathComponent("output")
        let first = try XCTUnwrap(entries.first { $0.path == "first.txt" })
        try await service.extract(entries: [first], to: destination)
        XCTAssertEqual(try String(contentsOf: destination.appendingPathComponent("first.txt")), "first file")
        XCTAssertFalse(FileManager.default.fileExists(atPath: destination.appendingPathComponent("second.txt").path))
    }

    func testAESProtectedArchiveCanBeRead() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }

        let source = folder.appendingPathComponent("aes.txt")
        try Data("encrypted content".utf8).write(to: source)
        let archiveURL = folder.appendingPathComponent("aes.zip")
        XCTAssertTrue(SSZipArchive.createZipFile(atPath: archiveURL.path,
                                                 withFilesAtPaths: [source.path], withPassword: "aes-password"))

        let service = ZipService()
        try await service.openArchive(at: archiveURL, password: "aes-password")
        let entries = try await service.loadEntries()
        let entry = try XCTUnwrap(entries.first { $0.name == "aes.txt" })
        let destination = folder.appendingPathComponent("extracted.txt")
        try await service.extract(entry: entry, to: destination, progress: Progress())
        XCTAssertEqual(try String(contentsOf: destination), "encrypted content")
    }
}
