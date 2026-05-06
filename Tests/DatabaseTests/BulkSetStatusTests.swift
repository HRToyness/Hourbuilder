import XCTest
import Foundation
@testable import Database
@testable import Models

final class BulkSetStatusTests: XCTestCase {
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

    func testBulkSetStatusUpdatesOnlySelected() async throws {
        let project = Project(naam: "P", klantNaam: "K", startDatum: Date())
        _ = try await projectRepo.save(project)
        let alice = Persoon(naam: "Alice", rol: "PM", type: .intern)
        _ = try await persoonRepo.save(alice)

        let a = Activiteit(projectId: project.id, persoonId: alice.id, datum: Date(), uren: 1, bron: .agenda, bronReferentie: "a", status: .concept)
        let b = Activiteit(projectId: project.id, persoonId: alice.id, datum: Date(), uren: 2, bron: .agenda, bronReferentie: "b", status: .concept)
        let c = Activiteit(projectId: project.id, persoonId: alice.id, datum: Date(), uren: 3, bron: .agenda, bronReferentie: "c", status: .concept)
        _ = try await activiteitRepo.save(a)
        _ = try await activiteitRepo.save(b)
        _ = try await activiteitRepo.save(c)

        let updated = try await activiteitRepo.bulkSetStatus(.bevestigd, ids: [a.id, c.id])
        XCTAssertEqual(updated, 2)

        let all = try await activiteitRepo.fetch(projectId: project.id)
        let byId = Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })
        XCTAssertEqual(byId[a.id]?.status, .bevestigd)
        XCTAssertEqual(byId[b.id]?.status, .concept)
        XCTAssertEqual(byId[c.id]?.status, .bevestigd)
    }

    func testBulkSetStatusEmptyIdSetReturnsZero() async throws {
        let count = try await activiteitRepo.bulkSetStatus(.afgewezen, ids: [])
        XCTAssertEqual(count, 0)
    }

    func testBulkSetStatusFlowingThroughTotals() async throws {
        let project = Project(
            naam: "P", klantNaam: "K", startDatum: Date(),
            doelTotaalKlantUren: nil, doelTotaalInternUren: 100
        )
        _ = try await projectRepo.save(project)
        let alice = Persoon(naam: "Alice", rol: "PM", type: .intern)
        _ = try await persoonRepo.save(alice)

        let act = Activiteit(
            projectId: project.id, persoonId: alice.id, datum: Date(),
            uren: 8, bron: .agenda, bronReferentie: "evt-1", status: .concept
        )
        _ = try await activiteitRepo.save(act)

        // Concept telt nog niet mee
        var totalen = try await projectRepo.uurTotalenPerGroep(projectId: project.id)
        XCTAssertNil(totalen[.intern])

        // Bulk-bevestig → telt wel mee
        _ = try await activiteitRepo.bulkSetStatus(.bevestigd, ids: [act.id])
        totalen = try await projectRepo.uurTotalenPerGroep(projectId: project.id)
        XCTAssertEqual(totalen[.intern] ?? 0, 8, accuracy: 0.001)
    }
}
