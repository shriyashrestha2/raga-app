import Foundation

extension APIClient {
    /// No `userId` header — these run before any account/session exists.
    func requestCode(name: String, phone: String) async throws -> RequestCodeResponse {
        try await post("auth/request-code", body: ["name": name, "phone": phone])
    }

    func verifyCode(phone: String, code: String) async throws -> VerifyCodeResponse {
        try await post("auth/verify-code", body: ["phone": phone, "code": code])
    }

    @discardableResult
    func selectRole(phone: String, role: Role, accessCode: String) async throws -> AppUser {
        try await post("auth/select-role", body: ["phone": phone, "role": role.rawValue, "accessCode": accessCode])
    }
}
