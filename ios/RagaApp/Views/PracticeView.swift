import SwiftUI

struct PracticeView: View {
    @EnvironmentObject private var appState: AppState
    @State private var decliningPracticeId: String?
    @State private var reason: String = ""
    @State private var showingNewPractice = false

    private var canCreatePractice: Bool { appState.capabilities?.practices.canCreatePractice == true }
    private var canCreatePropsDay: Bool { appState.capabilities?.practices.canCreatePropsDay == true }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                if canCreatePractice || canCreatePropsDay {
                    newSessionHeader
                }
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
        .sheet(isPresented: $showingNewPractice) {
            NewPracticeSheet(canCreatePractice: canCreatePractice, canCreatePropsDay: canCreatePropsDay) { date, location, focus, reminder, kind in
                Task { await appState.createPractice(date: date, location: location, focus: focus, reminder: reminder, kind: kind) }
            }
        }
    }

    /// Right-aligned "+" affordance mirroring MiniCalendarView's inline
    /// accent-circle button — this tab has no NavigationStack/toolbar of its
    /// own (see RootView.swift), so it can't use a system toolbar item.
    private var newSessionHeader: some View {
        HStack {
            Spacer()
            Button {
                showingNewPractice = true
            } label: {
                Image(systemName: "plus")
                    .font(.caption.bold())
                    .foregroundStyle(.white)
                    .frame(width: 30, height: 30)
                    .background(Color("AccentColor"), in: Circle())
            }
            .buttonStyle(.plain)
            .shadow(color: Color("AccentColor").opacity(0.35), radius: 4, y: 2)
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

/// New-session form shared by both kinds. Captains (who can create either)
/// get a kind picker; Production (Props Day only) skips straight to a
/// Props-Day-labeled form with no picker — mirrors NewFineEntrySheet/
/// NewVideoSheet's "sheet takes an onCreate closure" convention.
struct NewPracticeSheet: View {
    let canCreatePractice: Bool
    let canCreatePropsDay: Bool
    let onCreate: (_ date: Date, _ location: String, _ focus: String, _ reminder: String?, _ kind: PracticeKind) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var kind: PracticeKind = .practice
    @State private var date: Date = Date()
    @State private var location: String = ""
    @State private var focus: String = ""
    @State private var reminder: String = ""

    private var showsKindPicker: Bool { canCreatePractice && canCreatePropsDay }

    private var isValid: Bool {
        !location.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !focus.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                if showsKindPicker {
                    Section {
                        Picker("Type", selection: $kind) {
                            ForEach(PracticeKind.allCases, id: \.self) { k in
                                Label(k.label, systemImage: k.symbol).tag(k)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                }

                Section("Date & Time") {
                    DatePicker("Date", selection: $date)
                }

                Section("Location") {
                    TextField("e.g. Livingston Rec Center, Studio B", text: $location)
                }

                Section(kind == .propsDay ? "What's the plan?" : "Focus") {
                    TextField(kind == .propsDay ? "e.g. Prep costumes for showcase" : "e.g. Set 3 Formation Drill", text: $focus)
                }

                Section {
                    TextField("e.g. Boys wear black, girls wear white kurta", text: $reminder, axis: .vertical)
                        .lineLimit(2...4)
                } header: {
                    Text("Reminder (optional)")
                }
            }
            .navigationTitle(showsKindPicker ? "New Session" : (canCreatePropsDay ? "New Props Day" : "New Practice"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: { Image(systemName: "xmark") }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        onCreate(date, location.trimmingCharacters(in: .whitespacesAndNewlines), focus.trimmingCharacters(in: .whitespacesAndNewlines), reminder.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : reminder, kind)
                        dismiss()
                    } label: {
                        Image(systemName: "checkmark")
                    }
                    .disabled(!isValid)
                }
            }
        }
        .onAppear {
            if !canCreatePractice && canCreatePropsDay { kind = .propsDay }
        }
        .presentationDetents([.medium, .large])
    }
}
