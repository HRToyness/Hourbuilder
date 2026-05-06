import XCTest
import Foundation
@testable import Database
@testable import Models

final class ProjectMemberRepositoryTests: XCTestCase {
    private var appDb: AppDatabase!
    private var projectRepo: ProjectRepository!
    private var persoonRepo: PersoonRepository!
    private var memberRepo: ProjectMemberRepository!

    override func setUp() async throws {
        appDb = try AppDatabase.makeInMemory()
        projectRepo = ProjectRepository(writer: appDb.dbWriter)
        persoonRepo = PersoonRepository(writer: appDb.dbWriter)
        memberRepo = ProjectMemberRepository(writer: appDb.dbWriter)
    }

    func testAddAndFetchMembers() async throws {
        let project = Project(naam: "P", klantNaam: "K", startDatum: Date())
        _ = try await projectRepo.save(project)
        let alice = Persoon(naam: "Alice", rol: "PM", type: .intern)
        let bob = Persoon(naam: "Bob", rol: "Dev", type: .klant)
        _ = try await persoonRepo.save(alice)
        _ = try await persoonRepo.save(bob)

        _ = try await memberRepo.add(projectId: project.id, persoonId: alice.id)
        _ = try await memberRepo.add(projectId: project.id, persoonId: bob.id)

        let personen = try await memberRepo.fetchPersonen(projectId: project.id)
        XCTAssertEqual(Set(personen.map(\.id)), Set([alice.id, bob.id]))
    }

    func testAddIsIdempotent() async throws {
        let project = Project(naam: "P", klantNaam: "K", startDatum: Date())
        _ = try await projectRepo.save(project)
        let alice = Persoon(naam: "Alice", rol: "PM", type: .intern)
        _ = try await persoonRepo.save(alice)

        _ = try await memberRepo.add(projectId: project.id, persoonId: alice.id)
        _ = try await memberRepo.add(projectId: project.id, persoonId: alice.id)

        let members = try await memberRepo.fetchMembers(projectId: project.id)
        XCTAssertEqual(members.count, 1)
    }

    func testRemoveByPersoon() async throws {
        let project = Project(naam: "P", klantNaam: "K", startDatum: Date())
        _ = try await projectRepo.save(project)
        let alice = Persoon(naam: "Alice", rol: "PM", type: .intern)
        _ = try await persoonRepo.save(alice)
        _ = try await memberRepo.add(projectId: project.id, persoonId: alice.id)

        try await memberRepo.remove(projectId: project.id, persoonId: alice.id)
        let members = try await memberRepo.fetchMembers(projectId: project.id)
        XCTAssertTrue(members.isEmpty)
    }

    func testCascadeDeleteOnProject() async throws {
        let project = Project(naam: "P", klantNaam: "K", startDatum: Date())
        _ = try await projectRepo.save(project)
        let alice = Persoon(naam: "Alice", rol: "PM", type: .intern)
        _ = try await persoonRepo.save(alice)
        _ = try await memberRepo.add(projectId: project.id, persoonId: alice.id)

        try await projectRepo.delete(id: project.id)

        // Geen members meer voor verwijderd project, maar persoon bestaat nog globaal
        let members = try await memberRepo.fetchMembers(projectId: project.id)
        XCTAssertTrue(members.isEmpty)
        let stillExists = try await persoonRepo.fetch(id: alice.id)
        XCTAssertNotNil(stillExists)
    }

    func testCascadeDeleteOnPersoon() async throws {
        let project = Project(naam: "P", klantNaam: "K", startDatum: Date())
        _ = try await projectRepo.save(project)
        let alice = Persoon(naam: "Alice", rol: "PM", type: .intern)
        _ = try await persoonRepo.save(alice)
        _ = try await memberRepo.add(projectId: project.id, persoonId: alice.id)

        try await persoonRepo.delete(id: alice.id)
        let members = try await memberRepo.fetchMembers(projectId: project.id)
        XCTAssertTrue(members.isEmpty)
    }
}
