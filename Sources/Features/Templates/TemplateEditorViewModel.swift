import Foundation
import Observation
import Database
import Models

@Observable
@MainActor
public final class TemplateEditorViewModel {
    public var naam: String
    public var beschrijving: String
    public var defaultDoelKlantUrenInput: String
    public var defaultDoelInternUrenInput: String
    public var defaultNotities: String

    public private(set) var fases: [TemplateFase] = []
    public private(set) var entries: [TemplatePersoonEntry] = []
    public private(set) var personen: [Persoon] = []  // global, voor specifieke entry pickers

    public private(set) var isSavingHeader = false
    public var lastErrorMessage: String?

    private let templateRepo: ProjectTemplateRepository
    private let faseRepo: TemplateFaseRepository
    private let entryRepo: TemplatePersoonEntryRepository
    private let persoonRepo: PersoonRepository
    private(set) var template: ProjectTemplate

    public init(
        template: ProjectTemplate,
        templateRepo: ProjectTemplateRepository,
        faseRepo: TemplateFaseRepository,
        entryRepo: TemplatePersoonEntryRepository,
        persoonRepo: PersoonRepository
    ) {
        self.template = template
        self.templateRepo = templateRepo
        self.faseRepo = faseRepo
        self.entryRepo = entryRepo
        self.persoonRepo = persoonRepo
        self.naam = template.naam
        self.beschrijving = template.beschrijving
        self.defaultDoelKlantUrenInput = Self.formatOptional(template.defaultDoelKlantUren)
        self.defaultDoelInternUrenInput = Self.formatOptional(template.defaultDoelInternUren)
        self.defaultNotities = template.defaultNotities
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
        } catch {
            lastErrorMessage = "Laden mislukt: \(error.localizedDescription)"
        }
    }

    // MARK: - Header (template fields)

    public func saveHeader() async {
        isSavingHeader = true
        defer { isSavingHeader = false }
        var copy = template
        copy.naam = naam.trimmingCharacters(in: .whitespaces)
        copy.beschrijving = beschrijving
        copy.defaultDoelKlantUren = Self.parse(defaultDoelKlantUrenInput)
        copy.defaultDoelInternUren = Self.parse(defaultDoelInternUrenInput)
        copy.defaultNotities = defaultNotities
        do {
            template = try await templateRepo.save(copy)
        } catch {
            lastErrorMessage = "Opslaan mislukt: \(error.localizedDescription)"
        }
    }

    // MARK: - Fases

    public func addFase() async {
        let nextVolgorde = (fases.map(\.volgorde).max() ?? 0) + 1
        let fase = TemplateFase(
            templateId: template.id,
            naam: "Nieuwe fase",
            volgorde: nextVolgorde,
            weekVanaf: nil,
            weekTotEnMet: nil
        )
        do {
            _ = try await faseRepo.save(fase)
            await load()
        } catch {
            lastErrorMessage = "Fase toevoegen mislukt: \(error.localizedDescription)"
        }
    }

    public func updateFase(_ fase: TemplateFase) async {
        do {
            _ = try await faseRepo.save(fase)
            await load()
        } catch {
            lastErrorMessage = "Fase opslaan mislukt: \(error.localizedDescription)"
        }
    }

    public func deleteFase(id: UUID) async {
        do {
            try await faseRepo.delete(id: id)
            await load()
        } catch {
            lastErrorMessage = "Fase verwijderen mislukt: \(error.localizedDescription)"
        }
    }

    // MARK: - Persoon entries

    public func addSpecifiekEntry(persoonId: UUID) async {
        let entry = TemplatePersoonEntry.specifiek(templateId: template.id, persoonId: persoonId)
        await saveEntry(entry)
    }

    public func addPlaceholderEntry(rol: String, type: PersoonType) async {
        let entry = TemplatePersoonEntry.placeholder(templateId: template.id, rol: rol, type: type)
        await saveEntry(entry)
    }

    public func updateEntry(_ entry: TemplatePersoonEntry) async {
        await saveEntry(entry)
    }

    public func deleteEntry(id: UUID) async {
        do {
            try await entryRepo.delete(id: id)
            await load()
        } catch {
            lastErrorMessage = "Persoon-entry verwijderen mislukt: \(error.localizedDescription)"
        }
    }

    private func saveEntry(_ entry: TemplatePersoonEntry) async {
        do {
            _ = try await entryRepo.save(entry)
            await load()
        } catch {
            lastErrorMessage = "Persoon-entry opslaan mislukt: \(error.localizedDescription)"
        }
    }

    // MARK: - Helpers

    private static func parse(_ input: String) -> Double? {
        let normalized = input.replacingOccurrences(of: ",", with: ".")
        return Double(normalized.trimmingCharacters(in: .whitespaces))
    }

    private static func formatOptional(_ value: Double?) -> String {
        guard let value else { return "" }
        let f = NumberFormatter()
        f.minimumFractionDigits = 0
        f.maximumFractionDigits = 2
        f.decimalSeparator = ","
        return f.string(from: value as NSNumber) ?? ""
    }
}
