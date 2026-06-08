import SwiftUI

struct LoginView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var biometricManager: BiometricAuthManager

    @State private var mode: Mode = .login
    @State private var username = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var errorMessage = ""
    @State private var isLoading = false

    enum Mode { case login, register }

    var body: some View {
        ZStack {
            Color.cyberBackground.ignoresSafeArea()
                .scanlines(beam: true, beamColor: .cyberGreen)

            ScrollView {
                VStack(spacing: 32) {
                    // Header
                    VStack(spacing: 8) {
                        Image(systemName: "terminal.fill")
                            .font(.system(size: 48))
                            .foregroundColor(.cyberGreen)
                            .neonGlow(.cyberGreen, radius: 12)
                        Text("CyberLab")
                            .font(.system(size: 32, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                            .glitchEffect()
                        Text("SECURITY OPERATIONS")
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .foregroundColor(.cyberCyan)
                            .tracking(4)
                    }
                    .padding(.top, 60)

                    // Mode Toggle
                    HStack(spacing: 0) {
                        ForEach([Mode.login, Mode.register], id: \.self) { m in
                            Button {
                                withAnimation { mode = m }
                            } label: {
                                Text(m == .login ? "Authenticate" : "Initialize")
                                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                                    .foregroundColor(mode == m ? .black : .white.opacity(0.5))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(mode == m ? Color.cyberGreen : Color.clear)
                            }
                        }
                    }
                    .background(Color.cyberSurface)
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.cyberBorder, lineWidth: 1))

                    // Form
                    VStack(alignment: .leading, spacing: 16) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(mode == .login ? "System Access" : "Create Account")
                                .font(.system(size: 18, weight: .bold, design: .monospaced))
                                .foregroundColor(.white)
                            Text(mode == .login ? "Enter your credentials to access the console." : "Initialize a new operator account.")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.5))
                        }

                        CyberTextField("Username", text: $username, icon: "person")
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)

                        if mode == .register {
                            CyberTextField("Email", text: $email, icon: "envelope")
                                .keyboardType(.emailAddress)
                                .textInputAutocapitalization(.never)
                        }

                        CyberSecureField("Password", text: $password, icon: "lock")

                        if mode == .register {
                            CyberSecureField("Confirm Password", text: $confirmPassword, icon: "lock.shield")
                        }

                        if !errorMessage.isEmpty {
                            HStack(spacing: 6) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                Text(errorMessage)
                                    .font(.caption)
                            }
                            .foregroundColor(.red)
                            .padding(10)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(6)
                        }

                        Button {
                            Task { await submit() }
                        } label: {
                            HStack {
                                if isLoading {
                                    ProgressView().tint(.black)
                                } else {
                                    Text(mode == .login ? "Grant Access" : "Initialize")
                                        .font(.system(size: 15, weight: .bold, design: .monospaced))
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(isLoading || !isFormValid ? Color.cyberGreen.opacity(0.4) : Color.cyberGreen)
                            .foregroundColor(.black)
                            .cornerRadius(8)
                            .neonGlow(.cyberGreen, radius: isLoading || !isFormValid ? 0 : 9)
                        }
                        .disabled(isLoading || !isFormValid)

                        if mode == .login && biometricManager.isBiometricAvailable {
                            Button {
                                Task { await biometricLogin() }
                            } label: {
                                HStack {
                                    Image(systemName: biometricManager.biometricSystemImage)
                                    Text("Unlock with \(biometricManager.biometricLabel)")
                                        .font(.system(size: 14, weight: .medium, design: .monospaced))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .foregroundColor(.cyberGreen)
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.cyberGreen.opacity(0.5), lineWidth: 1))
                            }
                        }
                    }
                    .padding()
                    .background(Color.cyberSurface)
                    .cornerRadius(12)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.cyberBorder, lineWidth: 1))
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
    }

    private var isFormValid: Bool {
        guard !username.isEmpty && !password.isEmpty else { return false }
        if mode == .register {
            return !email.isEmpty && password == confirmPassword && password.count >= 8
        }
        return true
    }

    private func submit() async {
        errorMessage = ""
        isLoading = true
        defer { isLoading = false }
        do {
            if mode == .login {
                try await authManager.login(username: username, password: password)
            } else {
                try await authManager.register(username: username, email: email, password: password)
            }
        } catch let error as APIError {
            errorMessage = error.errorDescription ?? "An error occurred"
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func biometricLogin() async {
        let success = await biometricManager.authenticate(reason: "Unlock CyberLab")
        if !success { errorMessage = "\(biometricManager.biometricLabel) authentication failed" }
        // Note: biometric unlock assumes token is already stored from previous login
        if success, KeychainManager.load(.accessToken) != nil {
            authManager.isAuthenticated = true
            await authManager.fetchCurrentUser()
        }
    }
}

// MARK: - Custom Input Components

struct CyberTextField: View {
    let placeholder: String
    @Binding var text: String
    let icon: String

    init(_ placeholder: String, text: Binding<String>, icon: String) {
        self.placeholder = placeholder
        self._text = text
        self.icon = icon
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(.cyberGreen.opacity(0.7))
                .frame(width: 20)
            TextField(placeholder, text: $text)
                .font(.system(size: 14, design: .monospaced))
                .foregroundColor(.white)
                .tint(.cyberGreen)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color.cyberBackground)
        .cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.cyberBorder, lineWidth: 1))
    }
}

struct CyberSecureField: View {
    let placeholder: String
    @Binding var text: String
    let icon: String
    @State private var isVisible = false

    init(_ placeholder: String, text: Binding<String>, icon: String) {
        self.placeholder = placeholder
        self._text = text
        self.icon = icon
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(.cyberGreen.opacity(0.7))
                .frame(width: 20)
            Group {
                if isVisible {
                    TextField(placeholder, text: $text)
                } else {
                    SecureField(placeholder, text: $text)
                }
            }
            .font(.system(size: 14, design: .monospaced))
            .foregroundColor(.white)
            .tint(.cyberGreen)
            Button { isVisible.toggle() } label: {
                Image(systemName: isVisible ? "eye.slash" : "eye")
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.4))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color.cyberBackground)
        .cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.cyberBorder, lineWidth: 1))
    }
}

// MARK: - Legal Warning

struct LegalWarningView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var isLoading = false
    @State private var error = ""

    var body: some View {
        ZStack {
            Color.cyberBackground.ignoresSafeArea()
            VStack(spacing: 24) {
                Image(systemName: "exclamationmark.shield.fill")
                    .font(.system(size: 56))
                    .foregroundColor(.orange)

                Text("Legal Warning")
                    .font(.system(size: 24, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)

                VStack(alignment: .leading, spacing: 12) {
                    legalPoint("This tool is for authorized testing only")
                    legalPoint("Only scan systems you own or have written permission to scan")
                    legalPoint("Unauthorized scanning violates the CFAA and equivalent laws")
                    legalPoint("All activity is logged to an audit trail")
                    legalPoint("You are solely responsible for your actions")
                }
                .padding()
                .background(Color.cyberSurface)
                .cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.cyberBorder, lineWidth: 1))

                if !error.isEmpty {
                    Text(error).foregroundColor(.red).font(.caption)
                }

                Button {
                    Task {
                        isLoading = true
                        defer { isLoading = false }
                        do {
                            try await authManager.acknowledgeLegal()
                        } catch {
                            self.error = error.localizedDescription
                        }
                    }
                } label: {
                    HStack {
                        if isLoading { ProgressView().tint(.black) }
                        else { Text("I Understand and Accept").font(.system(size: 15, weight: .bold, design: .monospaced)) }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.cyberGreen)
                    .foregroundColor(.black)
                    .cornerRadius(8)
                }
                .disabled(isLoading)

                Button { authManager.logout() } label: {
                    Text("Decline and Log Out")
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.4))
                }
            }
            .padding(24)
        }
    }

    private func legalPoint(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "shield.lefthalf.filled")
                .foregroundColor(.orange)
                .font(.system(size: 13))
            Text(text)
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.8))
        }
    }
}
