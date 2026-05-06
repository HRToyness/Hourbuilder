import Foundation
import Observation
import Database
import Models

@Observable
@MainActor
public final class TemplateListViewModel {
    public private(set) var templates: [ProjectTemplate] = []
    public private(set) var faseCountById: [UUID: Int] = [:]
    public private(set) var persoonCountById: [UUID: Int] = [:]
    public var lastErrorMessage: String?

    private let templateRepo: ProjectTemplateRepository
    private let faseRepo: TemplateFaseRepository
    private let entryRepo: TemplatePersoonEntryRepository

    public init(
        templateRepo: ProjectTemplateRepository,
        faseRepo: TemplateFaseRepository,
        entryRepo: TemplatePersoonEntryRepository
    ) {
        self.templateRepo = templateRepo
        self.faseRepo = faseRepo
        self.entryRepo = entryRepo
    }

    public func load() async {
        do {
            let all = try await templateRepo.fetchAll()
            templates = all
            var faseCounts: [UUID: Int] = [:]
            var entryCounts: [UUID: Int] = [:]
            for template in all {
                let fases = try await faseRepo.fetch(templateId: template.id)
                let entries = try await entryRepo.fetch(templateId: template.id)
                faseCounts[template.id] = fases.count
                entryCounts[template.id] = entries.count
            }
            faseCountById = faseCounts
            persoonCountById = entryCounts
        } catch {
            lastErrorMessage = "Templates laden mislukt: \(error.localizedDescription)"
        }
    }

    public func delete(id: UUID) async {
        do {
            try await templateRepo.delete(id: id)
            await load()
        } catch {
            lastErrorMessage = "Verwijderen mislukt: \(error.localizedDescription)"
        }
    }
}
