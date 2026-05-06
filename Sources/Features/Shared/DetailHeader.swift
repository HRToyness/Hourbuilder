import SwiftUI
import Models
import Styling

public struct DetailHeader: View {
    public struct Summary: Sendable {
        public let project: Project
        public let activiteitenCount: Int
        public let personenCount: Int
        public let fasesCount: Int

        public init(
            project: Project,
            activiteitenCount: Int,
            personenCount: Int,
            fasesCount: Int
        ) {
            self.project = project
            self.activiteitenCount = activiteitenCount
            self.personenCount = personenCount
            self.fasesCount = fasesCount
        }
    }

    private let summary: Summary

    public init(summary: Summary) {
        self.summary = summary
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Projecten · \(summary.project.klantNaam)")
                .font(.appMeta(11))
                .foregroundStyle(Color.appTextSecondary)

            HStack(alignment: .center, spacing: 8) {
                Text(summary.project.naam)
                    .font(.appTitle(22))
                    .foregroundStyle(Color.appTextPrimary)
                AppStatusBadge(
                    label: summary.project.status.label,
                    tone: StatusBridge.badgeTone(for: summary.project.status)
                )
                if let factuur = summary.project.factuurNummer, !factuur.isEmpty {
                    AppStatusBadge(label: factuur, tone: .neutral)
                }
            }

            HStack(spacing: 14) {
                kpi(numberOf(weken), "weken")
                divider
                kpi(summary.activiteitenCount, "activiteiten")
                divider
                kpi(summary.personenCount, "personen")
                if summary.fasesCount > 0 {
                    divider
                    kpi(summary.fasesCount, "fases")
                }
                divider
                Text(periodLabel)
                    .font(.appMeta(11))
                    .foregroundStyle(Color.appTextSecondary)
            }
            .padding(.top, 4)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.appSurface)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.appBorder)
                .frame(height: 0.5)
        }
    }

    private func kpi(_ count: Int, _ label: String) -> some View {
        HStack(spacing: 4) {
            Text("\(count)")
                .font(.appNumberSmall(13))
                .fontWeight(.bold)
                .foregroundStyle(Color.appTextPrimary)
            Text(label)
                .font(.appMeta(11))
                .foregroundStyle(Color.appTextSecondary)
        }
    }

    private var divider: some View {
        Text("·").foregroundStyle(Color.appTextTertiary)
    }

    private var weken: Int {
        let start = summary.project.startDatum
        let end = summary.project.eindDatum ?? Date()
        let interval = end.timeIntervalSince(start)
        return max(1, Int(ceil(interval / (7 * 24 * 3600))))
    }

    private func numberOf(_ value: Int) -> Int { value }

    private var periodLabel: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "nl_NL")
        f.dateFormat = "d MMM yyyy"
        let start = f.string(from: summary.project.startDatum)
        if let eind = summary.project.eindDatum {
            return "\(start) → \(f.string(from: eind))"
        }
        return "vanaf \(start)"
    }
}
