import Foundation

/// Eén kolom in de matrix view: een ISO-kalender week.
public struct WeekBucket: Hashable, Identifiable, Sendable {
    public let yearForWeekOfYear: Int
    public let weekOfYear: Int
    public let startDate: Date

    public var id: String { "\(yearForWeekOfYear)-W\(weekOfYear)" }

    public var label: String { "W\(weekOfYear)" }

    public var fullLabel: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "nl_NL")
        formatter.dateFormat = "d MMM"
        return "W\(weekOfYear) (\(formatter.string(from: startDate)))"
    }
}

public enum WeekBucketing {
    /// Genereert ISO-weekbuckets tussen `start` en `end` (inclusief).
    public static func weeks(from start: Date, to end: Date) -> [WeekBucket] {
        guard end >= start else { return [] }
        var calendar = Calendar(identifier: .iso8601)
        calendar.firstWeekday = 2 // maandag
        calendar.minimumDaysInFirstWeek = 4

        let startWeekStart = calendar.dateInterval(of: .weekOfYear, for: start)?.start ?? start
        let endWeekStart = calendar.dateInterval(of: .weekOfYear, for: end)?.start ?? end

        var buckets: [WeekBucket] = []
        var cursor = startWeekStart
        while cursor <= endWeekStart {
            let comps = calendar.dateComponents(
                [.yearForWeekOfYear, .weekOfYear],
                from: cursor
            )
            if let yfwy = comps.yearForWeekOfYear, let woy = comps.weekOfYear {
                buckets.append(
                    WeekBucket(
                        yearForWeekOfYear: yfwy,
                        weekOfYear: woy,
                        startDate: cursor
                    )
                )
            }
            guard let next = calendar.date(byAdding: .weekOfYear, value: 1, to: cursor) else {
                break
            }
            cursor = next
        }
        return buckets
    }

    /// Plaatst een datum in zijn ISO-week.
    public static func bucket(for date: Date) -> (year: Int, week: Int) {
        var calendar = Calendar(identifier: .iso8601)
        calendar.firstWeekday = 2
        calendar.minimumDaysInFirstWeek = 4
        let comps = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return (comps.yearForWeekOfYear ?? 0, comps.weekOfYear ?? 0)
    }
}
