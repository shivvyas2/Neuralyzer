import SwiftUI

@main
struct NeuralyzerPhoneApp: App {
    @State private var store = PhoneStore()
    @AppStorage("onboarded") private var onboarded = false

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
        }
    }
}
