import Foundation

@MainActor
final class AppState: ObservableObject {
    @Published var role: Role = .dancer
    @Published var users: [AppUser] = []
    @Published var updates: [UpdateItem] = []
    @Published var practices: [PracticeItem] = []
    @Published var videos: [VideoItem] = []
    @Published var calendarEvents: [CalendarEventItem] = []
    @Published var activeVideoSet: String = "All"
    @Published var isLoading = false
    @Published var errorMessage: String?

    let videoSets = ["All", "Set 1", "Set 2", "Set 3", "Full Run"]

    /// Dev-only stand-in for auth: the role toggle picks which seeded demo
    /// user (captain or dancer) the app acts as. Real accounts are a
    /// follow-up (see backend/README.md and the PRD's open questions).
    var currentUser: AppUser? {
        users.first(where: { $0.role == role })
    }

    func loadAll() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            async let usersTask = APIClient.shared.fetchUsers()
            async let updatesTask = APIClient.shared.fetchUpdates()
            async let calendarTask = APIClient.shared.fetchCalendarEvents()
            let (fetchedUsers, fetchedUpdates, fetchedCalendar) = try await (usersTask, updatesTask, calendarTask)
            users = fetchedUsers
            updates = fetchedUpdates
            calendarEvents = fetchedCalendar
            await loadPractices()
            await loadVideos()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadPractices() async {
        do {
            practices = try await APIClient.shared.fetchPractices(userId: currentUser?.id, role: role)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadVideos() async {
        do {
            videos = try await APIClient.shared.fetchVideos(set: activeVideoSet)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func toggleRole() {
        role = (role == .dancer) ? .captain : .dancer
        Task { await loadPractices() }
    }

    func submitRsvp(practiceId: String, response: RsvpResponse, reason: String?) async {
        guard let userId = currentUser?.id else { return }
        do {
            try await APIClient.shared.submitRsvp(practiceId: practiceId, userId: userId, response: response, reason: reason)
            await loadPractices()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
