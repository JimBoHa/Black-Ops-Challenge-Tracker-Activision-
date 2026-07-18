import Foundation
import Observation

@Observable
final class ChallengeStore {
    private(set) var challenges: [Challenge] = []
    var selectedKind: ChallengeKind?
    var selectedMode: GameMode?
    var query = ""
    var lastUpdated: Date?
    private(set) var persistenceError: String?
    private(set) var currentDate: Date

    private let fileURL: URL
    private let now: () -> Date

    init(fileURL: URL? = nil, now: @escaping () -> Date = Date.init) {
        let defaultBase = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let defaultFolder = defaultBase.appending(path: "OpsTracker", directoryHint: .isDirectory)
        let resolvedURL = fileURL ?? defaultFolder.appending(path: "challenges.json")
        let folder = resolvedURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        self.fileURL = resolvedURL
        self.now = now
        self.currentDate = now()
        load()
    }

    var active: [Challenge] {
        return challenges.filter { !$0.isExpired(at: currentDate) }
    }

    var filtered: [Challenge] {
        active.filter { item in
            (selectedKind == nil || item.kind == selectedKind) &&
            (selectedMode == nil || item.mode == selectedMode) &&
            (query.isEmpty || item.title.localizedCaseInsensitiveContains(query) || item.detail.localizedCaseInsensitiveContains(query) || item.group.localizedCaseInsensitiveContains(query))
        }
    }

    var tracked: [Challenge] { active.filter(\.tracked).sorted { $0.progress > $1.progress } }
    var completion: Double {
        let activeChallenges = active
        guard !activeChallenges.isEmpty else { return 0 }
        return Double(activeChallenges.filter(\.isComplete).count) / Double(activeChallenges.count)
    }

    func challenge(id: UUID) -> Challenge? { challenges.first { $0.id == id } }

    func refreshExpirations() {
        currentDate = now()
    }

    func update(_ challenge: Challenge) {
        guard let index = challenges.firstIndex(where: { $0.id == challenge.id }) else { return }
        challenges[index] = challenge
        if save() { lastUpdated = .now }
    }

    @discardableResult
    func resetSampleData() -> Bool {
        challenges = SampleCatalog.challenges
        let saved = save()
        if saved { lastUpdated = .now }
        return saved
    }

    private func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            resetSampleData()
            return
        }

        do {
            let data = try Data(contentsOf: fileURL)
            challenges = try JSONDecoder().decode([Challenge].self, from: data)
        } catch {
            let backupURL = fileURL
                .deletingPathExtension()
                .appendingPathExtension("corrupt-\(UUID().uuidString).json")

            let recoveryMessage: String
            do {
                try FileManager.default.copyItem(at: fileURL, to: backupURL)
                recoveryMessage = "Unreadable tracker data was backed up as \(backupURL.lastPathComponent)."
            } catch {
                recoveryMessage = "Tracker data could not be read or backed up."
            }

            if resetSampleData() {
                persistenceError = recoveryMessage
            }
        }
    }

    @discardableResult
    private func save() -> Bool {
        do {
            let data = try JSONEncoder().encode(challenges)
            try data.write(to: fileURL, options: .atomic)
            persistenceError = nil
            return true
        } catch {
            persistenceError = "Changes could not be saved. Check available device storage."
            return false
        }
    }
}
