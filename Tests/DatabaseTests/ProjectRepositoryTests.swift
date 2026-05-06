import XCTest
import Foundation
@testable import Database
@testable import Models

final class ProjectRepositoryTests: XCTestCase {
    private var appDb: AppDatabase!
    private var repo: ProjectRepository!

    override func setUp() async throws {
        appDb = try AppDatabase.makeInMemory()
        repo = ProjectRepository(writer: appDb.dbWriter)
    }

    func testInsertAndFetchAll() async throws {
        let project = Project(
            naam: "Site Acme",
            klantNaam: "Acme",
            startDatum: Date()
        )
        _ = try await repo.save(project)

        let all = try await repo.fetchAll()
        XCTAssertEqual(all.count, 1)
        XCTAssertEqual(all.first?.id, project.id)
        XCTAssertEqual(all.first?.naam, "Site Acme")
    }

    func testFetchById() async throws {
        let project = Project(naam: "X", klantNaam: "Y", startDatum: Date())
        _ = try await repo.save(project)

        let fetched = try await repo.fetch(id: project.id)
        XCTAssertEqual(fetched?.id, project.id)
    }

    func testUpdate() async throws {
        var project = Project(naam: "Origineel", klantNaam: "Acme", startDatum: Date())
        _ = try await repo.save(project)

        project.naam = "Aangepast"
        project.status = .afgerond
        _ = try await repo.save(project)

        let fetched = try await repo.fetch(id: project.id)
        XCTAssertEqual(fetched?.naam, "Aangepast")
        XCTAssertEqual(fetched?.status, .afgerond)
    }

    func testDelete() async throws {
        let project = Project(naam: "X", klantNaam: "Y", startDatum: Date())
        _ = try await repo.save(project)

        try await repo.delete(id: project.id)
        let all = try await repo.fetchAll()
        XCTAssertTrue(all.isEmpty)
    }
}
