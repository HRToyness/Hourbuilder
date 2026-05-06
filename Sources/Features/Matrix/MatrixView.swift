import SwiftUI
import Database
import Models
import Styling

public struct MatrixView: View {
    @Bindable var viewModel: MatrixViewModel

    @State private var selectedCell: MatrixViewModel.CellKey?

    public init(viewModel: MatrixViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(spacing: 0) {
            filterBar
            matrixGrid
            totalsRow
        }
        .background(Color.appBackground)
        .task { await viewModel.load() }
    }

    // MARK: - Filter chips

    private var filterBar: some View {
        HStack(spacing: 6) {
            FilterChip(
                label: "Alle groepen",
                isActive: viewModel.filterPersoonGroep == nil
            ) { viewModel.filterPersoonGroep = nil }

            ForEach(PersoonGroep.allCases) { groep in
                FilterChip(
                    label: groep.label,
                    isActive: viewModel.filterPersoonGroep == groep,
                    dot: dotColor(for: groep)
                ) { viewModel.filterPersoonGroep = groep }
            }

            divider

            Menu {
                Button("Alle bronnen") { viewModel.filterBron = nil }
                ForEach(ActiviteitBron.allCases) { bron in
                    Button(bron.label) { viewModel.filterBron = bron }
                }
            } label: {
                FilterChip(
                    label: viewModel.filterBron.map { "Bron: \($0.label)" } ?? "Bron: alles",
                    isActive: viewModel.filterBron != nil
                ) {}
            }
            .menuStyle(.borderlessButton)
            .fixedSize()

            if !viewModel.fases.isEmpty {
                Menu {
                    Button("Alle fases") { viewModel.filterFaseId = nil }
                    ForEach(viewModel.fases) { fase in
                        Button(fase.naam) { viewModel.filterFaseId = fase.id }
                    }
                } label: {
                    FilterChip(
                        label: viewModel.filterFaseId
                            .flatMap { id in viewModel.fases.first(where: { $0.id == id })?.naam }
                            .map { "Fase: \($0)" } ?? "Fase: alle",
                        isActive: viewModel.filterFaseId != nil
                    ) {}
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
            }

            Spacer()

            Text(filterStatusText)
                .font(.appMeta(11))
                .foregroundStyle(Color.appTextSecondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.appBackground)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.appBorder).frame(height: 0.5)
        }
    }

    // MARK: - Grid

    private var matrixGrid: some View {
        ScrollView([.horizontal, .vertical]) {
            Grid(alignment: .center, horizontalSpacing: 0, verticalSpacing: 0) {
                headerRow
                ForEach(viewModel.personen) { persoon in
                    GridRow {
                        personCell(persoon)
                        ForEach(viewModel.weken) { week in
                            cellView(persoon: persoon, week: week)
                        }
                    }
                }
            }
        }
        .background(Color.appSurface)
        .frame(maxHeight: .infinity)
        .popover(item: bindingForSelectedCell) { state in
            cellPopover(state: state)
        }
    }

    private var headerRow: some View {
        GridRow {
            Text("Persoon")
                .font(.appLabel(10))
                .tracking(0.5)
                .textCase(.uppercase)
                .foregroundStyle(Color.appTextSecondary)
                .frame(minWidth: 200, minHeight: 32, alignment: .leading)
                .padding(.horizontal, 12)
                .background(Color.appSidebar)
                .overlay(alignment: .bottom) {
                    Rectangle().fill(Color.appBorder).frame(height: 0.5)
                }
            ForEach(viewModel.weken) { week in
                Text(week.label)
                    .font(.appLabel(10))
                    .tracking(0.5)
                    .textCase(.uppercase)
                    .foregroundStyle(Color.appTextSecondary)
                    .frame(minWidth: 56, minHeight: 32)
                    .background(Color.appSidebar)
                    .overlay(alignment: .bottom) {
                        Rectangle().fill(Color.appBorder).frame(height: 0.5)
                    }
            }
        }
    }

    private func personCell(_ persoon: Persoon) -> some View {
        HStack(spacing: 8) {
            AvatarBadge(name: persoon.naam, size: 24)
            VStack(alignment: .leading, spacing: 1) {
                Text(persoon.naam)
                    .font(.appH2(12))
                    .foregroundStyle(Color.appTextPrimary)
                    .lineLimit(1)
                Text("\(persoon.type.label) · \(persoon.rol)")
                    .font(.appMeta(10))
                    .foregroundStyle(Color.appTextSecondary)
                    .lineLimit(1)
            }
        }
        .frame(minWidth: 200, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.appSurface)
        .overlay(alignment: .trailing) {
            Rectangle().fill(Color.appBorder).frame(width: 0.5)
        }
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.appBorder).frame(height: 0.5)
        }
    }

    private func cellView(persoon: Persoon, week: WeekBucket) -> some View {
        let state = viewModel.cellVariant(persoonId: persoon.id, weekId: week.id)
        let key = MatrixViewModel.CellKey(persoonId: persoon.id, weekId: week.id)
        let variant = StatusBridge.cellVariant(for: state.activiteiten)
        let isSelected = selectedCell == key

        return HeatMapCell(
            uren: state.uren,
            variant: variant,
            isSelected: isSelected
        )
        .frame(minWidth: 56)
        .contentShape(Rectangle())
        .onTapGesture {
            selectedCell = state.activiteiten.isEmpty ? nil : key
        }
    }

    // MARK: - Totals

    private var totalsRow: some View {
        HStack(alignment: .top, spacing: 32) {
            ForEach(PersoonGroep.allCases) { groep in
                totalKPI(groep: groep)
            }
            Spacer()
            statusBreakdown
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
        .background(Color.appSidebar)
        .overlay(alignment: .top) {
            Rectangle().fill(Color.appBorder).frame(height: 0.5)
        }
    }

    private func totalKPI(groep: PersoonGroep) -> some View {
        let totaal = viewModel.totals.perGroep[groep] ?? 0
        let doel: Double? = {
            switch groep {
            case .klant: return viewModel.totals.doelKlant
            case .intern: return viewModel.totals.doelIntern
            case .leverancier: return nil
            }
        }()
        let afwijking: Double? = doel.map { totaal - $0 }

        return KPIRow(
            label: groep.label,
            value: formatHours(totaal),
            valueSuffix: doel.map { "/\(formatHours($0))" }
        ) {
            if let doel, doel > 0 {
                ProgressBar(
                    value: totaal / doel,
                    fill: (afwijking ?? 0) > 0 ? Color.pillWarningFg : Color.pillSuccessFg,
                    track: Color.appBorder,
                    height: 3
                )
                .frame(width: 80)
            }
            if let afwijking, doel != nil {
                let sentiment: DeltaLabel.Sentiment = abs(afwijking) < 0.5
                    ? .positive
                    : (afwijking > 0 ? .negative : .neutral)
                let text: String = {
                    if afwijking > 0.5 { return "\(formatHours(afwijking)) over" }
                    if afwijking < -0.5 { return "\(formatHours(-afwijking)) te gaan" }
                    return "op koers"
                }()
                DeltaLabel(text, sentiment: sentiment)
            } else {
                Text("geen doel")
                    .font(.appLabel(11))
                    .foregroundStyle(Color.appTextTertiary)
            }
        }
    }

    private var statusBreakdown: some View {
        VStack(alignment: .trailing, spacing: 3) {
            Text("Status")
                .font(.appLabel(10))
                .tracking(0.5)
                .foregroundStyle(Color.appTextSecondary)
            HStack(spacing: 6) {
                AppStatusBadge(label: "\(countOfStatus(.bevestigd)) bevestigd", tone: .success)
                AppStatusBadge(label: "\(countOfStatus(.concept)) concept", tone: .warning)
                if countOfBron(.aiVoorstel) > 0 {
                    AppStatusBadge(label: "\(countOfBron(.aiVoorstel)) AI", tone: .ai)
                }
            }
        }
    }

    private func countOfStatus(_ status: ActiviteitStatus) -> Int {
        viewModel.cellen.values.flatMap { $0 }.filter { $0.status == status }.count
    }

    private func countOfBron(_ bron: ActiviteitBron) -> Int {
        viewModel.cellen.values.flatMap { $0 }.filter { $0.bron == bron }.count
    }

    // MARK: - Helpers

    private var filterStatusText: String {
        let totaal = viewModel.cellen.values.reduce(0) { $0 + $1.count }
        return "\(totaal) activiteiten"
    }

    private func dotColor(for groep: PersoonGroep) -> Color {
        switch groep {
        case .klant: return .pillKlantFg
        case .intern: return .pillInternFg
        case .leverancier: return .pillLeverancierFg
        }
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.appBorder)
            .frame(width: 1, height: 16)
            .padding(.horizontal, 4)
    }

    // MARK: - Popover

    private var bindingForSelectedCell: Binding<MatrixCellPopoverState?> {
        Binding(
            get: {
                guard let key = selectedCell else { return nil }
                let state = viewModel.cellVariant(persoonId: key.persoonId, weekId: key.weekId)
                guard !state.activiteiten.isEmpty else { return nil }
                let persoonNaam = viewModel.personen
                    .first(where: { $0.id == key.persoonId })?
                    .naam ?? "Onbekend"
                let weekLabel = viewModel.weken
                    .first(where: { $0.id == key.weekId })?
                    .fullLabel ?? key.weekId
                return MatrixCellPopoverState(
                    persoonNaam: persoonNaam,
                    weekLabel: weekLabel,
                    activiteiten: state.activiteiten
                )
            },
            set: { newValue in
                if newValue == nil { selectedCell = nil }
            }
        )
    }

    private func cellPopover(state: MatrixCellPopoverState) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                AvatarBadge(name: state.persoonNaam, size: 22)
                VStack(alignment: .leading, spacing: 1) {
                    Text(state.persoonNaam)
                        .font(.appH2(13))
                    Text(state.weekLabel)
                        .font(.appMeta(11))
                        .foregroundStyle(Color.appTextSecondary)
                }
            }
            Divider()
            ForEach(state.activiteiten) { activiteit in
                HStack(alignment: .top, spacing: 10) {
                    Text(formatDate(activiteit.datum))
                        .font(.appMono(11))
                        .foregroundStyle(Color.appTextSecondary)
                        .frame(width: 56, alignment: .leading)
                    Text(formatHours(activiteit.uren))
                        .font(.appMono(11))
                        .frame(width: 32, alignment: .trailing)
                    Text(activiteit.beschrijving.isEmpty ? "—" : activiteit.beschrijving)
                        .font(.appBody(12))
                        .lineLimit(2)
                    Spacer()
                    AppStatusBadge(
                        label: activiteit.status.label,
                        tone: StatusBridge.badgeTone(for: activiteit.status)
                    )
                }
            }
        }
        .padding(14)
        .frame(minWidth: 380, maxWidth: 520)
    }

    private func formatHours(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 1
        formatter.decimalSeparator = ","
        return formatter.string(from: value as NSNumber) ?? "\(value)"
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "nl_NL")
        formatter.dateFormat = "d MMM"
        return formatter.string(from: date)
    }
}

private struct MatrixCellPopoverState: Identifiable {
    let id = UUID()
    let persoonNaam: String
    let weekLabel: String
    let activiteiten: [Activiteit]
}
