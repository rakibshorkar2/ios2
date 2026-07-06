import Foundation

class TorrentStorage {
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let fileURL: URL

    private static let torrentsFileName = "torrents.json"

    init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        fileURL = docs.appendingPathComponent(Self.torrentsFileName)
        encoder.outputFormatting = .prettyPrinted
    }

    func saveTorrents(_ snapshots: [TorrentSnapshot]) {
        guard let data = try? encoder.encode(snapshots) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    func loadTorrents() -> [TorrentSnapshot] {
        guard let data = try? Data(contentsOf: fileURL),
              let snapshots = try? decoder.decode([TorrentSnapshot].self, from: data)
        else { return [] }
        return snapshots
    }

    func clearTorrents() {
        try? FileManager.default.removeItem(at: fileURL)
    }
}
