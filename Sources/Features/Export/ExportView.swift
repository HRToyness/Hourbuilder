import SwiftUI
import UniformTypeIdentifiers
import Database
import Models
import Styling

public struct ExportView: View {
    @Bindable var viewModel: ExportViewModel

    @Environment(\.dismiss) private var dismiss
    @State private var showPDFExporter = false
    @State private var showCSVExporter = false
    @State private var statusMessage: String?

    public init(viewModel: ExportViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            AppSectionHeader(
                title: "Exporteren",
                subtitle: "Genereer een PDF urenoverzicht of een CSV met totalen."
            )

            Picker("Partij", selection: $viewModel.partij) {
                Text("Alle partijen").tag(nil as PersoonGroep?)
                ForEach(PersoonGroep.allCases) { groep in
                    Text(groep.label).tag(groep as PersoonGroep?)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: viewModel.partij) { _, _ in viewModel.clearGenerated() }

            HStack(spacing: 12) {
                AppPrimaryButton(title: "Genereer PDF") {
                    viewModel.generatePDF()
                    if viewModel.pdfData != nil {
                        showPDFExporter = true
                    }
                }
                AppPrimaryButton(title: "Genereer CSV") {
                    viewModel.generateCSV()
                    if viewModel.csvText != nil {
                        showCSVExporter = true
                    }
                }
                Spacer()
            }

            if let status = statusMessage {
                Text(status)
                    .font(.appBody(12))
                    .foregroundStyle(Color.appAccentDark)
            }

            if let err = viewModel.lastErrorMessage {
                Text(err)
                    .font(.appBody())
                    .foregroundStyle(Color.appWarning)
            }

            Spacer(minLength: 0)
            HStack {
                Spacer()
                Button("Sluiten") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
        }
        .padding(20)
        .frame(minWidth: 520, minHeight: 320)
        .task { await viewModel.load() }
        .fileExporter(
            isPresented: $showPDFExporter,
            document: viewModel.pdfData.map { ExportPDFDocument(data: $0) },
            contentType: .pdf,
            defaultFilename: viewModel.defaultFilenamePDF
        ) { result in
            handleExportResult(result)
        }
        .fileExporter(
            isPresented: $showCSVExporter,
            document: viewModel.csvText.map { ExportCSVDocument(text: $0) },
            contentType: .commaSeparatedText,
            defaultFilename: viewModel.defaultFilenameCSV
        ) { result in
            handleExportResult(result)
        }
    }

    private func handleExportResult(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            statusMessage = "Opgeslagen: \(url.lastPathComponent)"
        case .failure(let error):
            viewModel.lastErrorMessage = error.localizedDescription
        }
    }
}
