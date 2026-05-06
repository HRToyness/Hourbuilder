import XCTest
import Foundation
@testable import Database
@testable import Models

final class InsertWithDedupTests: XCTestCase {
    private var appDb: AppDatabase!
    private var projectRepo: ProjectRepository!
    private var persoonRepo: PersoonRepository!
    private var activiteitRepo: ActiviteitRepository!

    override func setUp() async throws {
        appDb = try AppDatabase.makeInMemory()
        projectRepo = ProjectRepository(writer: appDb.dbWriter)
        persoonRepo = PersoonRepository(writer: appDb.dbWriter)
        activiteitRepo = ActiviteitRepository(writer: appDb.dbWriter)
    }

    func testInsertWithDedupSkipsExistingBronReferentie() async throws {
        let project = Project(naam: "P", klantNaam: "K", startDatum: Date())
        _ = try await projectRepo.save(project)
        let alice = Persoon(naam: "Alice", rol: "PM", type: .intern)
        _ = try await persoonRepo.save(alice)

        let act1 = Activiteit(
            projectId: project.id,
            persoonId: alice.id,
            datum: Date(),
            uren: 1,
            bron: .agenda,
            bronReferentie: "evt-A",
            status: .concept
        )
        let result1 = try await activiteitRepo.insertWithDedup([act1])
        XCTAssertEqual(result1.inserted, 1)
        XCTAssertEqual(result1.skipped, 0)

        // Re-import same bronReferentie + nieuwe Activiteit met andere referentie
        let act2 = Activiteit(
            projectId: project.id,
            persoonId: alice.id,
            datum: Date(),
            uren: 2,
            bron: .agenda,
            bronReferentie: "evt-A",
            status: .concept
        )
        let act3 = Activiteit(
            projectId: project.id,
            persoonId: alice.id,
            datum: Date(),
            uren: 3,
            bron: .agenda,
            bronReferentie: "evt-B",
            status: .concept
        )
        let result2 = try await activiteitRepo.insertWithDedup([act2, act3])
        XCTAssertEqual(result2.inserted, 1)
        XCTAssertEqual(result2.skipped, 1)

        let all = try await activiteitRepo.fetch(projectId: project.id)
        XCTAssertEqual(all.count, 2)
    }

    func testInsertWithDedupAcceptsRecordsWithoutBronReferentie() async throws {
        let project = Project(naam: "P", klantNaam: "K", startDatum: Date())
        _ = try await projectRepo.save(project)
        let alice = Persoon(naam: "Alice", rol: "PM", type: .intern)
        _ = try await persoonRepo.save(alice)

        let m1 = Activiteit(
            projectId: project.id,
            persoonId: alice.id,
            datum: Date(),
            uren: 4,
            bron: .handmatig,
            bronReferentie: nil,
            status: .bevestigd
        )
        let m2 = Activiteit(
            projectId: project.id,
            persoonId: alice.id,
            datum: Date(),
            uren: 5,
            bron: .handmatig,
            bronReferentie: nil,
            status: .bevestigd
        )
        let r1 = try await activiteitRepo.insertWithDedup([m1, m2])
        XCTAssertEqual(r1.inserted, 2)
        XCTAssertEqual(r1.skipped, 0)
    }

    func testInsertWithDedupScopesPerProject() async throws {
        let p1 = Project(naam: "P1", klantNaam: "K", startDatum: Date())
        let p2 = Project(naam: "P2", klantNaam: "K", startDatum: Date())
        _ = try await projectRepo.save(p1)
        _ = try await projectRepo.save(p2)
        let alice = Persoon(naam: "Alice", rol: "PM", type: .intern)
        _ = try await persoonRepo.save(alice)

        let act1 = Activiteit(
            projectId: p1.id,
            persoonId: alice.id,
            datum: Date(),
            uren: 1,
            bron: .agenda,
            bronReferentie: "shared-id",
            status: .concept
        )
        let act2 = Activiteit(
            projectId: p2.id,
            persoonId: alice.id,
            datum: Date(),
            uren: 1,
            bron: .agenda,
            bronReferentie: "shared-id",
            status: .concept
        )
        _ = try await activiteitRepo.insertWithDedup([act1])
        let r2 = try await activiteitRepo.insertWithDedup([act2])
        XCTAssertEqual(r2.inserted, 1, "Same bronReferentie in different project should not dedupe")
    }
}
