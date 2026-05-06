import SwiftUI
import Database
import Models
import Styling

public struct PortfolioView: View {
    @Bindable var viewModel: PortfolioViewModel
    let onProjectTap: (UUID) -> Void

    public init(viewModel: PortfolioViewModel, onProjectTap: @escaping (UUID) -> Void) {
        self.viewModel = viewModel
        self.onProjectTap = onProjectTap
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                AppSectionHeader(
                    title: "Overzicht",
                    subtitle: "Lopende projecten + activiteit deze maand"
                )
                kpiStrip
                projectGrid
                recentActivity
            }
            .padding(28)
        }
        .background(Color.appBackground)
        .task { viewModel.startObserving() }
    }

    // MARK: - KPI strip

    @ViewBuilder
    private var kpiStrip: some View {
        if let summary = viewModel.summary {
            HStack(spacing: 14) {
                kpiCard(
                    label: "Deze maand",
                    value: "\(formatHours(summary.urenDezeMaand))",
                    suffix: "u"
                )
                kpiCard(
                    label: "Lopende projecten",
                    value: "\(summary.lopendeProjecten)",
                    suffix: nil
                )
                kpiCard(
                    label: "Bevestigd totaal",
                    value: "\(formatHours(summary.totaalBevestigd))",
                    suffix: "u"
                )
                kpiCard(
                    label: "Over doel",
                    value: "\(summary.projectenOverDoel)",
                    suffix: nil,
                    sentiment: summary.projectenOverDoel > 0 ? .negative : .neutral
                )
            }
        } else {
            HStack(spacing: 14) {
                ForEach(0..<4, id: \.self) { _ in
                    kpiSkeleton
                }
            }
        }
    }

    private func kpiCard(
        label: String,
        value: String,
        suffix: String?,
        sentiment: DeltaLabel.Sentiment? = nil
    ) -> some View {
        AppCard {
            VStack(alignment: .leading, spacing: 6) {
                Text(label.uppercased())
                    .font(.appLabel(10))
                    .tracking(0.5)
                    .foregroundStyle(.secondary)
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(value)
                        .font(.appNumber(24))
                        .foregroundStyle(sentiment == .negative ? Color.pillWarningFg : Color.appTextPrimary)
                    if let suffix {
                        Text(suffix)
                            .font(.appNumberSmall(12))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var kpiSkeleton: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 6) {
                Rectangle().fill(Color.appBorder).frame(width: 60, height: 8)
                Rectangle().fill(Color.appBorder).frame(width: 80, height: 22)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Project grid

    @ViewBuilder
    private var projectGrid: some View {
        if let summary = viewModel.summary, !summary.perProject.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("Lopende projecten")
                    .font(.appLabel(11))
                    .foregroundStyle(.secondary)
                    .tracking(0.5)
                    .textCase(.uppercase)
                let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(summary.perProject, id: \.project.id) { metric in
                        Button { onProjectTap(metric.project.id) } label: {
                            projectCard(metric)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func projectCard(_ metric: PortfolioSummary.ProjectMetric) -> some View {
        AppCard {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(metric.project.naam)
                        .font(.appH2(13))
                        .foregroundStyle(Color.appTextPrimary)
                    Spacer()
                    AppStatusBadge(
                        label: metric.project.status.label,
                        tone: StatusBridge.badgeTone(for: metric.project.status)
                    )
                }
                Text(metric.project.klantNaam)
                    .font(.appMeta(11))
                    .foregroundStyle(.secondary)

                HStack(spacing: 6) {
                    metaUren(value: metric.internUren, doel: metric.project.doelTotaalInternUren, label: "intern")
                    if metric.project.doelTotaalKlantUren != nil || metric.klantUren > 0 {
                        Text("·").foregroundStyle(.tertiary)
                        metaUren(value: metric.klantUren, doel: metric.project.doelTotaalKlantUren, label: "klant")
                    }
                }

                if let doel = metric.project.doelTotaalInternUren, doel > 0 {
                    ProgressBar(
                        value: metric.internUren / doel,
                        fill: metric.internUren > doel ? Color.pillWarningFg : Color.appPrimary,
                        track: Color.appBorder.opacity(0.6),
                        height: 3
                    )
                }

                Sparkline(
                    values: metric.weeklySparkline,
                    lineColor: Color.appAccentDark,
                    fillColor: Color.pillSuccessBg
                )
                .frame(height: 22)
            }
        }
    }

    @ViewBuilder
    private func metaUren(value: Double, doel: Double?, label: String) -> some View {
        HStack(spacing: 2) {
            Text("\(formatHours(value))")
                .font(.appNumberSmall(11))
                .foregroundStyle(Color.appTextPrimary)
            if let doel {
                Text("/\(formatHours(doel)) \(label)")
                    .font(.appMeta(10.5))
                    .foregroundStyle(.secondary)
            } else {
                Text("u \(label)")
                    .font(.appMeta(10.5))
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Recent activity

    @ViewBuilder
    private var recentActivity: some View {
        if let summary = viewModel.summary, !summary.recenteActiviteiten.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Recente activiteit")
                    .font(.appLabel(11))
                    .foregroundStyle(.secondary)
                    .tracking(0.5)
                    .textCase(.uppercase)
                AppCard {
                    VStack(spacing: 8) {
                        ForEach(Array(summary.recenteActiviteiten.enumerated()), id: \.element.id) { idx, act in
                            recentActivityRow(act)
                            if idx < summary.recenteActiviteiten.count - 1 {
                                Divider()
                            }
                        }
                    }
                }
            }
        }
    }

    private func recentActivityRow(_ act: Activiteit) -> some View {
        HStack(spacing: 10) {
            Text(formatDate(act.datum))
                .font(.appMono(11))
                .foregroundStyle(.secondary)
                .frame(width: 70, alignment: .leading)
            Text(formatHours(act.uren) + "u")
                .font(.appNumberSmall(11))
                .foregroundStyle(Color.appTextPrimary)
                .frame(width: 36, alignment: .trailing)
            Text(act.beschrijving.isEmpty ? "—" : act.beschrijving)
                .font(.appBody(12))
                .lineLimit(1)
            Spacer()
            AppStatusBadge(
                label: act.status.label,
                tone: StatusBridge.badgeTone(for: act.status)
            )
        }
    }

    // MARK: - Helpers

    private func formatHours(_ value: Double) -> String {
        let f = NumberFormatter()
        f.minimumFractionDigits = 0
        f.maximumFractionDigits = 1
        f.decimalSeparator = ","
        return f.string(from: value as NSNumber) ?? "\(value)"
    }

    private func formatDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "nl_NL")
        f.dateFormat = "d MMM"
        return f.string(from: date)
    }
}
