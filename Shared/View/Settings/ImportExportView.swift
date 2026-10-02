import SwiftUI
import UniformTypeIdentifiers

struct ImportExportView: View {
    @State private var isImporting = false
    @State private var isExporting = false
    @State private var importResult: CSVImporter.ImportResult?
    @State private var showResult = false
    @State private var isProcessing = false
    @State private var exportDocument: CSVDocument?

    var body: some View {
        Form {
            Section {
                Button {
                    exportWatchlist()
                } label: {
                    Label("Export Watchlist to CSV", systemImage: "square.and.arrow.up")
                }
                .disabled(isProcessing)
            } header: {
                Text("Export")
            } footer: {
                Text("Export your entire watchlist as a CSV file that can be opened in any spreadsheet app.")
            }

            Section {
                Button {
                    isImporting = true
                } label: {
                    Label("Import from CSV", systemImage: "square.and.arrow.down")
                }
                .disabled(isProcessing)
            } header: {
                Text("Import")
            } footer: {
                Text("Import a CSV file to add items to your watchlist. Supports Letterboxd export format.")
            }

            if isProcessing {
                Section {
                    HStack {
                        ProgressView()
                            .padding(.trailing, 8)
                        Text("Processing...")
                    }
                }
            }
        }
        .navigationTitle("Import & Export")
#if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
#endif
        .fileImporter(isPresented: $isImporting, allowedContentTypes: [.commaSeparatedText, .plainText]) { result in
            switch result {
            case .success(let url):
                Task { await handleImport(url: url) }
            case .failure(let error):
                print("Import error: \(error.localizedDescription)")
            }
        }
        .fileExporter(isPresented: $isExporting, document: exportDocument, contentType: .commaSeparatedText, defaultFilename: "watchlist") { result in
            switch result {
            case .success(let url):
                print("Exported to: \(url)")
            case .failure(let error):
                print("Export error: \(error.localizedDescription)")
            }
        }
        .alert("Import Complete", isPresented: $showResult) {
            Button("OK", role: .cancel) { }
        } message: {
            if let result = importResult {
                Text("Added: \(result.added)\nAlready saved: \(result.skipped)\nFailed: \(result.failed)")
            }
        }
    }

    private func exportWatchlist() {
        let context = PersistenceController.shared.container.viewContext
        do {
            let csv = try CSVExporter.exportWatchlist(from: context)
            exportDocument = CSVDocument(csv: csv)
            isExporting = true
        } catch {
            print("Export error: \(error.localizedDescription)")
        }
    }

    @MainActor
    private func handleImport(url: URL) async {
        isProcessing = true
        defer { isProcessing = false }

        guard url.startAccessingSecurityScopedResource() else { return }
        defer { url.stopAccessingSecurityScopedResource() }

        do {
            let data = try Data(contentsOf: url)
            guard let csvString = String(data: data, encoding: .utf8) else { return }
            let format = CSVImporter.detectFormat(from: csvString)
            importResult = await CSVImporter.importCSV(csvString, format: format)
            showResult = true
        } catch {
            print("Import error: \(error.localizedDescription)")
        }
    }
}

struct CSVDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.commaSeparatedText] }

    var csv: String

    init(csv: String) {
        self.csv = csv
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents,
              let string = String(data: data, encoding: .utf8) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        csv = string
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        guard let data = csv.data(using: .utf8) else {
            throw CocoaError(.fileWriteUnknown)
        }
        return FileWrapper(regularFileWithContents: data)
    }
}
