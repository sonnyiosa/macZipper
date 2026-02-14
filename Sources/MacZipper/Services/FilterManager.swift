import Foundation
import SwiftUI

@MainActor
class FilterManager: ObservableObject {
    @Published var macOSFilter: MacOSMetadataFilter
    @Published var hiddenFilesFilter: HiddenFilesFilter
    @Published var versionControlFilter: VersionControlFilter
    @Published var customPatternFilter: CustomPatternFilter
    
    @Published var areFiltersActive: Bool = false
    @Published var hiddenCount: Int = 0
    
    private var cancellables: Set<AnyCancellable> = []
    
    private var allFilters: [any EntryFilter] = []
    
    var filters: [any EntryFilter] {
        allFilters
    }
    
    init() {
        macOSFilter = MacOSMetadataFilter()
        hiddenFilesFilter = HiddenFilesFilter()
        versionControlFilter = VersionControlFilter()
        customPatternFilter = CustomPatternFilter()
        
        allFilters = [macOSFilter, hiddenFilesFilter, versionControlFilter, customPatternFilter]
        
        loadSettings()
        setupSubscriptions()
        updateActiveState()
    }
    
    private func setupSubscriptions() {
        macOSFilter.objectWillChange
            .sink { [weak self] in
                self?.handleFilterChange()
            }
            .store(in: &cancellables)
        
        hiddenFilesFilter.objectWillChange
            .sink { [weak self] in
                self?.handleFilterChange()
            }
            .store(in: &cancellables)
        
        versionControlFilter.objectWillChange
            .sink { [weak self] in
                self?.handleFilterChange()
            }
            .store(in: &cancellables)
        
        customPatternFilter.objectWillChange
            .sink { [weak self] in
                self?.handleFilterChange()
            }
            .store(in: &cancellables)
    }
    
    private func handleFilterChange() {
        // objectWillChange fires BEFORE the property changes, so we need to
        // defer the update to the next runloop iteration
        DispatchQueue.main.async { [weak self] in
            self?.updateActiveState()
            self?.saveSettings()
        }
    }
    
    private func updateActiveState() {
        areFiltersActive = allFilters.contains { $0.isEnabled }
    }
    
    func shouldInclude(path: String) -> Bool {
        for filter in allFilters {
            if filter.isEnabled {
                if !filter.shouldInclude(path: path) {
                    return false
                }
            }
        }
        return true
    }
    
    func shouldInclude(entry: ZipEntry) -> Bool {
        return shouldInclude(path: entry.path)
    }
    
    func shouldInclude(node: ZipEntryNode) -> Bool {
        return shouldInclude(path: node.path)
    }
    
    func filter(entries: [ZipEntry]) -> [ZipEntry] {
        let filtered = entries.filter { shouldInclude(entry: $0) }
        hiddenCount = entries.count - filtered.count
        return filtered
    }
    
    func filter(nodes: [ZipEntryNode]) -> [ZipEntryNode] {
        let filtered = nodes.filter { shouldInclude(node: $0) }
        hiddenCount = nodes.count - filtered.count
        return filtered
    }
    
    func calculateHiddenCount(from entries: [ZipEntry]) -> Int {
        return entries.filter { !shouldInclude(entry: $0) }.count
    }
    
    func enableAllFilters() {
        macOSFilter.isEnabled = true
        hiddenFilesFilter.isEnabled = true
        versionControlFilter.isEnabled = true
        customPatternFilter.isEnabled = true
        updateActiveState()
        saveSettings()
    }
    
    func disableAllFilters() {
        macOSFilter.isEnabled = false
        hiddenFilesFilter.isEnabled = false
        versionControlFilter.isEnabled = false
        customPatternFilter.isEnabled = false
        updateActiveState()
        saveSettings()
    }
    
    func resetToDefaults() {
        macOSFilter.isEnabled = true
        hiddenFilesFilter.isEnabled = false
        versionControlFilter.isEnabled = false
        customPatternFilter.isEnabled = true
        customPatternFilter.patterns = []
    }
    
    private func saveSettings() {
        var settings: [String: Any] = [:]
        settings["macOSFilterEnabled"] = macOSFilter.isEnabled
        settings["hiddenFilesFilterEnabled"] = hiddenFilesFilter.isEnabled
        settings["versionControlFilterEnabled"] = versionControlFilter.isEnabled
        settings["customPatternFilterEnabled"] = customPatternFilter.isEnabled
        
        if let patternsData = try? JSONEncoder().encode(customPatternFilter.patterns) {
            settings["customPatterns"] = patternsData
        }
        
        UserDefaults.standard.set(settings, forKey: "FilterManagerSettings")
    }
    
    private func loadSettings() {
        guard let settings = UserDefaults.standard.dictionary(forKey: "FilterManagerSettings") else {
            return
        }
        
        if let macOSEnabled = settings["macOSFilterEnabled"] as? Bool {
            macOSFilter.isEnabled = macOSEnabled
        }
        
        if let hiddenFilesEnabled = settings["hiddenFilesFilterEnabled"] as? Bool {
            hiddenFilesFilter.isEnabled = hiddenFilesEnabled
        }
        
        if let vcEnabled = settings["versionControlFilterEnabled"] as? Bool {
            versionControlFilter.isEnabled = vcEnabled
        }
        
        if let customEnabled = settings["customPatternFilterEnabled"] as? Bool {
            customPatternFilter.isEnabled = customEnabled
        }
        
        if let patternsData = settings["customPatterns"] as? Data {
            if let patterns = try? JSONDecoder().decode([CustomFilterPattern].self, from: patternsData) {
                customPatternFilter.patterns = patterns
            }
        }
    }
}

import Combine
