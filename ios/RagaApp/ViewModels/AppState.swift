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

    private static let loggedInUserIdKey = "loggedInUserId"

    init() {
        currentUserId = UserDefaults.standard.string(forKey: Self.loggedInUserIdKey)
    }

    /// The server is the source of truth for the current user's role and
    /// capabilities (fetched via `/me`), not this client.
    var currentUser: AppUser? {
        users.first(where: { $0.id == currentUserId })
    }

    var isLoggedIn: Bool { currentUserId != nil }

    /// Convenience accessor kept for existing call sites that only need the
    /// role (e.g. view-conditional UI). Falls back to `.returner` before the
    /// first user/capabilities fetch completes.
    var role: Role {
        currentUser?.role ?? .returner
    }

    /// Called once onboarding (phone verification + role selection, or a
    /// returning-user re-login) produces a real account. Persists the id so
    /// the app stays logged in across launches.
    func logIn(user: AppUser) {
        currentUserId = user.id
        UserDefaults.standard.set(user.id, forKey: Self.loggedInUserIdKey)
        Task { await loadAll() }
    }

    func logOut() {
        currentUserId = nil
        UserDefaults.standard.removeObject(forKey: Self.loggedInUserIdKey)
        capabilities = nil
        users = []
        updates = []
        practices = []
        videos = []
        calendarEvents = []
    }

    func loadAll() async {
        guard currentUserId != nil else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            users = try await APIClient.shared.fetchUsers()
            await refreshCurrentUserContext()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Re-fetches everything that depends on the logged-in user: capabilities
    /// plus every role-sensitive feed. Called after the initial load and
    /// after `logIn(user:)`.
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

    @discardableResult
    func createCalendarEvent(date: Date, category: CalendarCategory, label: String, description: String?, visibleToRoles: [Role]) async -> Bool {
        guard let userId = currentUserId else { return false }
        do {
            let created = try await APIClient.shared.createCalendarEvent(
                date: date,
                category: category,
                label: label,
                description: description,
                visibleToRoles: visibleToRoles,
                userId: userId
            )
            calendarEvents.append(created)
            calendarEvents.sort { $0.date < $1.date }
            errorMessage = nil
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    @discardableResult
    func createUpdate(tag: UpdateTag, content: String, pinned: Bool, visibleToRoles: [Role]) async -> Bool {
        guard let userId = currentUserId else { return false }
        do {
            let created = try await APIClient.shared.createUpdate(tag: tag, content: content, pinned: pinned, visibleToRoles: visibleToRoles, userId: userId)
            updates.insert(created, at: 0)
            errorMessage = nil
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func deleteUpdate(id: String) async {
        guard let userId = currentUserId else { return }
        do {
            try await APIClient.shared.deleteUpdate(id: id, userId: userId)
            updates.removeAll { $0.id == id }
            errorMessage = nil
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

    @discardableResult
    func createVideo(
        title: String,
        set: String,
        competition: String?,
        duration: String?,
        pinned: Bool,
        pinLabel: String?,
        fileData: Data,
        fileName: String,
        mimeType: String
    ) async -> Bool {
        guard let userId = currentUserId else { return false }
        do {
            _ = try await APIClient.shared.uploadVideo(
                title: title,
                set: set,
                competition: competition,
                duration: duration,
                pinned: pinned,
                pinLabel: pinLabel,
                fileData: fileData,
                fileName: fileName,
                mimeType: mimeType,
                userId: userId
            )
            // Reload rather than insert locally so ordering (pinned-first,
            // then date) stays server-driven, matching submitRsvp's pattern.
            await loadVideos()
            errorMessage = nil
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func togglePinVideo(id: String, pinned: Bool, pinLabel: String?) async {
        guard let userId = currentUserId else { return }
        do {
            try await APIClient.shared.setVideoPin(id: id, pinned: pinned, pinLabel: pinLabel, userId: userId)
            await loadVideos()
            errorMessage = nil
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
