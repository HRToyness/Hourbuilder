import Foundation
import Observation
import Database
import Models

@Observable
@MainActor
public final class TemplateApplyWizardViewModel {
    public let template: ProjectTemplate
    public private(set) var fases: [TemplateFase] = []
    public private(set) var entries: [TemplatePersoonEntry] = []
    public private(set) var personen: [Persoon] = []

    public var projectNaam: String = ""
    public var klantNaam: String = ""
    public var startDatum: Date = Date()
    public var heeftEindDatum: Bool = false
    public var eindDatum: Date = Date()
    public var factuurNummer: String = ""

    public var resolutions: [UUID: PlaceholderResolution] = [:]
    public var newPersoonNamen: [UUID: String] = [:]
    public var newPersoonEmails: [UUID: String] = [:]

    public private(set) var isApplying = false
    public var lastErrorMessage: String?
    public private(set) var lastResult: ProjectTemplateApplyResult?

    private let faseRepo: TemplateFaseRepository
    private let entryRepo: TemplatePersoonEntryRepository
    private let persoonRepo: PersoonRepository
    private let applyService: ProjectTemplateApplyService

    public init(
        template: ProjectTemplate,
        faseRepo: TemplateFaseRepository,
        entryRepo: TemplatePersoonEntryRepository,
        persoonRepo: PersoonRepository,
        applyService: ProjectTemplateApplyService
    ) {
        self.template = template
        self.faseRepo = faseRepo
        self.entryRepo = entryRepo
        self.persoonRepo = persoonRepo
        self.applyService = applyService
    }

    public func load() async {
        do {
            async let f = faseRepo.fetch(templateId: template.id)
            async let e = entryRepo.fetch(templateId: template.id)
            async let p = persoonRepo.fetchAll()
            let (loadedFases, loadedEntries, loadedPersonen) = try await (f, e, p)
            fases = loadedFases
            entries = loadedEntries
            personen = loadedPersonen

            // Default resolution per placeholder: skip
            for entry in entries where entry.mode == .placeholder {
                if resolutions[entry.id] == nil {
                    resolutions[entry.id] = .skip
                }
            }
        } catch {
            lastErrorMessage = "Laden mislukt: \(error.localizedDescription)"
        }
    }

    public var placeholderEntries: [TemplatePersoonEntry] {
        entries.filter { $0.mode == .placeholder }
    }

    public var specifiekePersonen: [Persoon] {
        let ids = Set(entries.compactMap { $0.mode == .specifiek ? $0.persoonId : nil })
        return personen.filter { ids.contains($0.id) }
    }

    public var canApply: Bool {
        !projectNaam.trimmingCharacters(in: .whitespaces).isEmpty
        && !klantNaam.trimmingCharacters(in: .whitespaces).isEmpty
        && !isApplying
    }

    public func setResolution(_ entryId: UUID, _ resolution: PlaceholderResolution) {
        resolutions[entryId] = resolution
    }

    public func setExistingResolution(entryId: UUID, persoonId: UUID) {
        resolutions[entryId] = .existing(persoonId: persoonId)
    }

    public func setSkipResolution(entryId: UUID) {
        resolutions[entryId] = .skip
    }

    public func setNewPersoonResolution(entryId: UUID) {
        guard let entry = entries.first(where: { $0.id == entryId }) else { return }
        let naam = newPersoonNamen[entryId, default: ""]
        let email = newPersoonEmails[entryId]
        resolutions[entryId] = .newPersoon(
            naam: naam.trimmingCharacters(in: .whitespaces),
            rol: entry.placeholderRol ?? "",
            type: entry.placeholderType ?? .intern,
            email: (email?.isEmpty ?? true) ? nil : email
        )
    }

    public func apply() async -> ProjectTemplateApplyResult? {
        guard canApply else { return nil }
        // Voor placeholders die in "newPersoon" mode staan, herevalueer de namen
        // (in geval de gebruiker tikte zonder onChange te triggeren)
        for (entryId, resolution) in resolutions {
            if case .newPersoon = resolution {
                setNewPersoonResolution(entryId: entryId)
            }
        }

        isApplying = true
        defer { isApplying = false }

        do {
            let result = try await applyService.apply(.init(
                templateId: template.id,
                projectNaam: projectNaam.trimmingCharacters(in: .whitespaces),
                klantNaam: klantNaam.trimmingCharacters(in: .whitespaces),
                startDatum: startDatum,
                eindDatum: heeftEindDatum ? eindDatum : nil,
                factuurNummer: factuurNummer.isEmpty ? nil : factuurNummer,
                placeholderResolutions: resolutions
            ))
            lastResult = result
            return result
        } catch {
            lastErrorMessage = "Apply mislukt: \(error.localizedDescription)"
            return nil
        }
    }
}
