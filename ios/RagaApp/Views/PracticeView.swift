import SwiftUI

struct PracticeView: View {
    @EnvironmentObject private var appState: AppState
    @State private var decliningPracticeId: String?
    @State private var reason: String = ""

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                if appState.role == .captain {
                    CaptainBannerView()
                }
                ForEach(appState.practices) { practice in
                    PracticeCardView(
                        practice: practice,
                        role: appState.role,
                        onYes: {
                            Task { await appState.submitRsvp(practiceId: practice.id, response: .yes, reason: nil) }
                        },
                        onNo: {
                            reason = ""
                            decliningPracticeId = practice.id
                        }
                    )
                }
            }
            .padding(16)
        }
        .refreshable { await appState.loadPractices() }
        .sheet(isPresented: Binding(
            get: { decliningPracticeId != nil },
            set: { if !$0 { decliningPracticeId = nil } }
        )) {
            RsvpReasonSheet(reason: $reason) {
                guard let id = decliningPracticeId else { return }
                Task {
                    await appState.submitRsvp(practiceId: id, response: .no, reason: reason)
                    decliningPracticeId = nil
                }
            }
        }
    }
}

private struct CaptainBannerView: View {
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Captain View")
                    .font(.subheadline.bold())
                    .foregroundStyle(Color("AccentColor"))
                Text("Full RSVP counts visible")
                    .font(.caption)
                    .foregroundStyle(Color("AccentColor").opacity(0.7))
            }
            Spacer()
            Image(systemName: "shield.fill")
                .foregroundStyle(Color("AccentColor").opacity(0.5))
                .font(.title2)
        }
        .padding(16)
        .background(Color("AccentColor").opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(Color("AccentColor").opacity(0.15)))
    }
}

struct RsvpReasonSheet: View {
    @Binding var reason: String
    let onSubmit: () -> Void
    @Environment(\.dismiss) private var dismiss

    private var isValid: Bool { !reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("e.g. Family commitment, exam conflict…", text: $reason, axis: .vertical)
                        .lineLimit(3...6)
                } header: {
                    Text("Why can't you make it?")
                } footer: {
                    Text("A short reason is required so captains can plan around absences.")
                }
            }
            .navigationTitle("Decline Practice")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: { Image(systemName: "xmark") }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        onSubmit()
                    } label: {
                        Image(systemName: "checkmark")
                    }
                    .disabled(!isValid)
                }
            }
        }
        .presentationDetents([.medium])
    }
}
