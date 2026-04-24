import SwiftUI
import AppKit

struct AboutView: View {
    private let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    private let build   = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"

    var body: some View {
        ZStack {
            Color(red: 0.09, green: 0.088, blue: 0.084).ignoresSafeArea()

            VStack(spacing: 0) {

                Spacer().frame(height: 36)

                // Icon
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 72, height: 72)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                Spacer().frame(height: 16)

                // Name
                Text("screens")
                    .font(.system(size: 20, weight: .thin))
                    .foregroundStyle(.white)
                    .kerning(1.5)

                Spacer().frame(height: 6)

                Text("version \(version) (\(build))")
                    .font(.system(size: 11, weight: .light))
                    .foregroundStyle(.white.opacity(0.3))

                Spacer().frame(height: 24)

                // Tagline
                Text("your monitor. a channel.")
                    .font(.system(size: 13, weight: .light))
                    .foregroundStyle(.white.opacity(0.5))
                    .kerning(0.3)

                Spacer().frame(height: 6)

                Text("a smol screensaver built on the are.na public api.")
                    .font(.system(size: 11, weight: .light))
                    .foregroundStyle(.white.opacity(0.3))
                    .multilineTextAlignment(.center)

                Spacer().frame(height: 28)

                Divider().background(Color.white.opacity(0.08)).padding(.horizontal, 32)

                Spacer().frame(height: 20)

                // Links
                HStack(spacing: 20) {
                    linkButton("github", url: "https://github.com/howwohmm/arenaframe")
                    linkButton("support", url: "mailto:mishraom.work@gmail.com")
                    linkButton("are.na", url: "https://are.na")
                }

                Spacer().frame(height: 20)

                Text("mit license · open source · made with ♥ by ohm.")
                    .font(.system(size: 10, weight: .light))
                    .foregroundStyle(.white.opacity(0.2))
                    .multilineTextAlignment(.center)

                Spacer().frame(height: 28)
            }
            .padding(.horizontal, 40)
        }
        .frame(width: 360, height: 320)
    }

    private func linkButton(_ label: String, url: String) -> some View {
        Button {
            if let u = URL(string: url) { NSWorkspace.shared.open(u) }
        } label: {
            Text(label)
                .font(.system(size: 11, weight: .light))
                .foregroundStyle(.white.opacity(0.4))
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(Color.white.opacity(0.06))
                .cornerRadius(5)
        }
        .buttonStyle(.plain)
    }
}
