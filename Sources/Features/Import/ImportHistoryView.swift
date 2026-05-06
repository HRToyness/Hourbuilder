import SwiftUI
import Database
import Models
import Styling

public struct ImportHistoryView: View {
    @Bindable var viewModel: ImportHistoryViewModel
    let onUndo: () -> Void

    @Environment(\.dismiss) private var dismiss

    public init(viewModel: ImportHistoryViewModel, onUndo: @escaping () -> Void) {
        self.viewModel = viewModel
        self.onUndo = onUndo
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            AppSectionHeader(
                title: "Import historie",
                subtitle: "Laatste imports per project. Ongedaan maken verwijdert alle activiteiten van die import."
            )

            if viewModel.history.isEmpty {
                Text("Nog geen imports voor dit project.")
                    .font(.appBody())
                    .foregroundStyle(Color.appTextSecondary)
            } else {
                Table(viewModel.history) {
                    TableColumn("Datum") { bron in
                        Text(formatDate(bron.importDatum))
                            .font(.appMono(11))
                    }
                    TableColumn("Type") { bron in
                        Text(bron.type.label)
                    }
                    TableColumn("Bestand") { bron in
                        Text(bron.bestandsnaam ?? "—")
                            .foregroundStyle(Color.appTextSecondary)
                            .lineLimit(1)
                    }
                    TableColumn("Aantal") { bron in
                        Text("\(bron.rijenAantal)")
                            .font(.appMono(11))
                    }
                    TableColumn("") { bron in
                        Button(role: .destructive) {
                            Task {
                                await viewModel.undo(bron)
                                onUndo()
                            }
                        } label: {
                            Text("Ongedaan maken")
                        }
                    }
                }
                .frame(minHeight: 240)
            }

            if let count = viewModel.lastUndoCount {
                Text("\(count) activiteit(en) verwijderd.")
                    .font(.appBody(12))
                    .foregroundStyle(Color.appAccentDark)
            }

            if let err = viewModel.lastErrorMessage {
                Text(err)
                    .font(.appBody())
                    .foregroundStyle(Color.appWarning)
            }

            Spacer(minLength: 0)
            HStack {
                Spacer()
                Button("Sluiten") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
        }
        .padding(20)
        .frame(minWidth: 640, minHeight: 460)
        .task { await viewModel.load() }
    }

    private func formatDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "nl_NL")
        f.dateFormat = "d MMM yyyy HH:mm"
        return f.string(from: date)
    }
}
