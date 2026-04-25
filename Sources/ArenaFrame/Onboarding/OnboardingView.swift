import SwiftUI

// MARK: - OnboardingView
// 3-step welcome flow: Welcome → Add Channel → Ready

struct OnboardingView: View {
    @Bindable var appState: AppState
    @State private var step: Int = 0
    @State private var channelInput: String = ""
    @State private var isValidating: Bool = false
    @State private var validationError: String? = nil
    @State private var validatedName: String? = nil
    @State private var validatedCount: Int = 0

    var body: some View {
        ZStack {
            Color(red: 0.149, green: 0.145, blue: 0.137) // #262523
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                switch step {
                case 0:  welcomeStep
                case 1:  addChannelStep
                default: readyStep
                }

                Spacer()

                // Step dots
                HStack(spacing: 8) {
                    ForEach(0..<3) { i in
                        Circle()
                            .fill(i == step ? Color.white.opacity(0.7) : Color.white.opacity(0.2))
                            .frame(width: 5, height: 5)
                    }
                }
                .padding(.bottom, 40)
            }
        }
        .frame(width: 480, height: 460)
    }

    // MARK: Step 0 — Welcome

    private var welcomeStep: some View {
        VStack(spacing: 24) {
            Text("screens")
                .font(.system(size: 32, weight: .thin))
                .foregroundStyle(.white)
                .kerning(2)

            Text("your monitor. a channel.")
                .font(.system(size: 14, weight: .light))
                .foregroundStyle(.white.opacity(0.45))
                .kerning(0.5)

            Spacer().frame(height: 8)

            Text("turn any display into a living window\ninto your Are.na collections.")
                .font(.system(size: 13, weight: .light))
                .foregroundStyle(.white.opacity(0.55))
                .multilineTextAlignment(.center)
                .lineSpacing(4)

            Spacer().frame(height: 16)

            onboardBtn("get started") { withAnimation { step = 1 } }
        }
        .transition(.asymmetric(insertion: .opacity, removal: .opacity))
    }

    // MARK: Step 1 — Add Channel

    private var addChannelStep: some View {
        VStack(spacing: 20) {
            Text("add a channel")
                .font(.system(size: 24, weight: .light))
                .foregroundStyle(.white)

            Text("paste a public Are.na channel slug or URL")
                .font(.system(size: 13, weight: .light))
                .foregroundStyle(.white.opacity(0.45))

            VStack(spacing: 4) {
                TextField("", text: $channelInput, prompt: Text("e.g. lme-colour").foregroundStyle(.white.opacity(0.2)))
                    .textFieldStyle(.plain)
                    .font(.system(size: 14, weight: .light))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.white.opacity(0.07))
                    .cornerRadius(8)
                    .autocorrectionDisabled()
                    .onSubmit { validateChannel() }

                if let err = validationError {
                    Text(err)
                        .font(.system(size: 11, weight: .light))
                        .foregroundStyle(.red.opacity(0.7))
                }
                if let name = validatedName {
                    Text("✓ \(name) · \(validatedCount) blocks")
                        .font(.system(size: 11, weight: .light))
                        .foregroundStyle(.green.opacity(0.7))
                }
            }
            .frame(width: 320)

            HStack(spacing: 12) {
                if isValidating {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .scaleEffect(0.7)
                        .tint(.white.opacity(0.4))
                }

                onboardBtn(validatedName != nil ? "looks good →" : "check channel") {
                    if validatedName != nil {
                        appState.channelSlugs = [resolvedSlug()]
                        withAnimation { step = 2 }
                    } else {
                        validateChannel()
                    }
                }
                .disabled(channelInput.trimmingCharacters(in: .whitespaces).isEmpty || isValidating)
            }
        }
        .transition(.asymmetric(insertion: .opacity, removal: .opacity))
    }

    // MARK: Step 2 — Ready

    private var readyStep: some View {
        VStack(spacing: 24) {
            Text("you're set.")
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(.white)

            Text("press ⌘⇧A anytime to open screens\nESC or Q to close.")
                .font(.system(size: 13, weight: .light))
                .foregroundStyle(.white.opacity(0.5))
                .multilineTextAlignment(.center)
                .lineSpacing(4)

            Spacer().frame(height: 8)

            onboardBtn("start") {
                appState.hasCompletedOnboarding = true
                appState.fetchAll()
                // Close the host NSWindow — it's always the key window at this point
                NSApplication.shared.keyWindow?.close()
            }
        }
        .transition(.asymmetric(insertion: .opacity, removal: .opacity))
    }

    // MARK: Helpers

    private func onboardBtn(_ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 13, weight: .light))
                .foregroundStyle(.white.opacity(0.8))
                .padding(.horizontal, 28)
                .padding(.vertical, 10)
                .background(Color.white.opacity(0.09))
                .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }

    private func resolvedSlug() -> String {
        var s = channelInput.trimmingCharacters(in: .whitespaces)
        if let url = URL(string: s),
           let host = url.host,
           host == "are.na" || host.hasSuffix(".are.na") {
            s = url.pathComponents.last ?? s
        }
        s = s.lowercased()
        return s
    }

    private func validateChannel() {
        let slug = resolvedSlug()
        guard !slug.isEmpty else { return }
        validationError = nil
        validatedName = nil
        isValidating = true
        Task {
            do {
                let (name, count) = try await appState.client.validateChannel(slug: slug)
                await MainActor.run {
                    validatedName  = name
                    validatedCount = count
                    isValidating   = false
                }
            } catch let e as ArenaError {
                await MainActor.run {
                    validationError = e.errorDescription
                    isValidating    = false
                }
            } catch {
                await MainActor.run {
                    validationError = "couldn't reach Are.na. check your connection."
                    isValidating    = false
                }
            }
        }
    }
}
