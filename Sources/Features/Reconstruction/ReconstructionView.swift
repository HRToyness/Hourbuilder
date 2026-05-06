import SwiftUI
import Database
import Models
import Services
import Styling

public struct ReconstructionView: View {
    @Bindable var viewModel: ReconstructionViewModel
    let onApproved: () -> Void
    let openSettings: () -> Void

    public init(
        viewModel: ReconstructionViewModel,
        onApproved: @escaping () -> Void,
        openSettings: @escaping () -> Void
    ) {
        self.viewModel = viewModel
        self.onApproved = onApproved
        self.openSettings = openSettings
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    AppSectionHeader(
                        title: "Reconstructie",
                        subtitle: "Bekend versus doel en AI-voorstellen om gaten op te vullen."
                    )
                    Spacer()
                    statusBlock
                }
                gapsSection
                Divider().background(Color.appBorder)
                suggestionsSection

                if let err = viewModel.lastErrorMessage {
                    Text(err)
                        .font(.appBody())
                        .foregroundStyle(Color.pillWarningFg)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 18)
        }
        .background(Color.appBackground)
        .task { await viewModel.load() }
    }

    private var statusBlock: some View {
        HStack(spacing: 10) {
            if viewModel.hasAPIKey {
                AppStatusBadge(label: "\(viewModel.activeProvider.shortLabel) ✓", tone: .success)
            } else {
                AppStatusBadge(label: "Geen \(viewModel.activeProvider.shortLabel) sleutel", tone: .warning)
                AppSecondaryButton(title: "Instellen…") { openSettings() }
            }
            AppPrimaryButton(
                title: viewModel.isCallingAI ? "AI denkt…" : "Vul gaten in",
                isDisabled: !viewModel.hasAPIKey || viewModel.isCallingAI
            ) {
                Task { await viewModel.generateSuggestions() }
            }
        }
    }

    private var gapsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Bekend versus doel")
                .font(.appH1(14))
                .foregroundStyle(Color.appTextPrimary)
            HStack(alignment: .top, spacing: 12) {
                ForEach(viewModel.gaps) { gap in
                    gapCard(gap)
                }
            }
        }
    }

    private func gapCard(_ gap: ReconstructionViewModel.GapInfo) -> some View {
        AppCard {
            KPIRow(
                label: gap.groep.label,
                value: formatHours(gap.bekend),
                valueSuffix: gap.doel.map { "/\(formatHours($0))" }
            ) {
                if let doel = gap.doel, doel > 0 {
                    ProgressBar(
                        value: gap.bekend / doel,
                        fill: (gap.verschil ?? 0) > 0 ? Color.pillSuccessFg : Color.pillWarningFg,
                        track: Color.appBorder,
                        height: 3
                    )
                    .frame(width: 110)
                }
                if let verschil = gap.verschil {
                    let text = verschil > 0.5
                        ? "\(formatHours(verschil)) tekort"
                        : (verschil < -0.5 ? "\(formatHours(-verschil)) over" : "op koers")
                    let sentiment: DeltaLabel.Sentiment = verschil > 0.5
                        ? .negative
                        : (verschil < -0.5 ? .positive : .positive)
                    DeltaLabel(text, sentiment: sentiment)
                } else {
                    Text("geen doel")
                        .font(.appLabel(11))
                        .foregroundStyle(Color.appTextTertiary)
                }
            }
        }
    }

    @ViewBuilder
    private var suggestionsSection: some View {
        if viewModel.pendingSuggestions.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Text("Geen voorstellen")
                    .font(.appH1(14))
                    .foregroundStyle(Color.appTextPrimary)
                Text("Klik op 'Vul gaten in' om Claude voor te stellen waar nog uren ontbreken.")
                    .font(.appBody())
                    .foregroundStyle(Color.appTextSecondary)
            }
        } else {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("AI voorstellen")
                        .font(.appH1(14))
                    CountBadge(count: viewModel.pendingSuggestions.count, tone: .ai)
                    Spacer()
                    AppSecondaryButton(title: "Alles afwijzen") {
                        viewModel.clearAllSuggestions()
                    }
                }
                let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(viewModel.pendingSuggestions) { pending in
                        suggestionCard(pending)
                    }
                }
            }
        }
    }

    private func suggestionCard(_ pending: ReconstructionViewModel.PendingSuggestion) -> some View {
        AppCard {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    AvatarBadge(name: pending.persoon.naam, size: 22)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(pending.persoon.naam)
                            .font(.appH2(12))
                        AppStatusBadge(
                            label: pending.persoon.type.label,
                            tone: StatusBridge.badgeTone(for: pending.persoon.type)
                        )
                    }
                    Spacer()
                    Text("✨")
                }

                HStack(spacing: 8) {
                    metaPill("Week \(pending.suggestion.week)")
                    metaPill("\(formatHours(pending.suggestion.uren))u")
                    metaPill(pending.suggestion.categorie)
                }

                Text(pending.suggestion.onderbouwing)
                    .font(.appBody(12))
                    .foregroundStyle(Color.appTextPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 8) {
                    Spacer()
                    AppSecondaryButton(title: "Afwijs") {
                        viewModel.reject(pending)
                    }
                    AppPrimaryButton(title: "Goedkeur") {
                        Task {
                            await viewModel.approve(pending)
                            onApproved()
                        }
                    }
                }
            }
        }
    }

    private func metaPill(_ text: String) -> some View {
        Text(text)
            .font(.appLabel(10))
            .foregroundStyle(Color.appTextSecondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.appSidebar)
            .clipShape(Capsule())
    }

    private func formatHours(_ value: Double) -> String {
        let f = NumberFormatter()
        f.minimumFractionDigits = 0
        f.maximumFractionDigits = 1
        f.decimalSeparator = ","
        return f.string(from: value as NSNumber) ?? "\(value)"
    }
}
