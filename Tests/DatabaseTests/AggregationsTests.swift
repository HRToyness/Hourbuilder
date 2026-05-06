import XCTest
import Foundation
@testable import Database
@testable import Models

final class AggregationsTests: XCTestCase {
    private var appDb: AppDatabase!
    private var projectRepo: ProjectRepository!
    private var persoonRepo: PersoonRepository!
    private var faseRepo: FaseRepository!
    private var activiteitRepo: ActiviteitRepository!

    override func setUp() async throws {
        appDb = try AppDatabase.makeInMemory()
        projectRepo = ProjectRepository(writer: appDb.dbWriter)
        persoonRepo = PersoonRepository(writer: appDb.dbWriter)
        faseRepo = FaseRepository(writer: appDb.dbWriter)
        activiteitRepo = ActiviteitRepository(writer: appDb.dbWriter)
    }

    private func makeBaseFixture() async throws -> (Project, Persoon, Persoon) {
        let project = Project(naam: "P", klantNaam: "K", startDatum: Date())
        _ = try await projectRepo.save(project)
        let alice = Persoon(naam: "Alice", rol: "PM", type: .intern)
        let bob = Persoon(naam: "Bob", rol: "PM", type: .klant)
        _ = try await persoonRepo.save(alice)
        _ = try await persoonRepo.save(bob)
        return (project, alice, bob)
    }

    private func date(_ ymd: String) -> Date {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(identifier: "UTC")
        return f.date(from: ymd)!
    }

    // MARK: - urenPerWeek

    func testUrenPerWeekGroupedByGroep() async throws {
        let (project, alice, bob) = try await makeBaseFixture()
        // Week 19/2026: 5 mei is een dinsdag, ISO-week 19
        _ = try await activiteitRepo.save(Activiteit(
            projectId: project.id, persoonId: alice.id,
            datum: date("2026-05-05"), uren: 4,
            bron: .handmatig, status: .bevestigd
        ))
        _ = try await activiteitRepo.save(Activiteit(
            projectId: project.id, persoonId: bob.id,
            datum: date("2026-05-06"), uren: 2,
            bron: .handmatig, status: .bevestigd
        ))
        // Week 20: 12 mei
        _ = try await activiteitRepo.save(Activiteit(
            projectId: project.id, persoonId: alice.id,
            datum: date("2026-05-12"), uren: 8,
            bron: .handmatig, status: .bevestigd
        ))

        let result = try await activiteitRepo.urenPerWeek(projectId: project.id)
        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result[0].perGroep[.intern] ?? 0, 4, accuracy: 0.001)
        XCTAssertEqual(result[0].perGroep[.klant] ?? 0, 2, accuracy: 0.001)
        XCTAssertEqual(result[1].perGroep[.intern] ?? 0, 8, accuracy: 0.001)
    }

    func testUrenPerWeekIgnoresConcept() async throws {
        let (project, alice, _) = try await makeBaseFixture()
        _ = try await activiteitRepo.save(Activiteit(
            projectId: project.id, persoonId: alice.id,
            datum: date("2026-05-05"), uren: 99,
            bron: .handmatig, status: .concept
        ))
        let result = try await activiteitRepo.urenPerWeek(projectId: project.id)
        XCTAssertTrue(result.isEmpty)
    }

    // MARK: - urenPerFase

    func testUrenPerFaseIncludesGeenFaseBucket() async throws {
        let (project, alice, _) = try await makeBaseFixture()
        let fase1 = Fase(projectId: project.id, naam: "Discovery", volgorde: 1)
        _ = try await faseRepo.save(fase1)

        _ = try await activiteitRepo.save(Activiteit(
            projectId: project.id, faseId: fase1.id,
            persoonId: alice.id, datum: Date(), uren: 5,
            bron: .handmatig, status: .bevestigd
        ))
        _ = try await activiteitRepo.save(Activiteit(
            projectId: project.id, faseId: nil,
            persoonId: alice.id, datum: Date(), uren: 3,
            bron: .handmatig, status: .bevestigd
        ))

        let result = try await activiteitRepo.urenPerFase(projectId: project.id)
        XCTAssertEqual(result.count, 2)
        let discovery = result.first(where: { $0.naam == "Discovery" })
        let geen = result.first(where: { $0.faseId == nil })
        XCTAssertEqual(discovery?.totaal, 5)
        XCTAssertEqual(geen?.totaal, 3)
    }

    // MARK: - urenPerPersoon

    func testUrenPerPersoonSortedDescending() async throws {
        let (project, alice, bob) = try await makeBaseFixture()
        _ = try await activiteitRepo.save(Activiteit(
            projectId: project.id, persoonId: alice.id,
            datum: Date(), uren: 3,
            bron: .handmatig, status: .bevestigd
        ))
        _ = try await activiteitRepo.save(Activiteit(
            projectId: project.id, persoonId: bob.id,
            datum: Date(), uren: 10,
            bron: .handmatig, status: .bevestigd
        ))
        let result = try await activiteitRepo.urenPerPersoon(projectId: project.id)
        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result[0].persoon.id, bob.id)
        XCTAssertEqual(result[0].totaal, 10)
        XCTAssertEqual(result[1].persoon.id, alice.id)
    }
}

final class PortfolioSummaryTests: XCTestCase {
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

    func testEmptyDatabaseReturnsZeros() async throws {
        let summary = try await projectRepo.fetchPortfolioSummary()
        XCTAssertEqual(summary.lopendeProjecten, 0)
        XCTAssertEqual(summary.urenDezeMaand, 0)
        XCTAssertTrue(summary.perProject.isEmpty)
        XCTAssertTrue(summary.recenteActiviteiten.isEmpty)
    }

    func testCountsLopendeProjectenAndOverDoel() async throws {
        let lopend = Project(naam: "L", klantNaam: "K", startDatum: Date(), status: .lopend, doelTotaalInternUren: 10)
        _ = try await projectRepo.save(lopend)
        let afgerond = Project(naam: "A", klantNaam: "K", startDatum: Date(), status: .afgerond)
        _ = try await projectRepo.save(afgerond)

        let alice = Persoon(naam: "Alice", rol: "PM", type: .intern)
        _ = try await persoonRepo.save(alice)
        // Over doel: 15u > 10u doel
        _ = try await activiteitRepo.save(Activiteit(
            projectId: lopend.id, persoonId: alice.id,
            datum: Date(), uren: 15,
            bron: .handmatig, status: .bevestigd
        ))

        let summary = try await projectRepo.fetchPortfolioSummary()
        XCTAssertEqual(summary.lopendeProjecten, 1)
        XCTAssertEqual(summary.projectenOverDoel, 1)
        XCTAssertEqual(summary.perProject.count, 1)
        XCTAssertEqual(summary.perProject[0].weeklySparkline.count, 8)
    }

    func testRecenteActiviteitenMaxFive() async throws {
        let project = Project(naam: "P", klantNaam: "K", startDatum: Date())
        _ = try await projectRepo.save(project)
        let alice = Persoon(naam: "Alice", rol: "PM", type: .intern)
        _ = try await persoonRepo.save(alice)

        for i in 0..<8 {
            let datum = Date(timeIntervalSince1970: 1_700_000_000 + Double(i) * 86400)
            _ = try await activiteitRepo.save(Activiteit(
                projectId: project.id, persoonId: alice.id,
                datum: datum, uren: 1,
                bron: .handmatig, status: .bevestigd
            ))
        }

        let summary = try await projectRepo.fetchPortfolioSummary()
        XCTAssertEqual(summary.recenteActiviteiten.count, 5)
    }
}

final class ForecastCalculatorTests: XCTestCase {
    private func date(_ ymd: String) -> Date {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(identifier: "UTC")
        return f.date(from: ymd)!
    }

    func testNilWhenDoelIsZero() {
        let result = ForecastCalculator.forecast(
            currentUren: 50,
            projectStart: date("2026-01-01"),
            projectEnd: date("2026-04-01"),
            now: date("2026-02-01"),
            doelUren: 0
        )
        XCTAssertNil(result)
    }

    func testNilWhenProjectAlreadyEnded() {
        let result = ForecastCalculator.forecast(
            currentUren: 100,
            projectStart: date("2026-01-01"),
            projectEnd: date("2026-04-01"),
            now: date("2026-05-01"),
            doelUren: 100
        )
        XCTAssertNil(result)
    }

    func testNilWhenLessThanOneWeekElapsed() {
        let result = ForecastCalculator.forecast(
            currentUren: 5,
            projectStart: date("2026-01-01"),
            projectEnd: date("2026-04-01"),
            now: date("2026-01-03"),
            doelUren: 100
        )
        XCTAssertNil(result)
    }

    func testOnTrackWhenLineairLandt() {
        // 13 weken project, 4 weken voorbij, 30u huidig → ETA = 30/4 * 13 = 97.5
        // Doel 100 → on track (97.5 / 100 = 0.975, binnen ±5%)
        let result = ForecastCalculator.forecast(
            currentUren: 30,
            projectStart: date("2026-01-01"),
            projectEnd: date("2026-04-02"),  // 13 weken later
            now: date("2026-01-29"),  // 4 weken later
            doelUren: 100
        )
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.sentiment, .onTrack)
        XCTAssertEqual(result?.etaUren ?? 0, 97.5, accuracy: 0.5)
    }

    func testBehindWhenSlowTempo() {
        // 13 weken, 4 voorbij, 10u → ETA = 32.5 (32.5% van doel 100)
        let result = ForecastCalculator.forecast(
            currentUren: 10,
            projectStart: date("2026-01-01"),
            projectEnd: date("2026-04-02"),
            now: date("2026-01-29"),
            doelUren: 100
        )
        XCTAssertEqual(result?.sentiment, .behind)
    }

    func testOverWhenSnelTempo() {
        // 13 weken, 4 voorbij, 60u → ETA = 195 (195% van doel 100)
        let result = ForecastCalculator.forecast(
            currentUren: 60,
            projectStart: date("2026-01-01"),
            projectEnd: date("2026-04-02"),
            now: date("2026-01-29"),
            doelUren: 100
        )
        XCTAssertEqual(result?.sentiment, .over)
    }
}
