import Foundation

protocol EntryFilter: ObservableObject {
    var id: String { get }
    var displayName: String { get }
    var description: String { get }
    var isEnabled: Bool { get set }
    
    func shouldInclude(path: String) -> Bool
}

class MacOSMetadataFilter: EntryFilter {
    let id = "com.maczipper.filters.macos-metadata"
    let displayName = "Hide macOS metadata"
    let description = "Removes __MACOSX folder, .DS_Store files, and resource forks"
    @Published var isEnabled: Bool = true
    
    private let excludedPatterns: [String] = [
        "__MACOSX",
        ".DS_Store",
    ]
    
    func shouldInclude(path: String) -> Bool {
        // If filter is disabled, include all files
        guard isEnabled else { return true }
        
        let components = path.split(separator: "/").map(String.init)
        
        for component in components {
            if component == "__MACOSX" {
                return false
            }
            if component == ".DS_Store" {
                return false
            }
            if component.hasPrefix("._") {
                return false
            }
        }
        
        return true
    }
}

class HiddenFilesFilter: EntryFilter {
    let id = "com.maczipper.filters.hidden-files"
    let displayName = "Hide hidden files"
    let description = "Removes Unix hidden files (files starting with a dot)"
    @Published var isEnabled: Bool = false
    
    func shouldInclude(path: String) -> Bool {
        // If filter is disabled, include all files
        guard isEnabled else { return true }
        
        let components = path.split(separator: "/").map(String.init)
        
        for component in components {
            if component.hasPrefix(".") && component != "." && component != ".." {
                return false
            }
        }
        
        return true
    }
}

class VersionControlFilter: EntryFilter {
    let id = "com.maczipper.filters.version-control"
    let displayName = "Hide version control folders"
    let description = "Removes .git, .svn, and .hg folders"
    @Published var isEnabled: Bool = false
    
    private let excludedFolders: Set<String> = [".git", ".svn", ".hg"]
    
    func shouldInclude(path: String) -> Bool {
        // If filter is disabled, include all files
        guard isEnabled else { return true }
        
        let components = path.split(separator: "/").map(String.init)
        
        for component in components {
            if excludedFolders.contains(component) {
                return false
            }
        }
        
        return true
    }
}

struct CustomFilterPattern: Codable, Identifiable {
    let id: UUID
    var pattern: String
    var isRegex: Bool
    var description: String
    var isEnabled: Bool
}

class CustomPatternFilter: EntryFilter {
    let id = "com.maczipper.filters.custom-patterns"
    let displayName = "Custom patterns"
    let description = "User-defined exclusion patterns"
    @Published var isEnabled: Bool = true
    @Published var patterns: [CustomFilterPattern] = []
    
    func shouldInclude(path: String) -> Bool {
        for pattern in patterns where pattern.isEnabled {
            if matchesPattern(path, pattern: pattern) {
                return false
            }
        }
        return true
    }
    
    private func matchesPattern(_ path: String, pattern: CustomFilterPattern) -> Bool {
        if pattern.isRegex {
            do {
                let regex = try NSRegularExpression(pattern: pattern.pattern)
                let range = NSRange(path.startIndex..., in: path)
                return regex.firstMatch(in: path, range: range) != nil
            } catch {
                return false
            }
        } else {
            let fnmatch = pattern.pattern
            let components = path.split(separator: "/").map(String.init)
            for component in components {
                if component.matchesGlob(fnmatch) {
                    return true
                }
            }
            return false
        }
    }
}

extension String {
    func matchesGlob(_ pattern: String) -> Bool {
        let nsPattern = pattern
            .replacingOccurrences(of: ".", with: "\\.")
            .replacingOccurrences(of: "*", with: ".*")
            .replacingOccurrences(of: "?", with: ".")
        
        do {
            let regex = try NSRegularExpression(pattern: "^\(nsPattern)$")
            let range = NSRange(self.startIndex..., in: self)
            return regex.firstMatch(in: self, range: range) != nil
        } catch {
            return false
        }
    }
}
