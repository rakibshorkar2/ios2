import Foundation

class TorrentStorage {
    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private static let torrentsKey = "torrents_key"
    private static let settingsKey = "torrent_settings_key"

    init() {
        defaults = UserDefaults.standard
        encoder.outputFormatting = .prettyPrinted
    }

    func saveTorrents(_ snapshots: [TorrentSnapshot]) {
        guard let data = try? encoder.encode(snapshots) else { return }
        defaults.set(data, forKey: Self.torrentsKey)
    }

    func loadTorrents() -> [TorrentSnapshot] {
        guard let data = defaults.data(forKey: Self.torrentsKey),
              let snapshots = try? decoder.decode([TorrentSnapshot].self, from: data)
        else {
            return []
        }
        return snapshots
    }

    func saveSettings(_ settings: [String: Any]) {
        defaults.set(settings, forKey: Self.settingsKey)
    }

    func loadSettings() -> [String: Any] {
        defaults.dictionary(forKey: Self.settingsKey) ?? [:]
    }

    func clearTorrents() {
        defaults.removeObject(forKey: Self.torrentsKey)
    }
}
