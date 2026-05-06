import SwiftUI
import Database
import Models
import Styling

public struct TemplateApplyWizardView: View {
    @Bindable var viewModel: TemplateApplyWizardViewModel
    let onApplied: (UUID) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var resolutionMode: [UUID: ResolutionMode] = [:]

    enum ResolutionMode: String, Hashable {
        case existing
        case newPersoon
        case skip
    }

    public init(
        viewModel: TemplateApplyWizardViewModel,
        onApplied: @escaping (UUID) -> Void
    ) {
        self.viewModel = viewModel
        self.onApplied = onApplied
    }

    public var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    projectBaseSection
                    fasesPreviewSection
                    placeholdersSection
                    if !viewModel.specifiekePersonen.isEmpty {
                        specifieksSection
                    }
                }
                .padding(20)
            }
            footer
        }
        .frame(minWidth: 640, minHeight: 600)
        .task { await viewModel.load() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Project vanaf template")
                .font(.appH1(15))
            Text(viewModel.template.naam)
                .font(.appMeta(11))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.appSidebar)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.appBorder).frame(height: 0.5)
        }
    }

    private var projectBaseSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Project basis")
                .font(.appLabel(11))
                .foregroundStyle(.secondary)
                .tracking(0.5)
                .textCase(.uppercase)
            Form {
                TextField("Naam", text: $viewModel.projectNaam)
                TextField("Klantnaam", text: $viewModel.klantNaam)
                DatePicker("Startdatum", selection: $viewModel.startDatum, displayedComponents: [.date])
                Toggle("Heeft einddatum", isOn: $viewModel.heeftEindDatum)
                if viewModel.heeftEindDatum {
                    DatePicker("Einddatum",
                               selection: $viewModel.eindDatum,
                               in: viewModel.startDatum...,
                               displayedComponents: [.date])
                }
                TextField("Factuurnummer (optioneel)", text: $viewModel.factuurNummer)
            }
            .formStyle(.grouped)
        }
    }

    private var fasesPreviewSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Fases die worden aangemaakt")
                .font(.appLabel(11))
                .foregroundStyle(.secondary)
                .tracking(0.5)
                .textCase(.uppercase)

            if viewModel.fases.isEmpty {
                Text("Geen fases in deze template.")
                    .font(.appBody(11))
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 6) {
                    ForEach(viewModel.fases) { f in
                        fasePreviewRow(f)
                    }
                }
            }
        }
    }

    private func fasePreviewRow(_ f: TemplateFase) -> some View {
        let start = ProjectTemplateApplyService.startDate(
            for: f.weekVanaf,
            projectStart: viewModel.startDatum
        )
        let end = ProjectTemplateApplyService.endDate(
            for: f.weekTotEnMet,
            projectStart: viewModel.startDatum
        )
        return HStack {
            Text("\(f.volgorde).")
                .font(.appNumberSmall(11))
                .foregroundStyle(.tertiary)
            Text(f.naam)
                .font(.appH2(12))
            Spacer()
            if let s = start, let e = end {
                Text("\(formatDate(s)) → \(formatDate(e))")
                    .font(.appMono(11))
                    .foregroundStyle(.secondary)
            } else if f.weekVanaf == nil && f.weekTotEnMet == nil {
                Text("geen timing")
                    .font(.appLabel(11))
                    .foregroundStyle(.tertiary)
            }
            if let from = f.weekVanaf, let to = f.weekTotEnMet {
                Text("week \(from)–\(to)")
                    .font(.appLabel(10))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(8)
        .background(Color.appSurface)
        .overlay(
            RoundedRectangle(cornerRadius: 4).stroke(Color.appBorder, lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    @ViewBuilder
    private var placeholdersSection: some View {
        if !viewModel.placeholderEntries.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Placeholders invullen")
                    .font(.appLabel(11))
                    .foregroundStyle(.secondary)
                    .tracking(0.5)
                    .textCase(.uppercase)
                ForEach(viewModel.placeholderEntries) { entry in
                    placeholderRow(entry)
                }
            }
        }
    }

    private func placeholderRow(_ entry: TemplatePersoonEntry) -> some View {
        let mode = resolutionMode[entry.id] ?? .existing
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                AppStatusBadge(label: "PLACEHOLDER", tone: .warning)
                Text(entry.placeholderRol ?? "")
                    .font(.appH2(12))
                if let type = entry.placeholderType {
                    AppStatusBadge(label: type.label, tone: StatusBridge.badgeTone(for: type))
                }
                Spacer()
            }

            Picker("", selection: Binding(
                get: { resolutionMode[entry.id] ?? .existing },
                set: { newMode in
                    resolutionMode[entry.id] = newMode
                    switch newMode {
                    case .existing:
                        if let first = viewModel.personen.first {
                            viewModel.setExistingResolution(entryId: entry.id, persoonId: first.id)
                        }
                    case .newPersoon:
                        viewModel.setNewPersoonResolution(entryId: entry.id)
                    case .skip:
                        viewModel.setSkipResolution(entryId: entry.id)
                    }
                }
            )) {
                Text("Bestaande persoon").tag(ResolutionMode.existing)
                Text("Nieuwe persoon").tag(ResolutionMode.newPersoon)
                Text("Sla over").tag(ResolutionMode.skip)
            }
            .pickerStyle(.segmented)

            switch mode {
            case .existing:
                Picker("", selection: Binding<UUID?>(
                    get: {
                        if case .existing(let id) = viewModel.resolutions[entry.id] {
                            return id
                        }
                        return viewModel.personen.first?.id
                    },
                    set: { (newId: UUID?) in
                        if let id = newId {
                            viewModel.setExistingResolution(entryId: entry.id, persoonId: id)
                        }
                    }
                )) {
                    ForEach(viewModel.personen) { p in
                        Text("\(p.naam) — \(p.type.label)").tag(p.id as UUID?)
                    }
                }
                .labelsHidden()

            case .newPersoon:
                HStack {
                    TextField("Naam", text: Binding(
                        get: { viewModel.newPersoonNamen[entry.id, default: ""] },
                        set: {
                            viewModel.newPersoonNamen[entry.id] = $0
                            viewModel.setNewPersoonResolution(entryId: entry.id)
                        }
                    ))
                    TextField("Email (optioneel)", text: Binding(
                        get: { viewModel.newPersoonEmails[entry.id, default: ""] },
                        set: {
                            viewModel.newPersoonEmails[entry.id] = $0
                            viewModel.setNewPersoonResolution(entryId: entry.id)
                        }
                    ))
                }
                .textFieldStyle(.roundedBorder)
            case .skip:
                Text("Wordt overgeslagen — voeg later eventueel handmatig een persoon toe.")
                    .font(.appBody(11))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(10)
        .background(Color.appSurface)
        .overlay(
            RoundedRectangle(cornerRadius: 5).stroke(Color.appBorder, lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 5))
    }

    private var specifieksSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Specifieke personen (auto-toegevoegd)")
                .font(.appLabel(11))
                .foregroundStyle(.secondary)
                .tracking(0.5)
                .textCase(.uppercase)
            ForEach(viewModel.specifiekePersonen) { p in
                HStack {
                    AvatarBadge(name: p.naam, size: 22)
                    Text(p.naam).font(.appH2(12))
                    Spacer()
                    AppStatusBadge(label: p.type.label, tone: StatusBridge.badgeTone(for: p.type))
                }
                .padding(8)
                .background(Color.appSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 5).stroke(Color.appBorder, lineWidth: 0.5)
                )
                .clipShape(RoundedRectangle(cornerRadius: 5))
            }
        }
    }

    private var footer: some View {
        HStack {
            if let err = viewModel.lastErrorMessage {
                Text(err)
                    .font(.appBody(11))
                    .foregroundStyle(Color.pillWarningFg)
            }
            Spacer()
            Button("Annuleren") { dismiss() }
                .keyboardShortcut(.cancelAction)
            AppPrimaryButton(
                title: viewModel.isApplying ? "Bezig…" : "Maak project aan",
                isDisabled: !viewModel.canApply
            ) {
                Task {
                    if let result = await viewModel.apply() {
                        onApplied(result.projectId)
                        dismiss()
                    }
                }
            }
        }
        .padding(12)
        .background(Color.appSidebar)
        .overlay(alignment: .top) {
            Rectangle().fill(Color.appBorder).frame(height: 0.5)
        }
    }

    private func formatDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "nl_NL")
        f.dateFormat = "d MMM"
        return f.string(from: date)
    }
}
