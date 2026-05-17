import SwiftUI

/// A scrollable list of all recorded sessions, grouped by date.
/// Presented as a sheet from SetupView.
struct SessionHistoryView: View {

    @EnvironmentObject var store: SessionStore
    @Environment(\.dismiss) private var dismiss

    // Sessions grouped by date string "YYYY-MM-DD"
    private var grouped: [(date: String, sessions: [PomodoroSession])] {
        let dict = Dictionary(grouping: store.sessions) { $0.date }
        return dict.keys.sorted(by: >).map { key in
            (date: key, sessions: dict[key]!.sorted { $0.startEpoch < $1.startEpoch })
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if store.sessions.isEmpty {
                    ContentUnavailableView(
                        "No Sessions Yet",
                        systemImage: "clock.arrow.circlepath",
                        description: Text("Your completed Pomodoro sessions will appear here.")
                    )
                } else {
                    List {
                        ForEach(grouped, id: \.date) { group in
                            Section(header: Text(formattedDate(group.date))) {
                                ForEach(group.sessions) { session in
                                    SessionRow(session: session)
                                }
                            }
                        }
                    }
                    #if os(iOS)
                    .listStyle(.insetGrouped)
                    #endif
                }
            }
            .navigationTitle("Session History")
#if os(iOS)
            .navigationBarTitleDisplayMode(.large)
#endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func formattedDate(_ iso: String) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        guard let date = fmt.date(from: iso) else { return iso }
        let out = DateFormatter()
        out.dateStyle = .full
        out.timeStyle = .none
        return out.string(from: date)
    }
}

// MARK: - SessionRow

private struct SessionRow: View {
    let session: PomodoroSession

    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Session \(session.sessionNumber)")
                        .font(.subheadline.weight(.semibold))
                    Text("\(session.startTime) – \(session.endTime)  ·  \(session.durationMinutes) min")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: expanded ? "chevron.up" : "chevron.down")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
            .onTapGesture { withAnimation { expanded.toggle() } }

            if expanded && !session.recap.isEmpty {
                Text(session.recap)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    SessionHistoryView()
        .environmentObject(SessionStore())
}
