import SwiftUI

struct OnboardingView: View {
    @Environment(ScanStore.self) private var store
    @Binding var onboarded: Bool
    @State private var step = 0

    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            switch step {
            case 0: welcome
            case 1: access
            default: done
            }
            Spacer()
        }
        .padding(48)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { if onboarded { step = store.hasAccess ? 2 : 1 } }
        .onChange(of: store.hasAccess) { _, granted in
            if granted && step == 1 { withAnimation { step = 2 } }
        }
    }

    private var welcome: some View {
        VStack(spacing: 28) {
            AppMark(size: 96)
            Text("Neuralyzer").font(.system(size: 44, weight: .bold))
            Button("Continue") { withAnimation { step = 1 } }
                .buttonStyle(PillButtonStyle())
        }
    }

    private var access: some View {
        VStack(spacing: 28) {
            Text("Allow Full Disk Access").font(.system(size: 34, weight: .bold))
            SettingsIllustration()
            Text("Turn on Neuralyzer in the list. If it is missing, press + and add it.")
                .font(.system(size: 15))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Open System Settings") { store.openFullDiskAccess() }
                .buttonStyle(PillButtonStyle())
        }
    }

    private var done: some View {
        VStack(spacing: 28) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 72))
                .foregroundStyle(.green)
            Text("All set").font(.system(size: 44, weight: .bold))
            Button("Start Scan") {
                onboarded = true
                store.scan()
            }
            .buttonStyle(PillButtonStyle())
            .disabled(!store.hasAccess)
        }
    }
}

/// A drawing of the Full Disk Access list with the Neuralyzer switch turned on.
struct SettingsIllustration: View {
    var body: some View {
        VStack(spacing: 0) {
            row(icon: "lock.shield", name: "Privacy & Security", header: true)
            Divider()
            row(icon: "terminal", name: "Terminal", on: true)
            Divider()
            row(app: true, name: "Neuralyzer", on: true, highlight: true)
            Divider()
            row(icon: "safari", name: "Safari", on: false)
        }
        .frame(width: 420)
        .surface()
        .shadow(color: .black.opacity(0.06), radius: 20, y: 8)
    }

    private func row(icon: String = "", app: Bool = false, name: String, on: Bool = false,
                     header: Bool = false, highlight: Bool = false) -> some View {
        HStack(spacing: 12) {
            if app { AppMark(size: 24) } else {
                Image(systemName: icon).font(.system(size: 15)).frame(width: 24).foregroundStyle(.secondary)
            }
            Text(name).font(.system(size: 14, weight: header ? .semibold : .regular))
            Spacer()
            if !header {
                Toggle("", isOn: .constant(on)).toggleStyle(.switch).labelsHidden().controlSize(.small).allowsHitTesting(false)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(highlight ? Color.accentColor.opacity(0.10) : .clear)
    }
}

/// The app's mark: a soft folder with a spark of light.
struct AppMark: View {
    var size: CGFloat

    var body: some View {
        ZStack {
            FolderShape(radius: size * 0.2, tabHeight: size * 0.12)
                .fill(LinearGradient(colors: [Color(red: 0.62, green: 0.80, blue: 1.0), Color(red: 0.36, green: 0.60, blue: 0.98)],
                                     startPoint: .top, endPoint: .bottom))
            Image(systemName: "sparkle")
                .font(.system(size: size * 0.36, weight: .semibold))
                .foregroundStyle(.white)
                .offset(y: size * 0.06)
        }
        .frame(width: size, height: size * 0.82)
    }
}
