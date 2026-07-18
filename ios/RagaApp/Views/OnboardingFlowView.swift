import SwiftUI

/// Real login: name + phone -> SMS-style code confirmation -> role selection
/// gated by a backend-set access code (see backend/src/roleAccessCodes.ts) ->
/// a brief success screen before handing off to the main app. Mirrors the
/// Figma prototype's WelcomeScreen/DetailsScreen/VerifyScreen/SuccessScreen.
struct OnboardingFlowView: View {
    @StateObject private var viewModel = OnboardingViewModel()

    var body: some View {
        Group {
            switch viewModel.step {
            case .welcome:
                WelcomeStepView { viewModel.step = .details }
            case .details:
                DetailsStepView(viewModel: viewModel)
            case .code:
                CodeStepView(viewModel: viewModel, onBack: { viewModel.step = .details })
            case .role:
                RoleStepView(viewModel: viewModel, onBack: { viewModel.step = .code })
            case .success:
                if let user = viewModel.loggedInUser {
                    SuccessStepView(user: user)
                }
            }
        }
        .alert("Something went wrong", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }
}

// MARK: - Shared header

private struct OnboardingHeader: View {
    var icon: String?
    let title: String
    let subtitle: String
    var onBack: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let onBack {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.subheadline.bold())
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                        .background(.white.opacity(0.15), in: Circle())
                }
                .buttonStyle(.plain)
            } else if let icon {
                Image(systemName: icon)
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(.white.opacity(0.15), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            Text(title)
                .font(.title2.bold())
                .foregroundStyle(.white)
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.75))
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color("AccentColor").ignoresSafeArea(edges: .top))
    }
}

private func labeledField<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
    VStack(alignment: .leading, spacing: 6) {
        Text(label.uppercased())
            .font(.caption2.bold())
            .foregroundStyle(.secondary)
        content()
    }
}

private struct FieldBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(14)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Color(.separator)))
    }
}

private extension View {
    func fieldBackground() -> some View { modifier(FieldBackground()) }
}

// MARK: - Welcome

private struct WelcomeStepView: View {
    let onGetStarted: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Color("AccentColor")
                Circle().fill(.white.opacity(0.05)).frame(width: 260, height: 260).offset(x: 130, y: -200)
                Circle().fill(.white.opacity(0.05)).frame(width: 320, height: 320).offset(x: -150, y: 240)

                VStack(spacing: 20) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .fill(.white.opacity(0.15))
                            .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).strokeBorder(.white.opacity(0.2)))
                            .frame(width: 84, height: 84)
                        Text("RR")
                            .font(.system(size: 30, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                    }
                    VStack(spacing: 6) {
                        Text("RU RAGA")
                            .font(.system(size: 30, weight: .black))
                            .foregroundStyle(.white)
                        Text("Team Communication Hub")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.white.opacity(0.75))
                    }
                }
            }
            .clipped()
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Welcome back.")
                        .font(.title2.bold())
                    Text("Sign in to access the team roundup, practice schedule, and video library.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Button(action: onGetStarted) {
                    HStack {
                        Text("Get started")
                        Image(systemName: "arrow.right")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color("AccentColor"))
                .controlSize(.large)

                Text("For RU RAGA members only")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .padding(20)
            .background(Color(.systemGroupedBackground))
        }
        .ignoresSafeArea(edges: .top)
    }
}

// MARK: - Details (name + phone)

private struct DetailsStepView: View {
    @ObservedObject var viewModel: OnboardingViewModel

    var body: some View {
        VStack(spacing: 0) {
            OnboardingHeader(icon: "phone.fill", title: "Your details", subtitle: "We'll send a verification code to your number.")

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    labeledField("Full Name") {
                        TextField("Priya Kumar", text: $viewModel.name)
                            .textContentType(.name)
                            .fieldBackground()
                    }

                    labeledField("Phone Number") {
                        HStack(spacing: 8) {
                            Text("🇺🇸 +1")
                                .font(.subheadline.weight(.semibold))
                                .fieldBackground()
                                .fixedSize()

                            TextField("(201) 555-0142", text: Binding(
                                get: { viewModel.phone },
                                set: { viewModel.phone = Self.formatPhone($0) }
                            ))
                            .keyboardType(.phonePad)
                            .textContentType(.telephoneNumber)
                            .fieldBackground()
                        }
                    }

                    Label("Standard message rates may apply. Your number is only used for verification.", systemImage: "bell.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .padding(14)
                        .background(Color.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                    Button {
                        Task { await viewModel.sendCode() }
                    } label: {
                        if viewModel.isLoading {
                            ProgressView().frame(maxWidth: .infinity)
                        } else {
                            HStack {
                                Text("Send verification code")
                                Image(systemName: "arrow.right")
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color("AccentColor"))
                    .controlSize(.large)
                    .disabled(!viewModel.canSendCode || viewModel.isLoading)
                }
                .padding(20)
            }
        }
        .background(Color(.systemGroupedBackground))
    }

    private static func formatPhone(_ raw: String) -> String {
        let digits = raw.filter(\.isNumber).prefix(10)
        switch digits.count {
        case 0: return ""
        case 1...3: return String(digits)
        case 4...6:
            return "(\(digits.prefix(3))) \(digits.dropFirst(3))"
        default:
            return "(\(digits.prefix(3))) \(digits.dropFirst(3).prefix(3))-\(digits.dropFirst(6))"
        }
    }
}

// MARK: - Code verification

private struct CodeStepView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    let onBack: () -> Void

    @State private var digits: [String] = Array(repeating: "", count: 6)
    @FocusState private var focusedIndex: Int?
    @State private var showError = false

    var body: some View {
        VStack(spacing: 0) {
            OnboardingHeader(title: "Verify your number", subtitle: "Code sent to \(viewModel.phone)", onBack: onBack)

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    (Text("Hi ") + Text(viewModel.name).fontWeight(.bold) + Text(" — enter the 6-digit code below."))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 10) {
                        ForEach(0..<6, id: \.self) { i in
                            TextField("", text: $digits[i])
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.center)
                                .font(.title2.bold())
                                .foregroundStyle(showError ? .red : (digits[i].isEmpty ? .primary : Color("AccentColor")))
                                .frame(width: 44, height: 52)
                                .background(showError ? Color.red.opacity(0.1) : Color(.secondarySystemGroupedBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .strokeBorder(
                                            showError ? Color.red.opacity(0.5) : (digits[i].isEmpty ? Color(.separator) : Color("AccentColor")),
                                            lineWidth: 1.5
                                        )
                                )
                                .focused($focusedIndex, equals: i)
                                .onChange(of: digits[i]) { _, newValue in
                                    handleChange(index: i, newValue: newValue)
                                }
                        }
                    }
                    .frame(maxWidth: .infinity)

                    if showError {
                        Text("Incorrect code. Try again.")
                            .font(.caption.bold())
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity)
                    }

                    if let devCode = viewModel.devCodeHint {
                        Label("Dev mode — no SMS provider yet. Your code is \(devCode).", systemImage: "hammer.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(12)
                            .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }

                    Button {
                        Task { await submit() }
                    } label: {
                        if viewModel.isLoading {
                            ProgressView().frame(maxWidth: .infinity)
                        } else {
                            HStack {
                                Text("Verify & sign in")
                                Image(systemName: "arrow.right")
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color("AccentColor"))
                    .controlSize(.large)
                    .disabled(digits.contains("") || viewModel.isLoading)

                    Button("Use a different number", action: onBack)
                        .font(.footnote)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                .padding(20)
            }
        }
        .background(Color(.systemGroupedBackground))
        .onAppear { focusedIndex = 0 }
    }

    private func handleChange(index: Int, newValue: String) {
        showError = false
        if newValue.count > 1 {
            digits[index] = String(newValue.last!)
        }
        if !newValue.isEmpty && index < 5 {
            focusedIndex = index + 1
        }
        if digits.allSatisfy({ !$0.isEmpty }) {
            Task { await submit() }
        }
    }

    private func submit() async {
        viewModel.code = digits.joined()
        await viewModel.verifyCode()
        if viewModel.errorMessage != nil {
            viewModel.errorMessage = nil
            showError = true
            digits = Array(repeating: "", count: 6)
            focusedIndex = 0
        }
    }
}

// MARK: - Role selection

private struct RoleStepView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    let onBack: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            OnboardingHeader(title: "What's your role?", subtitle: "Ask a captain for your role's access code if you don't have it.", onBack: onBack)

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    VStack(spacing: 6) {
                        ForEach(Role.allCases, id: \.self) { role in
                            RoleOptionRow(role: role, isSelected: viewModel.selectedRole == role) {
                                viewModel.selectedRole = role
                            }
                        }
                    }

                    labeledField("Access Code") {
                        TextField("Enter code", text: $viewModel.accessCode)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                            .fieldBackground()
                    }

                    Button {
                        Task { await viewModel.confirmRole() }
                    } label: {
                        if viewModel.isLoading {
                            ProgressView().frame(maxWidth: .infinity)
                        } else {
                            HStack {
                                Text("Join RU RAGA")
                                Image(systemName: "arrow.right")
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color("AccentColor"))
                    .controlSize(.large)
                    .disabled(!viewModel.canConfirmRole || viewModel.isLoading)
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 20)
            }
        }
        .background(Color(.systemGroupedBackground))
    }
}

private struct RoleOptionRow: View {
    let role: Role
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: role.symbol)
                    .font(.subheadline)
                    .foregroundStyle(isSelected ? .white : Color("AccentColor"))
                    .frame(width: 30, height: 30)
                    .background(isSelected ? Color("AccentColor") : Color("AccentColor").opacity(0.1), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                Text(role.label)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color("AccentColor"))
                }
            }
            .padding(9)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(isSelected ? Color("AccentColor") : Color(.separator), lineWidth: isSelected ? 1.5 : 0.5)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Success

private struct SuccessStepView: View {
    @EnvironmentObject private var appState: AppState
    let user: AppUser

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            ZStack {
                Circle().fill(.white.opacity(0.15)).frame(width: 88, height: 88)
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(.white)
            }
            VStack(spacing: 6) {
                Text("You're in!")
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                (Text("Welcome to RU RAGA, ") + Text(user.name).fontWeight(.bold) + Text("."))
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.85))
                    .multilineTextAlignment(.center)
            }
            Spacer()
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color("AccentColor"))
        .ignoresSafeArea()
        .task {
            try? await Task.sleep(for: .seconds(1.8))
            appState.logIn(user: user)
        }
    }
}
