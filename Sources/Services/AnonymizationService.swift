import Foundation
import Models

/// Houdt een per-sessie bidirectionele mapping bij tussen echte
/// `Persoon` records en geanonimiseerde identifiers (bv. "intern_dev_1").
/// Reset bij elke nieuwe AI-aanroep zodat mappings niet lekken tussen
/// projecten.
public final class AnonymizationService: @unchecked Sendable {
    public init() {}

    private let lock = NSLock()
    private var realToAnon: [String: String] = [:]
    private var anonToReal: [String: String] = [:]
    private var counters: [String: Int] = [:]

    public func anonymize(persoon: Persoon) -> String {
        lock.lock()
        defer { lock.unlock() }
        let realKey = persoon.id.uuidString
        if let existing = realToAnon[realKey] { return existing }
        let prefix = anonPrefix(for: persoon)
        let next = (counters[prefix] ?? 0) + 1
        counters[prefix] = next
        let anon = "\(prefix)_\(next)"
        realToAnon[realKey] = anon
        anonToReal[anon] = realKey
        return anon
    }

    /// Stabiele rol-prefix voor een persoon (bv. "intern_dev"), zonder
    /// per-persoon counter. Geschikt voor het sturen van rol-types naar de
    /// AI als generieke groep-categorieën.
    public func roleType(for persoon: Persoon) -> String {
        anonPrefix(for: persoon)
    }

    public func resolve(anon: String) -> UUID? {
        lock.lock()
        defer { lock.unlock() }
        guard let idString = anonToReal[anon] else { return nil }
        return UUID(uuidString: idString)
    }

    public func reset() {
        lock.lock()
        defer { lock.unlock() }
        realToAnon.removeAll()
        anonToReal.removeAll()
        counters.removeAll()
    }

    /// Verwijder herkenbare info uit vrije tekst (event titels, beschrijvingen).
    /// Defense-in-depth — beste verdediging is om vrije tekst niet te sturen.
    public func sanitize(_ text: String) -> String {
        var result = text
        result = result.replacingOccurrences(
            of: #"[\w.+-]+@[\w-]+\.[\w.-]+"#,
            with: "[email]",
            options: .regularExpression
        )
        result = result.replacingOccurrences(
            of: #"\+?\d[\d\s-]{7,}"#,
            with: "[phone]",
            options: .regularExpression
        )
        return result
    }

    private func anonPrefix(for persoon: Persoon) -> String {
        let role = persoon.rol
            .lowercased()
            .replacingOccurrences(of: " ", with: "_")
            .filter { $0.isLetter || $0 == "_" }

        switch persoon.type {
        case .intern:
            return role.isEmpty ? "intern" : "intern_\(role)"
        case .klant:
            return role.isEmpty ? "klant" : "klant_\(role)"
        case .leverancierWebbouwer:
            return "leverancier_web"
        case .leverancierEditor:
            return "leverancier_editor"
        }
    }
}
