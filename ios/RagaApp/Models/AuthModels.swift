import Foundation

struct RequestCodeResponse: Codable {
    let sent: Bool
    /// Only present while the backend's ENABLE_SMS is false (see
    /// backend/README.md) — real SMS delivery isn't wired up yet, so the dev
    /// code is handed back directly instead of texted.
    let devCode: String?
}

struct VerifyCodeResponse: Codable {
    let verified: Bool
    /// Non-nil when this phone already has an account — onboarding should
    /// skip role selection and log the user straight in.
    let user: AppUser?
}
