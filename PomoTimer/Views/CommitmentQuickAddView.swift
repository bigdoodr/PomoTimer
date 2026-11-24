import SwiftUI

/// "I'm tasked to…" quick entry. Collapsed to a single row until tapped, so it
/// costs almost no space on the recap and summary screens.
///
/// `onDark` switches the palette for the dark BreakTransitionView styling.
/// Anything typed but not yet added is saved when the view goes away, so
/// tapping Start Break (or Start Fresh) never silently drops it.
struct CommitmentQuickAddView: View {

    @ObservedObject var store: SessionStore
    var onDark: Bool = false

    @State private var expanded = false
    @State private var text = ""
    @State private var person = ""
    /// Commitments added while this view has been on screen, shown as confirmation.
    @State private var addedThisVisit: [String] = []

    private var primary: Color { onDark ? .white : .primary }
    private var secondary: Color { onDark ? .white.opacity(0.7) : .secondary }
    private var placeholder: Color { onDark ? .white.opacity(0.5) : .secondary }
    private var fieldFill: Color { onDark ? .white.opacity(0.1) : Color.pomoSurface }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                expanded.toggle()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "checklist")
                    Text("I\u{2019}m tasked to\u{2026}")
                    Spacer(minLength: 0)
                    Image(systemName: expanded ? "chevron.up" : "plus")
                        .font(.caption)
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(secondary)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if expanded {
                field("What did you promise to do?", text: $text)
                    .onSubmit(commit)
                field("Who or what for? (optional)", text: $person)
                    .onSubmit(commit)

                Button(action: commit) {
                    Label("Add", systemImage: "plus.circle.fill")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.bordered)
                .tint(onDark ? Color.pomoMint : Color.pomoIndigo)
                .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            // Offset IDs, since the same text could be added twice.
            ForEach(Array(addedThisVisit.enumerated()), id: \.offset) { _, item in
                Label("Saved: \(item)", systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(secondary)
                    .lineLimit(1)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: expanded)
        .onDisappear(perform: commit)
    }

    private func field(_ prompt: String, text: Binding<String>) -> some View {
        TextField("", text: text, prompt: Text(prompt).foregroundStyle(placeholder))
            .textFieldStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(fieldFill)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(secondary.opacity(0.3), lineWidth: 1)
                    )
            )
            .foregroundStyle(primary)
    }

    /// Saves the entry (if any) and clears the fields for another.
    private func commit() {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        store.addCommitment(text: trimmed, person: person)
        addedThisVisit.append(trimmed)
        text = ""
        person = ""
    }
}
