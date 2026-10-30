import SwiftUI

@main
struct NeuralyzerPhoneApp: App {
    @State private var store = PhoneStore()
    @AppStorage("onboarded") private var onboarded = false
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            Group {
                if onboarded {
                    HomeView()
                } else {
                    OnboardingView(onboarded: $onboarded)
                }
            }
            .environment(store)
            .preferredColorScheme(.light)
            .tint(Theme.ink)
            .onChange(of: scenePhase) { _, phase in if phase == .active && onboarded { store.refreshAccess() } }
        }
    }
}
