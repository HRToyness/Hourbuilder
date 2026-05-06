import SwiftUI
import Charts
import Database
import Models
import Styling

public struct InsightsView: View {
    @Bindable var viewModel: InsightsViewModel

    public init(viewModel: InsightsViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                kpiStrip
                weekChartSection
                faseChartSection
                persoonChartSection
                if let err = viewModel.lastErrorMessage {
                    Text(err)
                        .font(.appBody(11))
                        .foregroundStyle(Color.pillWarningFg)
                }
            }
            .padding(20)
        }
        .background(Color.appBackground)
        .task { await viewModel.load() }
    }

    // MARK: - KPI strip

    private var kpiStrip: some View {
        HStack(spacing: 14) {
            kpiCard(
                label: "Bevestigd",
                value: "\(viewModel.bevestigdCount)",
                tone: .success
            )
            kpiCard(
                label: "Concept",
                value: "\(viewModel.conceptCount)",
                tone: .warning
            )
            if viewModel.aiCount > 0 {
                kpiCard(
                    label: "AI voorstel",
                    value: "\(viewModel.aiCount)",
                    tone: .ai
                )
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("BEVESTIGD TOTAAL")
                    .font(.appLabel(10))
                    .tracking(0.5)
                    .foregroundStyle(.secondary)
                Text("\(formatHours(viewModel.totaalUren))u")
                    .font(.appNumber(22))
            }
        }
    }

    private func kpiCard(label: String, value: String, tone: AppStatusBadge.Tone) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            AppStatusBadge(label: label, tone: tone)
            Text(value)
                .font(.appNumber(20))
        }
    }

    // MARK: - Week chart

    private var weekChartSection: some View {
        sectionCard(title: "Uren per week") {
            if viewModel.weekTotals.isEmpty {
                emptyChartHint("Nog geen bevestigde uren")
            } else {
                Chart {
                    ForEach(viewModel.weekTotals, id: \.yearWeek) { week in
                        ForEach(PersoonGroep.allCases) { groep in
                            LineMark(
                                x: .value("Week", week.weekStart, unit: .weekOfYear),
                                y: .value("Uren", week.perGroep[groep] ?? 0)
                            )
                            .foregroundStyle(by: .value("Groep", groep.label))
                            .symbol(by: .value("Groep", groep.label))
                            .interpolationMethod(.linear)
                        }
                    }
                }
                .chartForegroundStyleScale(groepColorMapping)
                .chartLegend(position: .bottom, alignment: .leading)
                .frame(height: 200)
            }
        }
    }

    // MARK: - Fase chart

    private var faseChartSection: some View {
        sectionCard(title: "Uren per fase") {
            if viewModel.faseTotals.isEmpty {
                emptyChartHint("Nog geen fase-gerelateerde uren")
            } else {
                Chart {
                    ForEach(viewModel.faseTotals, id: \.naam) { fase in
                        ForEach(PersoonGroep.allCases) { groep in
                            BarMark(
                                x: .value("Fase", fase.naam),
                                y: .value("Uren", fase.perGroep[groep] ?? 0)
                            )
                            .foregroundStyle(by: .value("Groep", groep.label))
                        }
                    }
                }
                .chartForegroundStyleScale(groepColorMapping)
                .chartLegend(position: .bottom, alignment: .leading)
                .frame(height: 200)
            }
        }
    }

    // MARK: - Persoon donut

    private var persoonChartSection: some View {
        sectionCard(title: "Verdeling per persoon") {
            if viewModel.donutPersonen.isEmpty {
                emptyChartHint("Nog geen uren ingevoerd")
            } else {
                HStack(alignment: .top, spacing: 20) {
                    Chart {
                        ForEach(viewModel.donutPersonen, id: \.persoon.id) { item in
                            SectorMark(
                                angle: .value("Uren", item.totaal),
                                innerRadius: .ratio(0.6),
                                angularInset: 1
                            )
                            .foregroundStyle(by: .value("Persoon", item.persoon.naam))
                            .cornerRadius(2)
                        }
                    }
                    .chartLegend(.hidden)
                    .frame(width: 200, height: 200)

                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(viewModel.donutPersonen, id: \.persoon.id) { item in
                            HStack(spacing: 8) {
                                AvatarBadge(name: item.persoon.naam, size: 18)
                                Text(item.persoon.naam)
                                    .font(.appBody(12))
                                Spacer()
                                Text("\(formatHours(item.totaal))u")
                                    .font(.appNumberSmall(11))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    // MARK: - Helpers

    private var groepColorMapping: KeyValuePairs<String, Color> {
        [
            PersoonGroep.intern.label: Color.pillInternFg,
            PersoonGroep.klant.label: Color.pillKlantFg,
            PersoonGroep.leverancier.label: Color.pillLeverancierFg,
        ]
    }

    private func sectionCard<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.appH1(14))
                .foregroundStyle(Color.appTextPrimary)
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.appSurface)
        .overlay(
            RoundedRectangle(cornerRadius: 6).stroke(Color.appBorder, lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private func emptyChartHint(_ text: String) -> some View {
        Text(text)
            .font(.appBody(11))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, minHeight: 120, alignment: .center)
    }

    private func formatHours(_ value: Double) -> String {
        let f = NumberFormatter()
        f.minimumFractionDigits = 0
        f.maximumFractionDigits = 1
        f.decimalSeparator = ","
        return f.string(from: value as NSNumber) ?? "\(value)"
    }
}
