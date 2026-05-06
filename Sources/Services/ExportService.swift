import Foundation
import CoreGraphics
import CoreText
import ImageIO
import Models

public struct ExportInput: Sendable {
    public let project: Project
    public let activiteiten: [Activiteit]
    public let personen: [Persoon]
    public let fases: [Fase]
    public let partij: PersoonGroep?  // nil = alle

    public init(
        project: Project,
        activiteiten: [Activiteit],
        personen: [Persoon],
        fases: [Fase],
        partij: PersoonGroep?
    ) {
        self.project = project
        self.activiteiten = activiteiten
        self.personen = personen
        self.fases = fases
        self.partij = partij
    }
}

public enum ExportError: Error, LocalizedError {
    case pdfContextFailed
    case writeFailed(String)

    public var errorDescription: String? {
        switch self {
        case .pdfContextFailed: return "PDF context kon niet worden aangemaakt."
        case .writeFailed(let msg): return "Schrijven mislukt: \(msg)"
        }
    }
}

/// Genereert PDF en CSV exports zonder afhankelijkheden van AppKit zodat de
/// service ook in tests draait (CoreGraphics is voldoende).
public struct ExportService {
    public init() {}

    // MARK: - PDF

    public func generatePDFData(
        _ input: ExportInput,
        branding: Branding = BrandingStore.currentBranding()
    ) throws -> Data {
        let pageSize = CGSize(width: 595, height: 842) // A4 in points
        var mediaBox = CGRect(origin: .zero, size: pageSize)

        let pdfData = NSMutableData()
        guard let consumer = CGDataConsumer(data: pdfData),
              let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
            throw ExportError.pdfContextFailed
        }

        let layout = PDFLayout(pageRect: mediaBox)
        let renderer = PDFRenderer(
            input: input,
            layout: layout,
            context: context,
            branding: branding
        )
        try renderer.draw()
        context.closePDF()
        return pdfData as Data
    }

    public func writePDF(
        _ input: ExportInput,
        to url: URL,
        branding: Branding = BrandingStore.currentBranding()
    ) throws {
        let data = try generatePDFData(input, branding: branding)
        try data.write(to: url, options: .atomic)
    }

    // MARK: - CSV

    public func generateCSV(_ input: ExportInput) -> String {
        let persoonById = Dictionary(uniqueKeysWithValues: input.personen.map { ($0.id, $0) })
        let faseById = Dictionary(uniqueKeysWithValues: input.fases.map { ($0.id, $0) })

        let activiteiten = input.activiteiten
            .filter { $0.status == .bevestigd }
            .filter { activity in
                guard let partij = input.partij else { return true }
                return persoonById[activity.persoonId]?.type.groep == partij
            }
            .sorted { $0.datum < $1.datum }

        var lines: [String] = []
        lines.append("datum;persoon;type;rol;fase;uren;beschrijving;bron")

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let urenFormatter = NumberFormatter()
        urenFormatter.minimumFractionDigits = 0
        urenFormatter.maximumFractionDigits = 2
        urenFormatter.decimalSeparator = ","

        for activity in activiteiten {
            let persoon = persoonById[activity.persoonId]
            let fase = activity.faseId.flatMap { faseById[$0] }
            let row: [String] = [
                dateFormatter.string(from: activity.datum),
                persoon?.naam ?? "",
                persoon?.type.label ?? "",
                persoon?.rol ?? "",
                fase?.naam ?? "",
                urenFormatter.string(from: activity.uren as NSNumber) ?? "\(activity.uren)",
                activity.beschrijving,
                activity.bron.label
            ]
            lines.append(row.map(escapeCSV).joined(separator: ";"))
        }

        // Totalen sectie
        lines.append("")
        lines.append("totalen per groep")
        var totalen: [PersoonGroep: Double] = [:]
        for activity in activiteiten {
            if let groep = persoonById[activity.persoonId]?.type.groep {
                totalen[groep, default: 0] += activity.uren
            }
        }
        for groep in PersoonGroep.allCases {
            let total = totalen[groep] ?? 0
            let formatted = urenFormatter.string(from: total as NSNumber) ?? "\(total)"
            lines.append("\(groep.label);\(formatted)")
        }

        return lines.joined(separator: "\n")
    }

    public func writeCSV(_ input: ExportInput, to url: URL) throws {
        let csv = generateCSV(input)
        // BOM voor Excel zodat UTF-8 correct opgepakt wordt
        let bom = "\u{FEFF}"
        let bytes = (bom + csv).data(using: .utf8) ?? Data()
        try bytes.write(to: url, options: .atomic)
    }

    private func escapeCSV(_ field: String) -> String {
        if field.contains(";") || field.contains("\"") || field.contains("\n") {
            let escaped = field.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(escaped)\""
        }
        return field
    }
}

// MARK: - PDF rendering helpers (private)

private struct PDFLayout {
    let pageRect: CGRect
    var marginX: CGFloat = 40
    var marginY: CGFloat = 50
    var contentWidth: CGFloat { pageRect.width - 2 * marginX }
}

private final class PDFRenderer {
    let input: ExportInput
    let layout: PDFLayout
    let context: CGContext
    let branding: Branding
    var cursorY: CGFloat
    var pageNumber: Int = 1

    init(input: ExportInput, layout: PDFLayout, context: CGContext, branding: Branding) {
        self.input = input
        self.layout = layout
        self.context = context
        self.branding = branding
        self.cursorY = layout.pageRect.height - layout.marginY
    }

    func draw() throws {
        beginPage()
        drawLogo()
        drawHeader()
        drawProjectMeta()
        drawTotalsBlock()
        drawActivityTable()
        drawFooter()
        context.endPDFPage()
    }

    private func drawLogo() {
        guard let data = branding.logoData else { return }
        let options: CFDictionary? = nil
        guard let source = CGImageSourceCreateWithData(data as CFData, options),
              let image = CGImageSourceCreateImageAtIndex(source, 0, options) else {
            return
        }
        let maxWidth: CGFloat = 120
        let maxHeight: CGFloat = 50
        let aspect: CGFloat = CGFloat(image.width) / CGFloat(image.height)
        var w: CGFloat = maxWidth
        var h: CGFloat = w / aspect
        if h > maxHeight {
            h = maxHeight
            w = h * aspect
        }
        let rect = CGRect(
            x: layout.pageRect.width - layout.marginX - w,
            y: cursorY - h + 10,
            width: w,
            height: h
        )
        context.draw(image, in: rect)
    }

    private func beginPage() {
        context.beginPDFPage(nil)
        cursorY = layout.pageRect.height - layout.marginY
    }

    private func drawHeader() {
        drawText(
            "Urenoverzicht",
            at: CGPoint(x: layout.marginX, y: cursorY),
            font: CTFontCreateWithName("Helvetica-Bold" as CFString, 22, nil),
            color: CGColor(srgbRed: 0.10, green: 0.10, blue: 0.18, alpha: 1)
        )
        cursorY -= 28

        let partijLabel = input.partij?.label ?? "Alle partijen"
        drawText(
            partijLabel.uppercased(),
            at: CGPoint(x: layout.marginX, y: cursorY),
            font: CTFontCreateWithName("Helvetica" as CFString, 11, nil),
            color: CGColor(srgbRed: 0.42, green: 0.48, blue: 0.56, alpha: 1)
        )
        cursorY -= 22

        // accent rule (gebruikt geconfigureerde brandingkleur)
        let (r, g, b) = branding.accentRGB
        context.setFillColor(CGColor(srgbRed: r, green: g, blue: b, alpha: 1))
        context.fill(CGRect(x: layout.marginX, y: cursorY, width: 60, height: 2))
        cursorY -= 16
    }

    private func drawProjectMeta() {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "nl_NL")
        formatter.dateFormat = "d MMM yyyy"

        let lines: [(String, String)] = [
            ("Project", input.project.naam),
            ("Klant", input.project.klantNaam),
            ("Periode", "\(formatter.string(from: input.project.startDatum)) – \(input.project.eindDatum.map { formatter.string(from: $0) } ?? "...")"),
            ("Factuurnr", input.project.factuurNummer ?? "—"),
        ]
        for (label, value) in lines {
            drawKVRow(label: label, value: value, at: cursorY)
            cursorY -= 16
        }
        cursorY -= 8
    }

    private func drawKVRow(label: String, value: String, at y: CGFloat) {
        let labelFont = CTFontCreateWithName("Helvetica" as CFString, 10, nil)
        let valueFont = CTFontCreateWithName("Helvetica-Bold" as CFString, 11, nil)
        drawText(
            label.uppercased(),
            at: CGPoint(x: layout.marginX, y: y),
            font: labelFont,
            color: CGColor(srgbRed: 0.42, green: 0.48, blue: 0.56, alpha: 1)
        )
        drawText(
            value,
            at: CGPoint(x: layout.marginX + 90, y: y),
            font: valueFont,
            color: CGColor(srgbRed: 0.10, green: 0.10, blue: 0.18, alpha: 1)
        )
    }

    private func drawTotalsBlock() {
        let confirmed = activitiesForPartij().filter { $0.status == .bevestigd }
        let totaal = confirmed.reduce(0) { $0 + $1.uren }
        let formatter = NumberFormatter()
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 1
        formatter.decimalSeparator = ","

        drawKVRow(
            label: "Totaal uren",
            value: "\(formatter.string(from: totaal as NSNumber) ?? String(totaal))",
            at: cursorY
        )
        cursorY -= 24
    }

    private func drawActivityTable() {
        let persoonById = Dictionary(uniqueKeysWithValues: input.personen.map { ($0.id, $0) })
        let activiteiten = activitiesForPartij()
            .filter { $0.status == .bevestigd }
            .sorted { $0.datum < $1.datum }

        let headerFont = CTFontCreateWithName("Helvetica-Bold" as CFString, 9, nil)
        let bodyFont = CTFontCreateWithName("Helvetica" as CFString, 9, nil)
        let monoFont = CTFontCreateWithName("Menlo" as CFString, 9, nil)

        // header row
        let dark = CGColor(srgbRed: 0.10, green: 0.10, blue: 0.18, alpha: 1)
        context.setFillColor(dark)
        context.fill(CGRect(x: layout.marginX, y: cursorY - 4, width: layout.contentWidth, height: 18))

        let columns = tableColumns()
        for col in columns {
            drawText(
                col.title,
                at: CGPoint(x: col.x, y: cursorY + 2),
                font: headerFont,
                color: CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 1)
            )
        }
        cursorY -= 22

        let textColor = CGColor(srgbRed: 0.10, green: 0.10, blue: 0.18, alpha: 1)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "nl_NL")
        formatter.dateFormat = "d MMM yy"
        let urenFormatter = NumberFormatter()
        urenFormatter.minimumFractionDigits = 0
        urenFormatter.maximumFractionDigits = 1
        urenFormatter.decimalSeparator = ","

        for activity in activiteiten {
            if cursorY < layout.marginY + 60 {
                drawFooter()
                context.endPDFPage()
                pageNumber += 1
                beginPage()
            }
            let persoon = persoonById[activity.persoonId]
            let row: [String] = [
                formatter.string(from: activity.datum),
                persoon?.naam ?? "",
                urenFormatter.string(from: activity.uren as NSNumber) ?? "",
                String(activity.beschrijving.prefix(80))
            ]
            for (idx, col) in columns.enumerated() {
                let font = (idx == 0 || idx == 2) ? monoFont : bodyFont
                drawText(row[idx], at: CGPoint(x: col.x, y: cursorY), font: font, color: textColor)
            }
            cursorY -= 14
        }
    }

    private struct ColumnSpec { let title: String; let x: CGFloat }

    private func tableColumns() -> [ColumnSpec] {
        let xs: [CGFloat] = [layout.marginX + 4, layout.marginX + 80, layout.marginX + 240, layout.marginX + 300]
        return [
            .init(title: "Datum", x: xs[0]),
            .init(title: "Persoon", x: xs[1]),
            .init(title: "Uren", x: xs[2]),
            .init(title: "Beschrijving", x: xs[3]),
        ]
    }

    private func drawFooter() {
        let footerY = layout.marginY - 20
        let footerFont = CTFontCreateWithName("Helvetica" as CFString, 8, nil)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "nl_NL")
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        let exportText = "Geëxporteerd \(formatter.string(from: Date())) — pagina \(pageNumber)"
        drawText(
            exportText,
            at: CGPoint(x: layout.marginX, y: footerY),
            font: footerFont,
            color: CGColor(srgbRed: 0.42, green: 0.48, blue: 0.56, alpha: 1)
        )
    }

    private func activitiesForPartij() -> [Activiteit] {
        let persoonById = Dictionary(uniqueKeysWithValues: input.personen.map { ($0.id, $0) })
        guard let partij = input.partij else { return input.activiteiten }
        return input.activiteiten.filter { act in
            persoonById[act.persoonId]?.type.groep == partij
        }
    }

    private func drawText(_ string: String, at point: CGPoint, font: CTFont, color: CGColor) {
        let attrs: [CFString: Any] = [
            kCTFontAttributeName: font,
            kCTForegroundColorAttributeName: color,
        ]
        guard let attr = CFAttributedStringCreate(
            nil,
            string as CFString,
            attrs as CFDictionary
        ) else { return }
        let line = CTLineCreateWithAttributedString(attr)
        context.textPosition = point
        CTLineDraw(line, context)
    }
}
