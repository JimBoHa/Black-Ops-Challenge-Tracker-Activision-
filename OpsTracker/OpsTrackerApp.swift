import SwiftUI

@main
struct OpsTrackerApp: App {
    @State private var store = ChallengeStore()
    @State private var account = AccountStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .environment(account)
                .preferredColorScheme(.dark)
        }
    }
}
