import Foundation

public struct CsvFile: Sendable, Hashable {
    public let header: [String]
    public let rows: [[String]]
    public let delimiter: Character
    public let bestandsnaam: String?

    public init(
        header: [String],
        rows: [[String]],
        delimiter: Character,
        bestandsnaam: String?
    ) {
        self.header = header
        self.rows = rows
        self.delimiter = delimiter
        self.bestandsnaam = bestandsnaam
    }
}

public enum CsvParser {
    /// Detecteert delimiter op basis van eerste niet-lege regel. Kiest tussen
    /// `,` en `;` — de twee populairste in NL/EU exports. Verdedigingsregel:
    /// als beide voorkomen, kies de meest frequente.
    public static func detectDelimiter(in text: String) -> Character {
        let firstLine = text
            .split(whereSeparator: { $0.isNewline })
            .first
            .map(String.init) ?? ""
        let comma = firstLine.filter { $0 == "," }.count
        let semicolon = firstLine.filter { $0 == ";" }.count
        let tab = firstLine.filter { $0 == "\t" }.count
        if tab > comma && tab > semicolon { return "\t" }
        return semicolon > comma ? ";" : ","
    }

    public static func parse(
        text: String,
        bestandsnaam: String? = nil,
        delimiterOverride: Character? = nil
    ) -> CsvFile {
        let delimiter = delimiterOverride ?? detectDelimiter(in: text)
        var rows: [[String]] = []

        for rawLine in text.split(whereSeparator: { $0.isNewline }) {
            let line = rawLine.trimmingCharacters(in: .init(charactersIn: "\r"))
            if line.isEmpty { continue }
            rows.append(splitLine(line, delimiter: delimiter))
        }

        guard let header = rows.first else {
            return CsvFile(header: [], rows: [], delimiter: delimiter, bestandsnaam: bestandsnaam)
        }
        return CsvFile(
            header: header,
            rows: Array(rows.dropFirst()),
            delimiter: delimiter,
            bestandsnaam: bestandsnaam
        )
    }

    /// Eenvoudige line-splitter met support voor quoted fields ("...").
    /// Behandelt embedded quotes als `""`. Lijnen met embedded newlines binnen
    /// quotes worden niet ondersteund — kleine concessie voor Phase 2.
    static func splitLine(_ line: String, delimiter: Character) -> [String] {
        var fields: [String] = []
        var current = ""
        var inQuotes = false
        var iterator = line.makeIterator()

        while let ch = iterator.next() {
            if inQuotes {
                if ch == "\"" {
                    inQuotes = false
                } else {
                    current.append(ch)
                }
            } else if ch == "\"" {
                inQuotes = true
            } else if ch == delimiter {
                fields.append(current)
                current = ""
            } else {
                current.append(ch)
            }
        }
        fields.append(current)
        return fields.map { $0.trimmingCharacters(in: .whitespaces) }
    }
}
