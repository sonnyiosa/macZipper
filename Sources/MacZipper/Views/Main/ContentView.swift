import SwiftUI
import UniformTypeIdentifiers
import QuickLook

enum FilePickerMode {
    case openArchive
    case extractSelected
}

struct ContentView: View {
    @Binding var document: ZipDocument
    let fileURL: URL?
    @StateObject private var viewModel = ZipBrowserViewModel()
    @State private var isArchiveLoaded = false
    @State private var filePickerMode: FilePickerMode?
    @State private var searchText = ""
    @FocusState private var isSearchFieldFocused: Bool
    @State private var quickLookIsPresented = false
    
    private var showingFilePicker: Binding<Bool> {
        Binding(
            get: { filePickerMode != nil },
            set: { _ in }
        )
    }
    
    var body: some View {
        Group {
            if viewModel.isLoaded {
                archiveContentView
            } else if viewModel.isLoading {
                loadingView
            } else {
                emptyStateView
            }
        }
        .alert("Error", isPresented: $viewModel.showError, presenting: viewModel.errorMessage) { error in
            Button("OK", role: .cancel) { }
        } message: { error in
            Text(error)
        }
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            handleDrop(providers: providers)
        }
        .toolbar {
            ToolbarItemGroup {
                Button(action: {
                    filePickerMode = .openArchive
                }) {
                    Label("Open", systemImage: "doc.badge.plus")
                }
                .keyboardShortcut("o", modifiers: .command)
                
                Button("Extract All") {
                    Task {
                        await viewModel.extractAll()
                    }
                }
                .disabled(!viewModel.isLoaded || viewModel.isExtracting)
                
                Button("Extract Selected") {
                    filePickerMode = .extractSelected
                }
                .disabled(viewModel.selectedPaths.isEmpty || viewModel.isExtracting)
            }
            
            ToolbarItem(placement: .primaryAction) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search files...", text: $searchText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(width: 200)
                        .focused($isSearchFieldFocused)
                }
            }
        }
        .fileImporter(
            isPresented: showingFilePicker,
            allowedContentTypes: filePickerMode == .openArchive
                ? [.zip] : [.folder],
            allowsMultipleSelection: false,
            onCompletion: { result in
                switch result {
                case .success(let urls):
                    if let url = urls.first {
                        switch filePickerMode {
                        case .openArchive:
                            Task {
                                await viewModel.loadArchive(from: url)
                            }

                        case .extractSelected:
                            Task {
                                await viewModel.extractSelected(to: url)
                            }
                        case .none:
                            break
                        }
                    }
                case .failure(let error):
                    switch filePickerMode {
                    case .openArchive:
                        viewModel.errorMessage =
                            "Failed to open file: \(error.localizedDescription)"

                    case .extractSelected:
                        viewModel.errorMessage =
                            "Failed to extract: \(error.localizedDescription)"
                    case .none:
                        break
                    }
                    viewModel.showError = true
                }
                filePickerMode = nil
            },
            onCancellation: {
                filePickerMode = nil
            }
        )
        .onAppear {
            setupKeyboardShortcuts()
            setupNotifications()
        }
        .task {
            // Try to load from fileURL (when opened via document-based architecture)
            if let url = fileURL {
                await viewModel.loadArchive(from: url)
            }
        }
        .quickLookPreview($viewModel.quickLookURL, in: viewModel.quickLookURL != nil ? [viewModel.quickLookURL!] : [])
    }

    private func setupNotifications() {
        NotificationCenter.default.addObserver(forName: .extractAll, object: nil, queue: .main) { _ in
            Task {
                await viewModel.extractAll()
            }
        }
        
        NotificationCenter.default.addObserver(forName: .extractSelected, object: nil, queue: .main) { _ in
            filePickerMode = .extractSelected
        }
        
        NotificationCenter.default.addObserver(forName: .selectAllFiles, object: nil, queue: .main) { _ in
            Task { @MainActor in
                viewModel.selectAll()
            }
        }
        
        NotificationCenter.default.addObserver(forName: .deselectAllFiles, object: nil, queue: .main) { _ in
            Task { @MainActor in
                viewModel.deselectAll()
            }
        }
        

    }
    
    private var archiveContentView: some View {
        NavigationSplitView {
            FolderTreeView(viewModel: viewModel, searchText: $searchText)
                .frame(minWidth: 220)
        } detail: {
            FileListView(viewModel: viewModel, searchText: $searchText)
        }
        .safeAreaInset(edge: .bottom) {
            StatusBarView(viewModel: viewModel)
        }
    }
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Loading archive...")
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.controlBackgroundColor))
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.zipper")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("Open a ZIP Archive")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Drag and drop a ZIP file here, or click the button below")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Open ZIP File...") {
                filePickerMode = .openArchive
            }
            .keyboardShortcut("o", modifiers: .command)
            .padding(.top, 10)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.controlBackgroundColor))
    }
    
    private func setupKeyboardShortcuts() {
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            handleKeyEvent(event)
        }
    }
    
    private func handleKeyEvent(_ event: NSEvent) -> NSEvent? {
        let modifiers = event.modifierFlags
        
        // Handle Command shortcuts
        if modifiers.contains(.command) {
            switch event.charactersIgnoringModifiers {
            case "a":
                viewModel.selectAll()
                return nil
            case "d":
                viewModel.deselectAll()
                return nil
            case "f":
                isSearchFieldFocused = true
                return nil
            default:
                break
            }
        }
        
        // Handle Space bar for Quick Look (only when files are selected)
        if event.keyCode == 49 { // Space key
            if let entry = viewModel.getFirstSelectedEntry() {
                Task {
                    await viewModel.quickLookEntry(at: entry.path)
                }
                return nil
            }
        }
        
        return event
    }
    
    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        for provider in providers {
            // Accept file URLs from Finder drag (public.file-url)
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                let _ = provider.loadObject(ofClass: URL.self) { (url, error) in
                    if let url = url {
                        Task { @MainActor in
                            await viewModel.loadArchive(from: url)
                        }
                    }
                }

                return true
            }
        }
        return false
    }
}
