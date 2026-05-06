import Foundation

public enum ForecastCalculator {
    public struct Result: Sendable, Equatable {
        public let etaUren: Double
        public let etaDatum: Date
        public let sentiment: Sentiment

        public init(etaUren: Double, etaDatum: Date, sentiment: Sentiment) {
            self.etaUren = etaUren
            self.etaDatum = etaDatum
            self.sentiment = sentiment
        }
    }

    public enum Sentiment: Sendable, Equatable {
        case onTrack
        case behind
        case over
    }

    private static let secondsPerWeek: TimeInterval = 7 * 86400

    /// Lineaire extrapolatie: gegeven huidige uren, projectduur en `now`,
    /// bereken hoeveel uren we eindigen op `projectEnd` als het tempo gelijk
    /// blijft. Returnt `nil` als de berekening niet zinvol is (geen doel,
    /// project al voorbij, te kort onderweg).
    public static func forecast(
        currentUren: Double,
        projectStart: Date,
        projectEnd: Date,
        now: Date,
        doelUren: Double
    ) -> Result? {
        guard doelUren > 0 else { return nil }
        guard now < projectEnd else { return nil }

        let totaalWeken = projectEnd.timeIntervalSince(projectStart) / secondsPerWeek
        let verstreken = max(0, now.timeIntervalSince(projectStart) / secondsPerWeek)
        guard verstreken >= 1.0, totaalWeken > 0 else { return nil }

        let etaUren = currentUren / verstreken * totaalWeken

        let sentiment: Sentiment
        if etaUren > doelUren * 1.05 {
            sentiment = .over
        } else if etaUren < doelUren * 0.95 {
            sentiment = .behind
        } else {
            sentiment = .onTrack
        }

        return Result(etaUren: etaUren, etaDatum: projectEnd, sentiment: sentiment)
    }
}
