import SwiftUI
import Database
import Models
import Styling

public struct TemplateEditorView: View {
    @Bindable var viewModel: TemplateEditorViewModel
    let onClosed: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab: Tab = .algemeen

    enum Tab: String, CaseIterable, Identifiable {
        case algemeen = "Algemeen"
        case fases = "Fases"
        case personen = "Personen"
        var id: String { rawValue }
    }

    public init(viewModel: TemplateEditorViewModel, onClosed: @escaping () -> Void) {
        self.viewModel = viewModel
        self.onClosed = onClosed
    }

    public var body: some View {
        VStack(spacing: 0) {
            header
            tabSwitcher
            Divider()
            content
            footer
        }
        .frame(minWidth: 640, minHeight: 520)
        .task { await viewModel.load() }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Template bewerken")
                    .font(.appH1(15))
                Text(viewModel.naam.isEmpty ? "Naamloos" : viewModel.naam)
                    .font(.appMeta(11))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if let err = viewModel.lastErrorMessage {
                Text(err)
                    .font(.appBody(11))
                    .foregroundStyle(Color.pillWarningFg)
            }
        }
        .padding(16)
    }

    private var tabSwitcher: some View {
        HStack(spacing: 0) {
            ForEach(Tab.allCases) { tab in
                Button {
                    selectedTab = tab
                } label: {
                    Text(tab.rawValue)
                        .font(.appBody(12))
                        .fontWeight(selectedTab == tab ? .semibold : .regular)
                        .foregroundStyle(selectedTab == tab ? Color.appTextPrimary : Color.appTextSecondary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .overlay(alignment: .bottom) {
                            Rectangle()
                                .fill(selectedTab == tab ? Color.appPrimary : Color.clear)
                                .frame(height: 2)
                        }
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .padding(.horizontal, 12)
    }

    @ViewBuilder
    private var content: some View {
        switch selectedTab {
        case .algemeen: algemeenTab
        case .fases: fasesTab
        case .personen: personenTab
        }
    }

    private var algemeenTab: some View {
        Form {
            TextField("Naam", text: $viewModel.naam)
            TextField("Beschrijving", text: $viewModel.beschrijving, axis: .vertical)
                .lineLimit(2...4)
            Section("Default doel-uren") {
                TextField("Klant", text: $viewModel.defaultDoelKlantUrenInput)
                TextField("Intern", text: $viewModel.defaultDoelInternUrenInput)
            }
            Section("Default notities") {
                TextEditor(text: $viewModel.defaultNotities)
                    .frame(minHeight: 80)
            }
        }
        .formStyle(.grouped)
        .onSubmit { Task { await viewModel.saveHeader() } }
    }

    private var fasesTab: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Fases (\(viewModel.fases.count))")
                    .font(.appLabel(11))
                    .foregroundStyle(.secondary)
                Spacer()
                AppPrimaryButton(title: "+ Fase") {
                    Task { await viewModel.addFase() }
                }
            }
            .padding(12)

            if viewModel.fases.isEmpty {
                Text("Nog geen fases.")
                    .font(.appBody(11))
                    .foregroundStyle(.secondary)
                    .padding(12)
            } else {
                Table(viewModel.fases) {
                    TableColumn("Vlg") { f in
                        Text("\(f.volgorde)")
                            .font(.appNumberSmall(11))
                    }
                    .width(40)
                    TableColumn("Naam") { f in
                        TextField("Fase naam", text: bindingForFaseNaam(f))
                            .textFieldStyle(.plain)
                    }
                    TableColumn("Week vanaf") { f in
                        TextField("week", text: bindingForWeekVanaf(f))
                            .textFieldStyle(.plain)
                            .font(.appNumberSmall(11))
                    }
                    .width(70)
                    TableColumn("Week tot") { f in
                        TextField("week", text: bindingForWeekTot(f))
                            .textFieldStyle(.plain)
                            .font(.appNumberSmall(11))
                    }
                    .width(70)
                    TableColumn("") { f in
                        Button(role: .destructive) {
                            Task { await viewModel.deleteFase(id: f.id) }
                        } label: {
                            Image(systemName: "trash")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.borderless)
                    }
                    .width(34)
                }
            }
        }
    }

    private var personenTab: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Personen (\(viewModel.entries.count))")
                    .font(.appLabel(11))
                    .foregroundStyle(.secondary)
                Spacer()
                Menu {
                    Button("Specifieke persoon…") {
                        if let first = viewModel.personen.first {
                            Task { await viewModel.addSpecifiekEntry(persoonId: first.id) }
                        }
                    }
                    .disabled(viewModel.personen.isEmpty)
                    Button("Placeholder rol…") {
                        Task { await viewModel.addPlaceholderEntry(rol: "Nieuwe rol", type: .intern) }
                    }
                } label: {
                    Text("+ Persoon")
                        .font(.appLabel(12))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.appPrimary)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                }
                .menuStyle(.button)
                .buttonStyle(.plain)
                .fixedSize()
            }
            .padding(12)

            if viewModel.entries.isEmpty {
                Text("Nog geen personen of placeholders.")
                    .font(.appBody(11))
                    .foregroundStyle(.secondary)
                    .padding(12)
            } else {
                ScrollView {
                    VStack(spacing: 4) {
                        ForEach(viewModel.entries) { entry in
                            entryRow(entry)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 12)
                }
            }
        }
    }

    private func entryRow(_ entry: TemplatePersoonEntry) -> some View {
        HStack(spacing: 8) {
            AppStatusBadge(
                label: entry.mode == .specifiek ? "SPECIFIEK" : "PLACEHOLDER",
                tone: entry.mode == .specifiek ? .success : .warning
            )

            switch entry.mode {
            case .specifiek:
                Picker("", selection: bindingForSpecifiekPersoon(entry)) {
                    ForEach(viewModel.personen) { p in
                        Text("\(p.naam) — \(p.type.label)").tag(p.id as UUID?)
                    }
                }
                .labelsHidden()
            case .placeholder:
                TextField("Rol", text: bindingForPlaceholderRol(entry))
                    .textFieldStyle(.roundedBorder)
                Picker("", selection: bindingForPlaceholderType(entry)) {
                    ForEach(PersoonType.allCases) { t in
                        Text(t.label).tag(t)
                    }
                }
                .labelsHidden()
                .frame(maxWidth: 180)
            }

            Spacer()
            Button(role: .destructive) {
                Task { await viewModel.deleteEntry(id: entry.id) }
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.borderless)
        }
        .padding(8)
        .background(Color.appSurface)
        .overlay(
            RoundedRectangle(cornerRadius: 5).stroke(Color.appBorder, lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 5))
    }

    private var footer: some View {
        HStack {
            Spacer()
            Button("Sluiten") {
                Task {
                    await viewModel.saveHeader()
                    onClosed()
                    dismiss()
                }
            }
            .keyboardShortcut(.defaultAction)
        }
        .padding(12)
        .background(Color.appSidebar)
        .overlay(alignment: .top) {
            Rectangle().fill(Color.appBorder).frame(height: 0.5)
        }
    }

    // MARK: - Bindings (each Task to repo on commit)

    private func bindingForFaseNaam(_ fase: TemplateFase) -> Binding<String> {
        Binding(
            get: { fase.naam },
            set: { newValue in
                var copy = fase
                copy.naam = newValue
                Task { await viewModel.updateFase(copy) }
            }
        )
    }

    private func bindingForWeekVanaf(_ fase: TemplateFase) -> Binding<String> {
        Binding(
            get: { fase.weekVanaf.map(String.init) ?? "" },
            set: { newValue in
                var copy = fase
                copy.weekVanaf = Int(newValue)
                Task { await viewModel.updateFase(copy) }
            }
        )
    }

    private func bindingForWeekTot(_ fase: TemplateFase) -> Binding<String> {
        Binding(
            get: { fase.weekTotEnMet.map(String.init) ?? "" },
            set: { newValue in
                var copy = fase
                copy.weekTotEnMet = Int(newValue)
                Task { await viewModel.updateFase(copy) }
            }
        )
    }

    private func bindingForSpecifiekPersoon(_ entry: TemplatePersoonEntry) -> Binding<UUID?> {
        Binding(
            get: { entry.persoonId },
            set: { newValue in
                var copy = entry
                copy.persoonId = newValue
                Task { await viewModel.updateEntry(copy) }
            }
        )
    }

    private func bindingForPlaceholderRol(_ entry: TemplatePersoonEntry) -> Binding<String> {
        Binding(
            get: { entry.placeholderRol ?? "" },
            set: { newValue in
                var copy = entry
                copy.placeholderRol = newValue
                Task { await viewModel.updateEntry(copy) }
            }
        )
    }

    private func bindingForPlaceholderType(_ entry: TemplatePersoonEntry) -> Binding<PersoonType> {
        Binding(
            get: { entry.placeholderType ?? .intern },
            set: { newValue in
                var copy = entry
                copy.placeholderType = newValue
                Task { await viewModel.updateEntry(copy) }
            }
        )
    }
}
