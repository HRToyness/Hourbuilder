import Foundation
import Models

public struct CsvColumnMapping: Sendable, Hashable {
    public var datumColumn: Int?
    public var urenColumn: Int?
    public var beschrijvingColumn: Int?

    public init(
        datumColumn: Int? = nil,
        urenColumn: Int? = nil,
        beschrijvingColumn: Int? = nil
    ) {
        self.datumColumn = datumColumn
        self.urenColumn = urenColumn
        self.beschrijvingColumn = beschrijvingColumn
    }

    public var isComplete: Bool {
        datumColumn != nil && urenColumn != nil
    }
}

public struct CsvImportRowError: Sendable, Hashable {
    public let rowIndex: Int
    public let message: String

    public init(rowIndex: Int, message: String) {
        self.rowIndex = rowIndex
        self.message = message
    }
}

public struct CsvImportPreview: Sendable {
    public let activities: [Activiteit]
    public let errors: [CsvImportRowError]

    public init(activities: [Activiteit], errors: [CsvImportRowError]) {
        self.activities = activities
        self.errors = errors
    }
}

public struct CsvImportMapper {
    private let dateFormatters: [DateFormatter]
    private let isoFormatter: ISO8601DateFormatter

    public init() {
        let formats = [
            "yyyy-MM-dd",
            "yyyy/MM/dd",
            "dd-MM-yyyy",
            "dd/MM/yyyy",
            "dd-MM-yy",
            "dd/MM/yy",
            "d MMM yyyy",
        ]
        self.dateFormatters = formats.map { fmt in
            let f = DateFormatter()
            f.locale = Locale(identifier: "nl_NL_POSIX")
            f.dateFormat = fmt
            return f
        }
        self.isoFormatter = ISO8601DateFormatter()
        self.isoFormatter.formatOptions = [.withFullDate]
    }

    public func map(
        file: CsvFile,
        mapping: CsvColumnMapping,
        projectId: UUID,
        persoonId: UUID,
        bron: ActiviteitBron
    ) -> CsvImportPreview {
        guard mapping.isComplete else {
            return CsvImportPreview(activities: [], errors: [])
        }

        var activiteiten: [Activiteit] = []
        var errors: [CsvImportRowError] = []

        for (idx, row) in file.rows.enumerated() {
            guard let datumStr = column(row, mapping.datumColumn),
                  !datumStr.isEmpty else {
                errors.append(.init(rowIndex: idx, message: "Datum ontbreekt"))
                continue
            }
            guard let urenStr = column(row, mapping.urenColumn),
                  !urenStr.isEmpty else {
                errors.append(.init(rowIndex: idx, message: "Uren ontbreken"))
                continue
            }
            guard let datum = parseDate(datumStr) else {
                errors.append(.init(rowIndex: idx, message: "Onbekend datum-formaat: \(datumStr)"))
                continue
            }
            guard let uren = parseHours(urenStr) else {
                errors.append(.init(rowIndex: idx, message: "Onbekend uren-formaat: \(urenStr)"))
                continue
            }
            let beschrijving = column(row, mapping.beschrijvingColumn) ?? ""

            let bronReferentie = (file.bestandsnaam.map { "\($0):\(idx + 2)" })

            let activity = Activiteit(
                projectId: projectId,
                faseId: nil,
                persoonId: persoonId,
                datum: datum,
                uren: uren,
                beschrijving: beschrijving,
                bron: bron,
                bronReferentie: bronReferentie,
                status: .concept,
                bewijs: file.bestandsnaam.map { "Import uit \($0), regel \(idx + 2)" }
            )
            activiteiten.append(activity)
        }

        return CsvImportPreview(activities: activiteiten, errors: errors)
    }

    // MARK: - Parsers

    func parseDate(_ raw: String) -> Date? {
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        if let iso = isoFormatter.date(from: trimmed) { return iso }
        for f in dateFormatters {
            if let d = f.date(from: trimmed) { return d }
        }
        if let serial = parseExcelSerialDate(trimmed) { return serial }
        return nil
    }

    /// Excel slaat datums op als seriële getallen sinds 1899-12-30. Als
    /// XLSX-cellen niet als string zijn opgemaakt komen ze hier binnen als
    /// pure getallen — alleen interpreteren binnen een redelijk bereik om
    /// te voorkomen dat we uren-getallen voor datums aanzien.
    func parseExcelSerialDate(_ raw: String) -> Date? {
        let normalized = raw.replacingOccurrences(of: ",", with: ".")
        guard let serial = Double(normalized) else { return nil }
        // Bereik: 30000 ≈ 1982-03-15, 100000 ≈ 2173 — sluit kleine getallen
        // (uren) en negatieve waardes uit.
        guard serial >= 30000, serial <= 100000 else { return nil }

        var comps = DateComponents()
        comps.year = 1899
        comps.month = 12
        comps.day = 30
        let calendar = Calendar(identifier: .gregorian)
        guard let reference = calendar.date(from: comps) else { return nil }
        return reference.addingTimeInterval(serial * 86400)
    }

    func parseHours(_ raw: String) -> Double? {
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        // "h:mm" formaat
        if let colonIdx = trimmed.firstIndex(of: ":") {
            let h = String(trimmed[..<colonIdx])
            let m = String(trimmed[trimmed.index(after: colonIdx)...])
            if let hi = Int(h), let mi = Int(m) {
                return Double(hi) + Double(mi) / 60.0
            }
        }
        let normalized = trimmed
            .replacingOccurrences(of: ",", with: ".")
            .filter { $0.isNumber || $0 == "." || $0 == "-" }
        return Double(normalized)
    }

    private func column(_ row: [String], _ idx: Int?) -> String? {
        guard let idx, idx >= 0, idx < row.count else { return nil }
        return row[idx]
    }
}
