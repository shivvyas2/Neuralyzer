import SwiftUI

@main
struct NeuralyzerApp: App {
    @State private var store = ScanStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .frame(minWidth: 900, minHeight: 620)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentMinSize)
    }
}

struct RootView: View {
    @Environment(ScanStore.self) private var store
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("onboarded") private var onboarded = false

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            if store.hasAccess && onboarded {
                HomeView()
                    .transition(.opacity)
            } else {
                OnboardingView(onboarded: $onboarded)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: store.hasAccess && onboarded)
        .onAppear {
            store.startAccessPolling()
            #if DEBUG
            Snapshot.scheduleIfRequested()
            #endif
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { store.startAccessPolling() }
        }
    }
}
