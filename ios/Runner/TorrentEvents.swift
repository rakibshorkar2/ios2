import Foundation

struct TorrentEvent: Codable {
    let id: String
    let name: String
    let progress: Double
    let downloadSpeed: Int
    let uploadSpeed: Int
    let downloaded: Int64
    let totalSize: Int64
    let eta: Int
    let peers: Int
    let seeds: Int
    let state: String
    let ratio: Double

    func toDict() -> [String: Any] {
        [
            "id": id,
            "name": name,
            "progress": progress,
            "downloadSpeed": downloadSpeed,
            "uploadSpeed": uploadSpeed,
            "downloaded": downloaded,
            "totalSize": totalSize,
            "eta": eta,
            "peers": peers,
            "seeds": seeds,
            "state": state,
            "ratio": ratio,
        ]
    }
}

enum TorrentEventState: String {
    case downloading
    case seeding
    case paused
    case completed
    case error
    case checking
    case queued
}

struct TorrentSnapshot: Codable {
    let id: String
    let name: String
    let hash: String
    let magnetLink: String
    let savePath: String
    let state: String
    let progress: Double
    let totalSize: Int64
    let downloaded: Int64
    let addedAt: Date
    let isSequential: Bool

    func toDict() -> [String: Any] {
        [
            "id": id,
            "name": name,
            "hash": hash,
            "magnetLink": magnetLink,
            "savePath": savePath,
            "state": state,
            "progress": progress,
            "totalSize": totalSize,
            "downloaded": downloaded,
            "addedAt": ISO8601DateFormatter().string(from: addedAt),
            "isSequential": isSequential ? 1 : 0,
        ]
    }
}
