import Foundation
import Observation
import Database
import Models

@Observable
@MainActor
public final class FaseListViewModel {
    public private(set) var fases: [Fase] = []
    public var lastErrorMessage: String?

    private let projectId: UUID
    private let repository: FaseRepository

    public init(projectId: UUID, repository: FaseRepository) {
        self.projectId = projectId
        self.repository = repository
    }

    public func load() async {
        do {
            fases = try await repository.fetch(projectId: projectId)
        } catch {
            lastErrorMessage = "Fases laden mislukt: \(error.localizedDescription)"
        }
    }

    public func delete(id: UUID) async {
        do {
            try await repository.delete(id: id)
            await load()
        } catch {
            lastErrorMessage = "Verwijderen mislukt: \(error.localizedDescription)"
        }
    }

    public var nextVolgorde: Int {
        (fases.map(\.volgorde).max() ?? 0) + 1
    }
}
