import Foundation

@MainActor
final class AppState: ObservableObject {
    @Published var currentUserId: String?
    @Published var capabilities: Capabilities?
    @Published var users: [AppUser] = []
    @Published var updates: [UpdateItem] = []
    @Published var practices: [PracticeItem] = []
    @Published var videos: [VideoItem] = []
    @Published var calendarEvents: [CalendarEventItem] = []
    @Published var activeVideoSet: String = "All"
    @Published var isLoading = false
    @Published var errorMessage: String?

    let videoSets = ["All", "Set 1", "Set 2", "Set 3", "Full Run"]

    /// Dev-only stand-in for auth: `currentUserId` picks which seeded demo
    /// user (one per role) the app acts as. The server is the source of
    /// truth for that user's role and capabilities (fetched via `/me`), not
    /// this client. Real accounts are a follow-up (see backend/README.md and
    /// the PRD's open questions).
    var currentUser: AppUser? {
        users.first(where: { $0.id == currentUserId })
    }

    /// Convenience accessor kept for existing call sites that only need the
    /// role (e.g. view-conditional UI). Falls back to `.dancer` before the
    /// first user/capabilities fetch completes.
    var role: Role {
        currentUser?.role ?? .dancer
    }

    func loadAll() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let fetchedUsers = try await APIClient.shared.fetchUsers()
            users = fetchedUsers
            if currentUserId == nil || !fetchedUsers.contains(where: { $0.id == currentUserId }) {
                currentUserId = fetchedUsers.first(where: { $0.role == .captain })?.id ?? fetchedUsers.first?.id
            }
            await refreshCurrentUserContext()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Re-fetches everything that depends on which demo user is "logged in":
    /// capabilities plus every role-sensitive feed. Called after the initial
    /// load and every time `switchUser(to:)` picks a different demo user.
    func refreshCurrentUserContext() async {
        guard let userId = currentUserId else { return }
        do {
            async let meTask = APIClient.shared.fetchMe(userId: userId)
            async let updatesTask = APIClient.shared.fetchUpdates(userId: userId)
            async let calendarTask = APIClient.shared.fetchCalendarEvents(userId: userId)
            let (me, fetchedUpdates, fetchedCalendar) = try await (meTask, updatesTask, calendarTask)
            capabilities = me.capabilities
            updates = fetchedUpdates
            calendarEvents = fetchedCalendar
            await loadPractices()
            await loadVideos()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func switchUser(to userId: String) async {
        currentUserId = userId
        await refreshCurrentUserContext()
    }

    func loadPractices() async {
        guard let userId = currentUserId else { return }
        do {
            practices = try await APIClient.shared.fetchPractices(userId: userId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadCalendarEvents() async {
        guard let userId = currentUserId else { return }
        do {
            calendarEvents = try await APIClient.shared.fetchCalendarEvents(userId: userId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadVideos() async {
        guard let userId = currentUserId else { return }
        do {
            videos = try await APIClient.shared.fetchVideos(set: activeVideoSet, userId: userId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func submitRsvp(practiceId: String, response: RsvpResponse, reason: String?) async {
        guard let userId = currentUserId else { return }
        do {
            try await APIClient.shared.submitRsvp(practiceId: practiceId, userId: userId, response: response, reason: reason)
            await loadPractices()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
