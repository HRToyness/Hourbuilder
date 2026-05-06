import Foundation
import Observation
import Database
import Models
import Services

@Observable
@MainActor
public final class CsvImportViewModel {
    public private(set) var file: CsvFile?
    public private(set) var detectedBron: ActiviteitBron = .importCsv
    public var mapping: CsvColumnMapping = CsvColumnMapping()
    public var persoonId: UUID?
    public private(set) var personen: [Persoon] = []
    public private(set) var preview: CsvImportPreview?
    public private(set) var isImporting = false
    public private(set) var lastImportResult: ImportResult?
    public var lastErrorMessage: String?

    private let projectId: UUID
    private let mapper: CsvImportMapper
    private let activiteitRepo: ActiviteitRepository
    private let persoonRepo: PersoonRepository

    public init(
        projectId: UUID,
        mapper: CsvImportMapper = CsvImportMapper(),
        activiteitRepo: ActiviteitRepository,
        persoonRepo: PersoonRepository
    ) {
        self.projectId = projectId
        self.mapper = mapper
        self.activiteitRepo = activiteitRepo
        self.persoonRepo = persoonRepo
    }

    public func loadPersonen() async {
        do {
            personen = try await persoonRepo.fetchAll()
            if persoonId == nil {
                persoonId = personen.first?.id
            }
        } catch {
            lastErrorMessage = "Personen laden mislukt: \(error.localizedDescription)"
        }
    }

    public func loadFile(at url: URL) async {
        let extensionLower = url.pathExtension.lowercased()
        let security = url.startAccessingSecurityScopedResource()
        defer { if security { url.stopAccessingSecurityScopedResource() } }

        do {
            let parsed: CsvFile
            if extensionLower == "xlsx" {
                parsed = try XlsxImporter.parse(at: url)
                detectedBron = .importXlsx
            } else {
                let data = try Data(contentsOf: url)
                guard let text = String(data: data, encoding: .utf8)
                    ?? String(data: data, encoding: .isoLatin1) else {
                    lastErrorMessage = "Bestand kon niet als tekst gelezen worden."
                    return
                }
                parsed = CsvParser.parse(text: text, bestandsnaam: url.lastPathComponent)
                detectedBron = .importCsv
            }
            self.file = parsed
            self.mapping = autoMap(header: parsed.header)
            recomputePreview()
        } catch {
            lastErrorMessage = "Bestand laden mislukt: \(error.localizedDescription)"
        }
    }

    public func setMappingDatum(_ idx: Int?) {
        mapping.datumColumn = idx
        recomputePreview()
    }

    public func setMappingUren(_ idx: Int?) {
        mapping.urenColumn = idx
        recomputePreview()
    }

    public func setMappingBeschrijving(_ idx: Int?) {
        mapping.beschrijvingColumn = idx
        recomputePreview()
    }

    public func recomputePreview() {
        guard let file, let persoonId, mapping.isComplete else {
            preview = nil
            return
        }
        preview = mapper.map(
            file: file,
            mapping: mapping,
            projectId: projectId,
            persoonId: persoonId,
            bron: detectedBron
        )
    }

    public var canImport: Bool {
        guard let preview else { return false }
        return !preview.activities.isEmpty && !isImporting
    }

    public func runImport() async -> Bool {
        guard let preview, !preview.activities.isEmpty else { return false }
        isImporting = true
        defer { isImporting = false }
        do {
            let bronType: ImportBronType = detectedBron == .importXlsx ? .xlsx : .csv
            let summary = try await activiteitRepo.runImport(
                projectId: projectId,
                bronType: bronType,
                bestandsnaam: file?.bestandsnaam,
                candidates: preview.activities
            )
            self.lastImportResult = ImportResult(
                inserted: summary.inserted,
                skipped: summary.skipped
            )
            return true
        } catch {
            lastErrorMessage = "Import mislukt: \(error.localizedDescription)"
            return false
        }
    }

    /// Heuristiek: kolomnaam-matching op gangbare termen.
    private func autoMap(header: [String]) -> CsvColumnMapping {
        var m = CsvColumnMapping()
        for (idx, name) in header.enumerated() {
            let lower = name.lowercased()
            if m.datumColumn == nil, lower.contains("datum") || lower.contains("date") {
                m.datumColumn = idx
            }
            if m.urenColumn == nil, lower.contains("uren") || lower.contains("uur") || lower.contains("hour") || lower == "tijd" {
                m.urenColumn = idx
            }
            if m.beschrijvingColumn == nil, lower.contains("beschrijving") || lower.contains("omschrijving") || lower.contains("description") || lower.contains("task") {
                m.beschrijvingColumn = idx
            }
        }
        return m
    }
}
