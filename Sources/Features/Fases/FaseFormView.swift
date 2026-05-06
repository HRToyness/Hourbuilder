import SwiftUI
import Database
import Models
import Styling

public struct FaseFormView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var naam: String
    @State private var volgorde: Int
    @State private var heeftStart: Bool
    @State private var startDatum: Date
    @State private var heeftEind: Bool
    @State private var eindDatum: Date
    @State private var isSaving = false
    @State private var errorMessage: String?

    private let projectId: UUID
    private let editingId: UUID?
    private let repository: FaseRepository
    private let onSaved: () -> Void

    public init(
        appDatabase: AppDatabase,
        projectId: UUID,
        existing: Fase? = nil,
        defaultVolgorde: Int = 1,
        onSaved: @escaping () -> Void
    ) {
        self.projectId = projectId
        self.editingId = existing?.id
        self.repository = FaseRepository(writer: appDatabase.dbWriter)
        self.onSaved = onSaved
        _naam = State(initialValue: existing?.naam ?? "")
        _volgorde = State(initialValue: existing?.volgorde ?? defaultVolgorde)
        _heeftStart = State(initialValue: existing?.startDatum != nil)
        _startDatum = State(initialValue: existing?.startDatum ?? Date())
        _heeftEind = State(initialValue: existing?.eindDatum != nil)
        _eindDatum = State(initialValue: existing?.eindDatum ?? Date())
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            AppSectionHeader(title: editingId == nil ? "Nieuwe fase" : "Fase bewerken")

            Form {
                TextField("Naam", text: $naam)
                Stepper("Volgorde: \(volgorde)", value: $volgorde, in: 1...99)

                Toggle("Heeft startdatum", isOn: $heeftStart)
                if heeftStart {
                    DatePicker("Start", selection: $startDatum, displayedComponents: [.date])
                }
                Toggle("Heeft einddatum", isOn: $heeftEind)
                if heeftEind {
                    DatePicker(
                        "Eind",
                        selection: $eindDatum,
                        in: heeftStart ? startDatum... : Date.distantPast...,
                        displayedComponents: [.date]
                    )
                }
            }
            .formStyle(.grouped)

            if let errorMessage {
                Text(errorMessage)
                    .font(.appBody())
                    .foregroundStyle(Color.appWarning)
            }

            HStack {
                Spacer()
                Button("Annuleren") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                AppPrimaryButton(
                    title: isSaving ? "Bezig…" : "Opslaan",
                    isDisabled: !canSave
                ) {
                    Task { await saveTapped() }
                }
            }
        }
        .padding(20)
        .frame(minWidth: 420, minHeight: 360)
    }

    private var canSave: Bool {
        !naam.trimmingCharacters(in: .whitespaces).isEmpty && !isSaving
    }

    private func saveTapped() async {
        isSaving = true
        defer { isSaving = false }

        let fase = Fase(
            id: editingId ?? UUID(),
            projectId: projectId,
            naam: naam.trimmingCharacters(in: .whitespaces),
            volgorde: volgorde,
            startDatum: heeftStart ? startDatum : nil,
            eindDatum: heeftEind ? eindDatum : nil
        )
        do {
            _ = try await repository.save(fase)
            onSaved()
            dismiss()
        } catch {
            errorMessage = "Opslaan mislukt: \(error.localizedDescription)"
        }
    }
}
