import Foundation
import Observation
import Database
import Models

@Observable
@MainActor
public final class PersoonListViewModel {
    public private(set) var members: [Persoon] = []
    public private(set) var alleGlobal: [Persoon] = []
    public var lastErrorMessage: String?

    private let projectId: UUID
    private let persoonRepo: PersoonRepository
    private let memberRepo: ProjectMemberRepository

    public init(
        projectId: UUID,
        persoonRepo: PersoonRepository,
        memberRepo: ProjectMemberRepository
    ) {
        self.projectId = projectId
        self.persoonRepo = persoonRepo
        self.memberRepo = memberRepo
    }

    public func load() async {
        do {
            async let m = memberRepo.fetchPersonen(projectId: projectId)
            async let g = persoonRepo.fetchAll()
            let (loadedMembers, loadedGlobal) = try await (m, g)
            members = loadedMembers
            alleGlobal = loadedGlobal
        } catch {
            lastErrorMessage = "Personen laden mislukt: \(error.localizedDescription)"
        }
    }

    /// Personen die nog géén lid zijn van dit project — voor de "voeg
    /// bestaande toe" picker.
    public var nonMembers: [Persoon] {
        let memberIds = Set(members.map(\.id))
        return alleGlobal.filter { !memberIds.contains($0.id) }
    }

    public func addExistingMember(persoonId: UUID) async {
        do {
            _ = try await memberRepo.add(projectId: projectId, persoonId: persoonId)
            await load()
        } catch {
            lastErrorMessage = "Toevoegen mislukt: \(error.localizedDescription)"
        }
    }

    public func removeMember(persoonId: UUID) async {
        do {
            try await memberRepo.remove(projectId: projectId, persoonId: persoonId)
            await load()
        } catch {
            lastErrorMessage = "Verwijderen mislukt: \(error.localizedDescription)"
        }
    }
}
