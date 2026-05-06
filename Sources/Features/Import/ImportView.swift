import SwiftUI
import Database
import Models
import Services
import Styling

public struct ImportView: View {
    @Bindable var viewModel: ImportViewModel
    let onCompleted: () -> Void

    @Environment(\.dismiss) private var dismiss

    public init(viewModel: ImportViewModel, onCompleted: @escaping () -> Void) {
        self.viewModel = viewModel
        self.onCompleted = onCompleted
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            AppSectionHeader(
                title: "Importeer uit Apple Calendar",
                subtitle: "Events worden voorgesteld als concept-activiteiten."
            )

            switch viewModel.accessState {
            case .granted:
                grantedBody
            case .notDetermined:
                accessRequestPrompt
            case .denied, .writeOnly:
                deniedHelp
            case .restricted:
                Text("Toegang tot Agenda is geblokkeerd door beheerder.")
                    .font(.appBody())
                    .foregroundStyle(Color.appWarning)
            }

            if let err = viewModel.lastErrorMessage {
                Text(err)
                    .font(.appBody())
                    .foregroundStyle(Color.appWarning)
            }
        }
        .padding(20)
        .frame(minWidth: 720, minHeight: 600)
        .task { await viewModel.loadInitialData() }
    }

    // MARK: - Access prompts

    private var accessRequestPrompt: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("UrenReconstructie heeft toegang tot Agenda nodig om events te importeren.")
                .font(.appBody())
            AppPrimaryButton(title: "Toegang vragen") {
                Task { await viewModel.requestAccess() }
            }
        }
    }

    private var deniedHelp: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Toegang tot Agenda is geweigerd of beperkt tot alleen-schrijven.")
                .font(.appBody())
                .foregroundStyle(Color.appWarning)
            Text("Open Systeeminstellingen → Privacy & beveiliging → Agenda en geef volledige toegang. Daarna kun je dit venster opnieuw openen.")
                .font(.appBody(12))
                .foregroundStyle(Color.appTextSecondary)
        }
    }

    // MARK: - Granted body

    @ViewBuilder
    private var grantedBody: some View {
        querySection
        Divider()
        previewSection
        Spacer(minLength: 0)
        footerActions
    }

    private var querySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Selectie")
                .font(.appH2())
                .foregroundStyle(Color.appTextPrimary)

            HStack(alignment: .top, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Kalenders")
                        .font(.appLabel())
                        .foregroundStyle(Color.appTextSecondary)
                    if viewModel.calendars.isEmpty {
                        Text("Geen kalenders gevonden.")
                            .font(.appBody())
                            .foregroundStyle(Color.appTextSecondary)
                    } else {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 4) {
                                ForEach(viewModel.calendars) { cal in
                                    Toggle(isOn: Binding(
                                        get: { viewModel.selectedCalendarIds.contains(cal.id) },
                                        set: { _ in viewModel.toggleCalendar(cal.id) }
                                    )) {
                                        Text(cal.title)
                                            .font(.appBody())
                                    }
                                    .toggleStyle(.checkbox)
                                }
                            }
                            .padding(8)
                        }
                        .frame(maxHeight: 140)
                        .background(Color.appSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6).stroke(Color.appBorder, lineWidth: 0.5)
                        )
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Periode")
                        .font(.appLabel())
                        .foregroundStyle(Color.appTextSecondary)
                    DatePicker("Vanaf", selection: $viewModel.startDatum, displayedComponents: [.date])
                    DatePicker("Tot", selection: $viewModel.eindDatum, in: viewModel.startDatum..., displayedComponents: [.date])
                    TextField("Titel bevat (optioneel)", text: $viewModel.titleFilter)
                    Toggle("Sla hele dagen over", isOn: $viewModel.skipAllDay)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack {
                AppPrimaryButton(
                    title: viewModel.isFetching ? "Bezig…" : "Voorbeeld tonen",
                    isDisabled: viewModel.isFetching
                ) {
                    Task { await viewModel.fetchPreview() }
                }
                Spacer()
            }
        }
    }

    // MARK: - Preview

    @ViewBuilder
    private var previewSection: some View {
        if viewModel.rows.isEmpty {
            Text("Klik op 'Voorbeeld tonen' om events te zien.")
                .font(.appBody())
                .foregroundStyle(Color.appTextSecondary)
        } else {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 16) {
                    Text("\(viewModel.rows.count) event(s)")
                        .font(.appH2(14))
                    if viewModel.unmatchedCount > 0 {
                        Text("\(viewModel.unmatchedCount) zonder persoon")
                            .font(.appLabel())
                            .foregroundStyle(Color.appWarning)
                    }
                    if viewModel.skippedCount > 0 {
                        Text("\(viewModel.skippedCount) overgeslagen")
                            .font(.appLabel())
                            .foregroundStyle(Color.appTextSecondary)
                    }
                    Spacer()
                }

                Table(viewModel.rows) {
                    TableColumn("✓") { row in
                        Toggle("", isOn: Binding(
                            get: { row.include },
                            set: { viewModel.setInclude(row.id, $0) }
                        ))
                        .labelsHidden()
                        .disabled(row.skipReason != nil || row.persoonId == nil)
                    }
                    .width(28)
                    TableColumn("Datum") { row in
                        Text(formatDate(row.descriptor.startDate))
                            .font(.appMono(11))
                    }
                    TableColumn("Titel") { row in
                        Text(row.descriptor.title ?? "—")
                            .lineLimit(1)
                    }
                    TableColumn("Uren") { row in
                        Text(formatHours(row.descriptor.durationHours))
                            .font(.appMono(11))
                    }
                    TableColumn("Persoon") { row in
                        Picker("", selection: Binding(
                            get: { row.persoonId },
                            set: { viewModel.setPersoon(row.id, $0) }
                        )) {
                            Text("— Niet gekozen —").tag(nil as UUID?)
                            ForEach(viewModel.personen) { p in
                                Text(p.naam).tag(p.id as UUID?)
                            }
                        }
                        .labelsHidden()
                    }
                    TableColumn("Status") { row in
                        if let reason = row.skipReason {
                            AppStatusBadge(label: skipLabel(reason), tone: .neutral)
                        } else if row.persoonId == nil {
                            AppStatusBadge(label: "Geen persoon", tone: .warning)
                        } else {
                            AppStatusBadge(label: "Klaar", tone: .success)
                        }
                    }
                }
                .frame(minHeight: 220)
            }
        }
    }

    // MARK: - Footer

    private var footerActions: some View {
        HStack {
            if let result = viewModel.lastImportResult {
                Text("\(result.inserted) toegevoegd, \(result.skipped) al aanwezig")
                    .font(.appBody(12))
                    .foregroundStyle(Color.appAccentDark)
            }
            Spacer()
            Button("Sluiten") { dismiss() }
                .keyboardShortcut(.cancelAction)
            AppPrimaryButton(
                title: viewModel.isImporting
                    ? "Bezig…"
                    : "Importeer \(viewModel.includableRows.count) event(s)",
                isDisabled: viewModel.includableRows.isEmpty || viewModel.isImporting
            ) {
                Task {
                    if await viewModel.runImport() {
                        onCompleted()
                    }
                }
            }
        }
    }

    private func skipLabel(_ reason: EventMappingService.SkipReason) -> String {
        switch reason {
        case .allDay: return "Hele dag"
        case .cancelled: return "Geannuleerd"
        case .zeroDuration: return "Nul duur"
        }
    }

    private func formatDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "nl_NL")
        f.dateFormat = "d MMM HH:mm"
        return f.string(from: date)
    }

    private func formatHours(_ value: Double) -> String {
        let f = NumberFormatter()
        f.minimumFractionDigits = 0
        f.maximumFractionDigits = 1
        f.decimalSeparator = ","
        return f.string(from: value as NSNumber) ?? String(format: "%.1f", value)
    }
}
