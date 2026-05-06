import Foundation
import Observation
import Database
import Models

@Observable
@MainActor
public final class ActiviteitListViewModel {
    public private(set) var activiteiten: [Activiteit] = []
    public private(set) var personenById: [UUID: Persoon] = [:]
    public var lastErrorMessage: String?

    private let projectId: UUID
    private let activiteitRepo: ActiviteitRepository
    private let persoonRepo: PersoonRepository

    public init(
        projectId: UUID,
        activiteitRepo: ActiviteitRepository,
        persoonRepo: PersoonRepository
    ) {
        self.projectId = projectId
        self.activiteitRepo = activiteitRepo
        self.persoonRepo = persoonRepo
    }

    public func load() async {
        do {
            async let acts = activiteitRepo.fetch(projectId: projectId)
            async let pers = persoonRepo.fetchAll()
            let (loadedActs, loadedPers) = try await (acts, pers)
            self.activiteiten = loadedActs
            self.personenById = Dictionary(uniqueKeysWithValues: loadedPers.map { ($0.id, $0) })
        } catch {
            lastErrorMessage = "Laden mislukt: \(error.localizedDescription)"
        }
    }

    public func delete(id: UUID) async {
        do {
            try await activiteitRepo.delete(id: id)
            await load()
        } catch {
            lastErrorMessage = "Verwijderen mislukt: \(error.localizedDescription)"
        }
    }

    public func bulkSetStatus(_ status: ActiviteitStatus, ids: Set<UUID>) async {
        guard !ids.isEmpty else { return }
        do {
            _ = try await activiteitRepo.bulkSetStatus(status, ids: ids)
            await load()
        } catch {
            lastErrorMessage = "Status bijwerken mislukt: \(error.localizedDescription)"
        }
    }

    public func persoonNaam(for activiteit: Activiteit) -> String {
        personenById[activiteit.persoonId]?.naam ?? "Onbekend"
    }
}
