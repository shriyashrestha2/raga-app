import Foundation

enum OnboardingStep {
    case welcome
    case details
    case code
    case role
    case success
}

@MainActor
final class OnboardingViewModel: ObservableObject {
    @Published var step: OnboardingStep = .welcome
    @Published var name = ""
    @Published var phone = ""
    @Published var code = ""
    @Published var selectedRole: Role = .returner
    @Published var accessCode = ""
    @Published var isLoading = false
    @Published var errorMessage: String?

    /// Set once verify-code or select-role succeeds. Held here (rather than
    /// logged in immediately) so the success screen can show before
    /// `AppState.logIn(user:)` swaps the whole app over.
    @Published var loggedInUser: AppUser?

    /// Only populated while the backend's ENABLE_SMS is false — surfaced in
    /// the UI so testers aren't blocked without a real SMS provider wired up
    /// yet (see backend/README.md).
    @Published var devCodeHint: String?

    private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var trimmedPhone: String { phone.trimmingCharacters(in: .whitespacesAndNewlines) }

    var canSendCode: Bool { !trimmedName.isEmpty && trimmedPhone.count >= 7 }
    var canVerifyCode: Bool { code.trimmingCharacters(in: .whitespacesAndNewlines).count == 6 }
    var canConfirmRole: Bool { !accessCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    func sendCode() async {
        guard canSendCode else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let response = try await APIClient.shared.requestCode(name: trimmedName, phone: trimmedPhone)
            devCodeHint = response.devCode
            step = .code
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func verifyCode() async {
        guard canVerifyCode else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let response = try await APIClient.shared.verifyCode(phone: trimmedPhone, code: code.trimmingCharacters(in: .whitespacesAndNewlines))
            if let user = response.user {
                loggedInUser = user
                step = .success
            } else {
                step = .role
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func confirmRole() async {
        guard canConfirmRole else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let user = try await APIClient.shared.selectRole(
                phone: trimmedPhone,
                role: selectedRole,
                accessCode: accessCode.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            loggedInUser = user
            step = .success
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
