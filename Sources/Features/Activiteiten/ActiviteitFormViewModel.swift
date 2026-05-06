import Foundation
import Observation
import Database
import Models

@Observable
@MainActor
public final class ActiviteitFormViewModel {
    public var persoonId: UUID?
    public var faseId: UUID?
    public var datum: Date
    public var urenInput: String
    public var beschrijving: String
    public var status: ActiviteitStatus

    public private(set) var personen: [Persoon] = []
    public private(set) var fases: [Fase] = []
    public private(set) var isSaving = false
    public var lastErrorMessage: String?

    private let projectId: UUID
    private let editingId: UUID?
    private let activiteitRepo: ActiviteitRepository
    private let persoonRepo: PersoonRepository
    private let faseRepo: FaseRepository
    private let memberRepo: ProjectMemberRepository

    public init(
        projectId: UUID,
        existing: Activiteit? = nil,
        activiteitRepo: ActiviteitRepository,
        persoonRepo: PersoonRepository,
        faseRepo: FaseRepository,
        memberRepo: ProjectMemberRepository
    ) {
        self.projectId = projectId
        self.activiteitRepo = activiteitRepo
        self.persoonRepo = persoonRepo
        self.faseRepo = faseRepo
        self.memberRepo = memberRepo
        self.editingId = existing?.id

        if let e = existing {
            self.persoonId = e.persoonId
            self.faseId = e.faseId
            self.datum = e.datum
            self.urenInput = Self.format(e.uren)
            self.beschrijving = e.beschrijving
            self.status = e.status
        } else {
            self.persoonId = nil
            self.faseId = nil
            self.datum = Date()
            self.urenInput = ""
            self.beschrijving = ""
            self.status = .bevestigd
        }
    }

    public var canSave: Bool {
        persoonId != nil
        && parsedUren != nil
        && (parsedUren ?? 0) > 0
        && !isSaving
    }

    public var parsedUren: Double? {
        let normalized = urenInput.replacingOccurrences(of: ",", with: ".")
        return Double(normalized.trimmingCharacters(in: .whitespaces))
    }

    public func loadPickerOptions() async {
        do {
            async let pers = persoonRepo.fetchAll()
            async let fas = faseRepo.fetch(projectId: projectId)
            let (loadedPers, loadedFas) = try await (pers, fas)
            self.personen = loadedPers
            self.fases = loadedFas
            if persoonId == nil {
                persoonId = loadedPers.first?.id
            }
        } catch {
            lastErrorMessage = "Kon opties niet laden: \(error.localizedDescription)"
        }
    }

    public func save() async -> Bool {
        guard let persoonId, let uren = parsedUren else { return false }
        isSaving = true
        defer { isSaving = false }

        let activiteit = Activiteit(
            id: editingId ?? UUID(),
            projectId: projectId,
            faseId: faseId,
            persoonId: persoonId,
            datum: datum,
            uren: uren,
            beschrijving: beschrijving,
            bron: .handmatig,
            bronReferentie: nil,
            status: status,
            bewijs: nil
        )
        do {
            _ = try await activiteitRepo.save(activiteit)
            // Zorg dat de persoon ook lid is van het project — anders zou de
            // matrix view 'm wel tonen via activiteit-fallback maar de
            // Personen tab niet.
            _ = try await memberRepo.add(projectId: projectId, persoonId: persoonId)
            return true
        } catch {
            lastErrorMessage = "Opslaan mislukt: \(error.localizedDescription)"
            return false
        }
    }

    private static func format(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        formatter.decimalSeparator = ","
        return formatter.string(from: value as NSNumber) ?? ""
    }
}
