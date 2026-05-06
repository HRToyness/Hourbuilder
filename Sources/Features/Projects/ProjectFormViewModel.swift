import Foundation
import Observation
import Database
import Models

@Observable
@MainActor
public final class ProjectFormViewModel {
    public var naam: String
    public var klantNaam: String
    public var startDatum: Date
    public var heeftEindDatum: Bool
    public var eindDatum: Date
    public var status: ProjectStatus
    public var factuurNummer: String
    public var doelTotaalKlantUren: String
    public var doelTotaalInternUren: String
    public var notities: String

    public private(set) var isSaving = false
    public var lastErrorMessage: String?

    private let repository: ProjectRepository
    private let editingId: UUID?

    public init(repository: ProjectRepository, existing: Project? = nil) {
        self.repository = repository
        if let existing {
            self.editingId = existing.id
            self.naam = existing.naam
            self.klantNaam = existing.klantNaam
            self.startDatum = existing.startDatum
            self.heeftEindDatum = existing.eindDatum != nil
            self.eindDatum = existing.eindDatum ?? existing.startDatum
            self.status = existing.status
            self.factuurNummer = existing.factuurNummer ?? ""
            self.doelTotaalKlantUren = existing.doelTotaalKlantUren.map { Self.format($0) } ?? ""
            self.doelTotaalInternUren = existing.doelTotaalInternUren.map { Self.format($0) } ?? ""
            self.notities = existing.notities
        } else {
            self.editingId = nil
            self.naam = ""
            self.klantNaam = ""
            self.startDatum = Date()
            self.heeftEindDatum = false
            self.eindDatum = Date()
            self.status = .lopend
            self.factuurNummer = ""
            self.doelTotaalKlantUren = ""
            self.doelTotaalInternUren = ""
            self.notities = ""
        }
    }

    public var canSave: Bool {
        !naam.trimmingCharacters(in: .whitespaces).isEmpty
        && !klantNaam.trimmingCharacters(in: .whitespaces).isEmpty
        && !isSaving
    }

    public func save() async -> Bool {
        guard canSave else { return false }
        isSaving = true
        defer { isSaving = false }

        let project = Project(
            id: editingId ?? UUID(),
            naam: naam.trimmingCharacters(in: .whitespaces),
            klantNaam: klantNaam.trimmingCharacters(in: .whitespaces),
            startDatum: startDatum,
            eindDatum: heeftEindDatum ? eindDatum : nil,
            status: status,
            factuurNummer: factuurNummer.isEmpty ? nil : factuurNummer,
            doelTotaalKlantUren: Self.parse(doelTotaalKlantUren),
            doelTotaalInternUren: Self.parse(doelTotaalInternUren),
            notities: notities
        )

        do {
            _ = try await repository.save(project)
            return true
        } catch {
            lastErrorMessage = "Opslaan mislukt: \(error.localizedDescription)"
            return false
        }
    }

    private static func parse(_ s: String) -> Double? {
        let normalized = s.replacingOccurrences(of: ",", with: ".")
        return Double(normalized.trimmingCharacters(in: .whitespaces))
    }

    private static func format(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        formatter.decimalSeparator = ","
        return formatter.string(from: value as NSNumber) ?? ""
    }
}
