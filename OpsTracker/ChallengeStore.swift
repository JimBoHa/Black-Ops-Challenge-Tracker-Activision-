import Foundation
import Observation

@Observable
final class ChallengeStore {
    private(set) var challenges: [Challenge] = []
    var selectedKind: ChallengeKind?
    var selectedMode: GameMode?
    var query = ""
    var lastUpdated: Date?

    private let fileURL: URL

    init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let folder = base.appending(path: "OpsTracker", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        fileURL = folder.appending(path: "challenges.json")
        load()
    }

    var filtered: [Challenge] {
        challenges.filter { item in
            (selectedKind == nil || item.kind == selectedKind) &&
            (selectedMode == nil || item.mode == selectedMode) &&
            (query.isEmpty || item.title.localizedCaseInsensitiveContains(query) || item.detail.localizedCaseInsensitiveContains(query) || item.group.localizedCaseInsensitiveContains(query))
        }
    }

    var tracked: [Challenge] { challenges.filter(\.tracked).sorted { $0.progress > $1.progress } }
    var completion: Double {
        guard !challenges.isEmpty else { return 0 }
        return Double(challenges.filter(\.isComplete).count) / Double(challenges.count)
    }

    func challenge(id: UUID) -> Challenge? { challenges.first { $0.id == id } }

    func update(_ challenge: Challenge) {
        guard let index = challenges.firstIndex(where: { $0.id == challenge.id }) else { return }
        challenges[index] = challenge
        lastUpdated = .now
        save()
    }

    func resetSampleData() {
        challenges = SampleCatalog.challenges
        lastUpdated = .now
        save()
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL), let decoded = try? JSONDecoder().decode([Challenge].self, from: data) else {
            resetSampleData()
            return
        }
        challenges = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(challenges) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
