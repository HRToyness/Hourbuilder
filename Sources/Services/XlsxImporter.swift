import Foundation
import CoreXLSX

public enum XlsxImporter {
    public enum XlsxError: Error, LocalizedError {
        case cannotOpen
        case noWorksheets

        public var errorDescription: String? {
            switch self {
            case .cannotOpen: return "Kon Excel bestand niet openen."
            case .noWorksheets: return "Geen werkbladen gevonden in het bestand."
            }
        }
    }

    /// Leest het eerste werkblad uit een XLSX bestand en mapt het naar onze
    /// `CsvFile` structuur — zo loopt het door dezelfde import-pipeline als
    /// CSV (kolom-mapping, datum-parsing, dedupe, runImport).
    public static func parse(at url: URL) throws -> CsvFile {
        guard let file = XLSXFile(filepath: url.path) else {
            throw XlsxError.cannotOpen
        }

        let sharedStrings = try file.parseSharedStrings()
        let workbooks = try file.parseWorkbooks()
        guard let workbook = workbooks.first else { throw XlsxError.noWorksheets }
        let paths = try file.parseWorksheetPathsAndNames(workbook: workbook)
        guard let firstPath = paths.first?.path else { throw XlsxError.noWorksheets }
        let worksheet = try file.parseWorksheet(at: firstPath)

        var rows: [[String]] = []
        let maxColumns = computeMaxColumnCount(worksheet: worksheet)

        for row in worksheet.data?.rows ?? [] {
            var dense: [String] = Array(repeating: "", count: maxColumns)
            for cell in row.cells {
                let idx = columnIndex(for: cell.reference.column)
                guard idx >= 0, idx < dense.count else { continue }
                dense[idx] = cellText(cell, sharedStrings: sharedStrings)
            }
            // Skip volledig lege rijen
            if dense.contains(where: { !$0.isEmpty }) {
                rows.append(dense)
            }
        }

        let header = rows.first ?? []
        let body = Array(rows.dropFirst())
        return CsvFile(
            header: header,
            rows: body,
            delimiter: "\t",
            bestandsnaam: url.lastPathComponent
        )
    }

    private static func computeMaxColumnCount(worksheet: Worksheet) -> Int {
        var maxIdx = -1
        for row in worksheet.data?.rows ?? [] {
            for cell in row.cells {
                let idx = columnIndex(for: cell.reference.column)
                if idx > maxIdx { maxIdx = idx }
            }
        }
        return max(0, maxIdx + 1)
    }

    private static func cellText(_ cell: Cell, sharedStrings: SharedStrings?) -> String {
        if let strings = sharedStrings, let resolved = cell.stringValue(strings) {
            return resolved
        }
        return cell.value ?? ""
    }

    /// Excel kolomletters → 0-based index. "A" → 0, "Z" → 25, "AA" → 26.
    static func columnIndex(for column: ColumnReference) -> Int {
        let name = column.value.uppercased()
        var index = 0
        for char in name {
            guard let ascii = char.asciiValue,
                  ascii >= Character("A").asciiValue!,
                  ascii <= Character("Z").asciiValue! else { return -1 }
            let digit = Int(ascii - Character("A").asciiValue!) + 1
            index = index * 26 + digit
        }
        return index - 1
    }
}
