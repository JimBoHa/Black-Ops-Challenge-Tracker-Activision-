import SwiftUI

struct RootView: View {
    var body: some View {
        TabView {
            NavigationStack { DashboardView() }
                .tabItem { Label("Overview", systemImage: "scope") }
            NavigationStack { TrackerView() }
                .tabItem { Label("Tracker", systemImage: "checklist") }
            NavigationStack { AccountView() }
                .tabItem { Label("Account", systemImage: "person.crop.circle") }
        }
        .tint(.orange)
    }
}

struct DashboardView: View {
    @Environment(ChallengeStore.self) private var store

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                hero
                Text("TRACKED OPERATIONS").font(.caption.bold()).foregroundStyle(.secondary)
                if store.tracked.isEmpty {
                    ContentUnavailableView("No tracked challenges", systemImage: "scope", description: Text("Track challenges from the Tracker tab."))
                } else {
                    ForEach(store.tracked) { ChallengeCard(challenge: $0) }
                }
            }
            .padding()
        }
        .background(Color.black)
        .navigationTitle("OPS TRACKER")
        .toolbar { ToolbarItem(placement: .primaryAction) { Image(systemName: "shield.lefthalf.filled").foregroundStyle(.orange) } }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("MISSION READINESS").font(.caption.bold()).foregroundStyle(.orange)
            HStack(alignment: .lastTextBaseline) {
                Text(store.completion, format: .percent.precision(.fractionLength(0))).font(.system(size: 48, weight: .black, design: .rounded))
                Spacer()
                Text("\(store.challenges.filter(\.isComplete).count) / \(store.challenges.count) COMPLETE").font(.caption.bold()).foregroundStyle(.secondary)
            }
            ProgressView(value: store.completion).tint(.orange).scaleEffect(y: 2)
        }
        .padding(20)
        .background(.gray.opacity(0.14), in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(.orange.opacity(0.3)))
    }
}

struct ChallengeCard: View {
    let challenge: Challenge

    var body: some View {
        NavigationLink(value: challenge.id) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label(challenge.mode.rawValue.uppercased(), systemImage: challenge.kind.symbol).font(.caption.bold()).foregroundStyle(.orange)
                    Spacer()
                    if challenge.isComplete { Image(systemName: "checkmark.seal.fill").foregroundStyle(.green) }
                }
                Text(challenge.title).font(.headline).foregroundStyle(.white)
                Text(challenge.detail).font(.subheadline).foregroundStyle(.secondary).lineLimit(2)
                ProgressView(value: challenge.progress).tint(challenge.isComplete ? .green : .orange)
                HStack {
                    Text("\(challenge.current) / \(challenge.target)").monospacedDigit().font(.caption.bold())
                    Spacer()
                    Text(challenge.reward).font(.caption).foregroundStyle(.secondary)
                }
            }
            .padding()
            .background(.gray.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }
}
