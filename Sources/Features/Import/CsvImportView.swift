import SwiftUI
import UniformTypeIdentifiers
import Database
import Models
import Services
import Styling

public struct CsvImportView: View {
    @Bindable var viewModel: CsvImportViewModel
    let onCompleted: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var showFilePicker = false

    public init(viewModel: CsvImportViewModel, onCompleted: @escaping () -> Void) {
        self.viewModel = viewModel
        self.onCompleted = onCompleted
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            AppSectionHeader(
                title: "Importeer uit CSV of Excel",
                subtitle: "Bijlage van leverancier of klant. Records komen binnen als concept."
            )

            HStack(spacing: 12) {
                AppPrimaryButton(title: "Bestand kiezen…") {
                    showFilePicker = true
                }
                if let file = viewModel.file {
                    Text(file.bestandsnaam ?? "geladen")
                        .font(.appBody())
                        .foregroundStyle(Color.appTextSecondary)
                    Text("(\(file.rows.count) regels, delim: '\(String(file.delimiter))')")
                        .font(.appLabel(11))
                        .foregroundStyle(Color.appTextSecondary)
                }
                Spacer()
            }

            if viewModel.file != nil {
                Divider()
                mappingSection
                Divider()
                previewSection
            }

            if let err = viewModel.lastErrorMessage {
                Text(err)
                    .font(.appBody())
                    .foregroundStyle(Color.appWarning)
            }

            Spacer(minLength: 0)
            footer
        }
        .padding(20)
        .frame(minWidth: 760, minHeight: 600)
        .task { await viewModel.loadPersonen() }
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [
                .commaSeparatedText,
                .plainText,
                UTType(filenameExtension: "csv") ?? .data,
                UTType(filenameExtension: "xlsx") ?? .data,
                UTType("org.openxmlformats.spreadsheetml.sheet") ?? .data,
            ],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    Task { await viewModel.loadFile(at: url) }
                }
            case .failure(let error):
                viewModel.lastErrorMessage = error.localizedDescription
            }
        }
    }

    @ViewBuilder
    private var mappingSection: some View {
        if let file = viewModel.file {
            VStack(alignment: .leading, spacing: 12) {
                Text("Kolom-mapping")
                    .font(.appH2())
                HStack(spacing: 12) {
                    columnPicker(
                        label: "Datum",
                        header: file.header,
                        selection: viewModel.mapping.datumColumn,
                        onChange: viewModel.setMappingDatum
                    )
                    columnPicker(
                        label: "Uren",
                        header: file.header,
                        selection: viewModel.mapping.urenColumn,
                        onChange: viewModel.setMappingUren
                    )
                    columnPicker(
                        label: "Beschrijving",
                        header: file.header,
                        selection: viewModel.mapping.beschrijvingColumn,
                        onChange: viewModel.setMappingBeschrijving
                    )
                }

                Picker("Persoon (geldt voor hele bestand)", selection: Binding(
                    get: { viewModel.persoonId },
                    set: { newValue in
                        viewModel.persoonId = newValue
                        viewModel.recomputePreview()
                    }
                )) {
                    Text("— Niet gekozen —").tag(nil as UUID?)
                    ForEach(viewModel.personen) { p in
                        Text("\(p.naam) — \(p.type.label)").tag(p.id as UUID?)
                    }
                }
            }
        }
    }

    private func columnPicker(
        label: String,
        header: [String],
        selection: Int?,
        onChange: @escaping (Int?) -> Void
    ) -> some View {
        Picker(label, selection: Binding(
            get: { selection },
            set: { onChange($0) }
        )) {
            Text("— Niet gemapped —").tag(nil as Int?)
            ForEach(Array(header.enumerated()), id: \.offset) { idx, name in
                Text(name).tag(idx as Int?)
            }
        }
        .frame(minWidth: 160)
    }

    @ViewBuilder
    private var previewSection: some View {
        if let preview = viewModel.preview {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Preview: \(preview.activities.count) klaar")
                        .font(.appH2(14))
                    if !preview.errors.isEmpty {
                        Text("\(preview.errors.count) foutregels")
                            .font(.appLabel())
                            .foregroundStyle(Color.appWarning)
                    }
                    Spacer()
                }

                if !preview.activities.isEmpty {
                    Table(preview.activities) {
                        TableColumn("Datum") { a in
                            Text(formatDate(a.datum))
                                .font(.appMono(11))
                        }
                        TableColumn("Uren") { a in
                            Text(formatHours(a.uren))
                                .font(.appMono(11))
                        }
                        TableColumn("Beschrijving") { a in
                            Text(a.beschrijving)
                                .lineLimit(1)
                        }
                    }
                    .frame(minHeight: 160)
                }

                if !preview.errors.isEmpty {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 2) {
                            ForEach(preview.errors, id: \.rowIndex) { err in
                                Text("Regel \(err.rowIndex + 2): \(err.message)")
                                    .font(.appLabel(11))
                                    .foregroundStyle(Color.appWarning)
                            }
                        }
                    }
                    .frame(maxHeight: 100)
                }
            }
        } else {
            Text("Vul de kolom-mapping en kies een persoon om een preview te zien.")
                .font(.appBody())
                .foregroundStyle(Color.appTextSecondary)
        }
    }

    private var footer: some View {
        HStack {
            if let result = viewModel.lastImportResult {
                Text("\(result.inserted) toegevoegd, \(result.skipped) al aanwezig")
                    .font(.appBody(12))
                    .foregroundStyle(Color.appAccentDark)
            }
            Spacer()
            Button("Sluiten") { dismiss() }
                .keyboardShortcut(.cancelAction)
            AppPrimaryButton(
                title: viewModel.isImporting ? "Bezig…" : "Importeer",
                isDisabled: !viewModel.canImport
            ) {
                Task {
                    if await viewModel.runImport() {
                        onCompleted()
                    }
                }
            }
        }
    }

    private func formatDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "nl_NL")
        f.dateFormat = "d MMM yyyy"
        return f.string(from: date)
    }

    private func formatHours(_ value: Double) -> String {
        let f = NumberFormatter()
        f.minimumFractionDigits = 0
        f.maximumFractionDigits = 2
        f.decimalSeparator = ","
        return f.string(from: value as NSNumber) ?? "\(value)"
    }
}
