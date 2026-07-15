import SwiftUI

/// What TeamInfoEditView is editing: the singleton team-level row, or one
/// member's roster/contact fields.
enum TeamInfoEditTarget {
    case teamInfo(TeamInfoModel)
    case member(AppUser)
}

/// One reusable Form for both editable surfaces in this subsystem. Presented
/// via push navigation (like AttendanceView, PracticePlannerView) rather
/// than a sheet — the caller pushes this onto the ambient NavigationStack
/// (TeamView owns the stack), so this view doesn't wrap its own
/// NavigationStack the way a modal sheet (e.g. PracticeView's
/// RsvpReasonSheet) would need to.
struct TeamInfoEditView: View {
    @EnvironmentObject private var appState: AppState
    @ObservedObject var viewModel: TeamRosterViewModel
    @Environment(\.dismiss) private var dismiss

    let target: TeamInfoEditTarget
    /// Fires with the freshly-saved AppUser after a member edit succeeds, so
    /// the caller can splice it back into `appState.users` without a full
    /// reload. Unused for the `.teamInfo` target.
    var onMemberSaved: (AppUser) -> Void = { _ in }

    @State private var teamName = ""
    @State private var season = ""
    @State private var description = ""

    @State private var email = ""
    @State private var phone = ""
    @State private var year = ""
    @State private var major = ""
    @State private var bio = ""
    @State private var emergencyContactName = ""
    @State private var emergencyContactPhone = ""

    @State private var isSaving = false
    @State private var errorMessage: String?

    private var navTitle: String {
        switch target {
        case .teamInfo: return "Edit Team Info"
        case .member(let member): return member.name
        }
    }

    var body: some View {
        Form {
            switch target {
            case .teamInfo:
                Section("Team") {
                    TextField("Team name", text: $teamName)
                    TextField("Season", text: $season)
                }
                Section {
                    TextField("What does this team do?", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                } header: {
                    Text("Description")
                }

            case .member:
                Section("Contact") {
                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    TextField("Phone", text: $phone)
                        .keyboardType(.phonePad)
                }
                Section("Team Details") {
                    TextField("Year (e.g. Sophomore)", text: $year)
                    TextField("Major", text: $major)
                }
                Section("Bio") {
                    TextField("A short bio…", text: $bio, axis: .vertical)
                        .lineLimit(3...6)
                }
                Section("Emergency Contact") {
                    TextField("Name", text: $emergencyContactName)
                    TextField("Phone", text: $emergencyContactPhone)
                }
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle(navTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button {
                    Task { await save() }
                } label: {
                    if isSaving {
                        ProgressView()
                    } else {
                        Text("Save").bold()
                    }
                }
                .disabled(isSaving)
            }
        }
        .onAppear(perform: populate)
    }

    private func populate() {
        switch target {
        case .teamInfo(let info):
            teamName = info.teamName
            season = info.season
            description = info.description ?? ""
        case .member(let member):
            email = member.email ?? ""
            phone = member.phone ?? ""
            year = member.year ?? ""
            major = member.major ?? ""
            bio = member.bio ?? ""
            emergencyContactName = member.emergencyContactName ?? ""
            emergencyContactPhone = member.emergencyContactPhone ?? ""
        }
    }

    private func save() async {
        guard let userId = appState.currentUserId else { return }
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }

        switch target {
        case .teamInfo:
            let ok = await viewModel.saveTeamInfo(
                teamName: teamName.trimmingCharacters(in: .whitespacesAndNewlines),
                season: season.trimmingCharacters(in: .whitespacesAndNewlines),
                description: description,
                userId: userId
            )
            if ok {
                dismiss()
            } else {
                errorMessage = viewModel.errorMessage ?? "Couldn't save. Try again."
            }

        case .member(let member):
            // Empty fields are omitted rather than explicitly nulled, matching
            // the rest of the app's PATCH-body convention (e.g. AttendanceView's
            // `notes`) — clearing a field to blank leaves the prior value in
            // place instead of wiping it server-side.
            let updated = await viewModel.updateMember(
                memberId: member.id,
                email: email.isEmpty ? nil : email,
                phone: phone.isEmpty ? nil : phone,
                year: year.isEmpty ? nil : year,
                major: major.isEmpty ? nil : major,
                bio: bio.isEmpty ? nil : bio,
                emergencyContactName: emergencyContactName.isEmpty ? nil : emergencyContactName,
                emergencyContactPhone: emergencyContactPhone.isEmpty ? nil : emergencyContactPhone,
                userId: userId
            )
            if let updated {
                onMemberSaved(updated)
                dismiss()
            } else {
                errorMessage = viewModel.errorMessage ?? "Couldn't save. Try again."
            }
        }
    }
}
