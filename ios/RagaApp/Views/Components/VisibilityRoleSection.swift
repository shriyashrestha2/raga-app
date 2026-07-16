import SwiftUI

/// Shared "Visible to" role picker for the New Event and New Reminder
/// sheets: "Visible to ALL" (default, mutually exclusive) or any combination
/// of specific roles.
struct VisibilityRoleSection: View {
    @Binding var selection: Set<Role>

    var body: some View {
        Section {
            Button {
                selection = []
            } label: {
                HStack {
                    Text("Visible to ALL")
                    Spacer()
                    if selection.isEmpty {
                        Image(systemName: "checkmark").foregroundStyle(Color("AccentColor"))
                    }
                }
            }
            .foregroundStyle(.primary)

            ForEach(Role.allCases, id: \.self) { r in
                Button {
                    if selection.contains(r) {
                        selection.remove(r)
                    } else {
                        selection.insert(r)
                    }
                } label: {
                    HStack {
                        Label(r.label, systemImage: r.symbol)
                        Spacer()
                        if selection.contains(r) {
                            Image(systemName: "checkmark").foregroundStyle(Color("AccentColor"))
                        }
                    }
                }
                .foregroundStyle(.primary)
            }
        } header: {
            Text("Visible to")
        } footer: {
            Text(selection.isEmpty
                ? "Everyone on the team can see this event."
                : "Only the selected roles can see this event.")
        }
    }
}
