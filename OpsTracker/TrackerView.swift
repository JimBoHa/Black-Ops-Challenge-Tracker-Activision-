import SwiftUI

struct TrackerView: View {
    @Environment(ChallengeStore.self) private var store

    var body: some View {
        @Bindable var store = store
        List {
            Section {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        FilterChip(title: "All", selected: store.selectedKind == nil) { store.selectedKind = nil }
                        ForEach(ChallengeKind.allCases) { kind in
                            FilterChip(title: kind.rawValue, selected: store.selectedKind == kind) { store.selectedKind = kind }
                        }
                    }
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }
            ForEach(store.filtered) { challenge in
                NavigationLink(value: challenge.id) {
                    VStack(alignment: .leading, spacing: 7) {
                        HStack { Text(challenge.title).font(.headline); Spacer(); Text(challenge.progress, format: .percent.precision(.fractionLength(0))).font(.caption.bold()).foregroundStyle(.orange) }
                        Text("\(challenge.group) · \(challenge.mode.rawValue)").font(.caption).foregroundStyle(.secondary)
                        ProgressView(value: challenge.progress).tint(challenge.isComplete ? .green : .orange)
                    }.padding(.vertical, 5)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.black)
        .navigationTitle("CHALLENGES")
        .searchable(text: $store.query, prompt: "Search challenges")
        .navigationDestination(for: UUID.self) { id in
            if let challenge = store.challenge(id: id) { ChallengeDetailView(challenge: challenge) }
        }
    }
}

struct FilterChip: View {
    let title: String
    let selected: Bool
    let action: () -> Void
    var body: some View {
        Button(title, action: action)
            .font(.caption.bold())
            .foregroundStyle(selected ? .black : .white)
            .padding(.horizontal, 14).padding(.vertical, 8)
            .background(selected ? Color.orange : Color.gray.opacity(0.25), in: Capsule())
    }
}

struct ChallengeDetailView: View {
    @Environment(ChallengeStore.self) private var store
    @State var challenge: Challenge

    var body: some View {
        Form {
            Section("Objective") { Text(challenge.detail); LabeledContent("Reward", value: challenge.reward); LabeledContent("Mode", value: challenge.mode.rawValue) }
            Section("Progress") {
                ProgressView(value: challenge.progress).tint(.orange)
                Stepper(value: $challenge.current, in: 0...challenge.target) { LabeledContent("Current", value: "\(challenge.current) / \(challenge.target)") }
                Toggle("Track on dashboard", isOn: $challenge.tracked).tint(.orange)
                if let persistenceError = store.persistenceError {
                    Label(persistenceError, systemImage: "externaldrive.badge.exclamationmark")
                        .foregroundStyle(.orange)
                }
            }
        }
        .navigationTitle(challenge.title)
        .onChange(of: challenge) { _, value in store.update(value) }
    }
}
