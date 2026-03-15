import SwiftUI

struct LoginView: View {
    @Environment(AuthManager.self) private var auth
    @State private var handle = ""
    @State private var appPassword = ""
    @FocusState private var focusedField: Field?

    enum Field { case handle, password }

    var body: some View {
        ZStack {
            // Memphis dot-grid background
            DotGridBackground()
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Logo
                VStack(spacing: 16) {
                    CloudLogoView(size: 72)
                    Text("BSKY DREAMS")
                        .font(.syne(28, weight: .heavy))
                        .tracking(4)
                        .foregroundStyle(Color.nbBlack)
                }
                .padding(.bottom, 48)

                // Login card
                VStack(alignment: .leading, spacing: 0) {
                    Text("SIGN IN")
                        .font(.syne(18, weight: .heavy))
                        .tracking(3)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.nbAccent)

                    VStack(spacing: 16) {
                        NBTextField(
                            placeholder: "handle.bsky.social",
                            text: $handle,
                            label: "Handle"
                        )
                        .focused($focusedField, equals: .handle)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.emailAddress)
                        .submitLabel(.next)
                        .onSubmit { focusedField = .password }

                        NBTextField(
                            placeholder: "xxxx-xxxx-xxxx-xxxx",
                            text: $appPassword,
                            label: "App Password",
                            isSecure: true
                        )
                        .focused($focusedField, equals: .password)
                        .submitLabel(.done)
                        .onSubmit { signIn() }

                        // Helper text
                        Text("Create an App Password at bsky.app → Settings → App Passwords")
                            .font(.inter(12))
                            .foregroundStyle(Color.nbBlack.opacity(0.6))

                        if let error = auth.errorMessage {
                            Text(error)
                                .font(.inter(13, weight: .medium))
                                .foregroundStyle(.red)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        Button(action: signIn) {
                            HStack {
                                if auth.isLoading {
                                    ProgressView()
                                        .tint(Color.nbBlack)
                                        .scaleEffect(0.8)
                                }
                                Text(auth.isLoading ? "SIGNING IN..." : "SIGN IN")
                                    .font(.syne(15, weight: .heavy))
                                    .tracking(2)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.nbAccent)
                            .nbBorder()
                            .nbShadow(size: 4)
                        }
                        .disabled(handle.isEmpty || appPassword.isEmpty || auth.isLoading)
                        .offset(x: -2, y: -2)
                    }
                    .padding(20)
                    .background(Color.nbWhite)
                }
                .nbBorder()
                .nbShadow(size: 6)
                .padding(.horizontal, 24)

                Spacer()
                Spacer()
            }
        }
    }

    private func signIn() {
        guard !handle.isEmpty, !appPassword.isEmpty else { return }
        Task { await auth.login(handle: handle, appPassword: appPassword) }
    }
}

// MARK: - Reusable Components

struct NBTextField: View {
    let placeholder: String
    @Binding var text: String
    var label: String? = nil
    var isSecure = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let label {
                Text(label.uppercased())
                    .font(.syne(11, weight: .bold))
                    .tracking(1)
                    .foregroundStyle(Color.nbBlack)
            }
            Group {
                if isSecure {
                    SecureField(placeholder, text: $text)
                } else {
                    TextField(placeholder, text: $text)
                }
            }
            .font(.inter(15))
            .padding(.horizontal, 12)
            .padding(.vertical, 11)
            .background(Color.nbWhite)
            .nbBorder()
        }
    }
}

struct DotGridBackground: View {
    var body: some View {
        GeometryReader { geo in
            Canvas { context, size in
                let spacing: CGFloat = 24
                let dotSize: CGFloat = 2
                var y: CGFloat = 0
                while y < size.height {
                    var x: CGFloat = 0
                    while x < size.width {
                        let rect = CGRect(x: x - dotSize/2, y: y - dotSize/2, width: dotSize, height: dotSize)
                        context.fill(Path(ellipseIn: rect), with: .color(.nbBlack.opacity(0.12)))
                        x += spacing
                    }
                    y += spacing
                }
            }
        }
        .background(Color(hex: "#FFFDF8"))
    }
}

struct CloudLogoView: View {
    var size: CGFloat = 32

    var body: some View {
        Image(systemName: "cloud.fill")
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size * 0.675)
            .foregroundStyle(Color.nbAccent)
            .overlay(
                Image(systemName: "cloud")
                    .resizable()
                    .scaledToFit()
                    .frame(width: size, height: size * 0.675)
                    .foregroundStyle(Color.nbBlack)
                    .fontWeight(.black)
            )
    }
}
