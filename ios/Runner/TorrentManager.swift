import Foundation
import Flutter

@available(iOS 16.0, *)
class TorrentManager: @unchecked Sendable {
    static let shared = TorrentManager()

    private var sessions: [String: TorrentSession] = [:]
    private let storage = TorrentStorage()
    private var eventSink: FlutterEventSink?
    private var downloadLimit: Int = 0
    private var uploadLimit: Int = 0
    private var isInitialized = false

    private init() {}

    func initialize() {
        guard !isInitialized else { return }
        isInitialized = true
        let saved = storage.loadTorrents()
        for snap in saved {
            let session = TorrentSession(
                id: snap.id,
                name: snap.name,
                hash: snap.hash,
                magnetLink: snap.magnetLink,
                savePath: snap.savePath,
                onUpdate: { [weak self] event in
                    self?.broadcastEvent(event)
                }
            )
            sessions[snap.id] = session
        }
    }

    func shutdown() {
        for (_, session) in sessions {
            session.stop()
        }
        sessions.removeAll()
        storage.clearTorrents()
        isInitialized = false
    }

    func setEventSink(_ sink: FlutterEventSink?) {
        eventSink = sink
    }

    func addMagnet(
        id: String,
        name: String,
        magnet: String,
        savePath: String,
        isSequential: Bool = false
    ) {
        let hash = extractHash(from: magnet)
        let session = TorrentSession(
            id: id,
            name: name,
            hash: hash,
            magnetLink: magnet,
            savePath: savePath,
            onUpdate: { [weak self] event in
                self?.broadcastEvent(event)
            }
        )
        session.setSequential(isSequential)
        session.start()
        sessions[id] = session
        persistSessions()
    }

    func pauseTorrent(_ id: String) {
        sessions[id]?.pause()
        persistSessions()
    }

    func resumeTorrent(_ id: String) {
        sessions[id]?.resume()
        persistSessions()
    }

    func removeTorrent(_ id: String, deleteFiles: Bool = false) {
        sessions[id]?.remove()
        sessions.removeValue(forKey: id)
        persistSessions()
    }

    func setSequential(_ id: String, enabled: Bool) {
        sessions[id]?.setSequential(enabled)
    }

    func setDownloadLimit(_ bytesPerSecond: Int) {
        downloadLimit = bytesPerSecond
    }

    func setUploadLimit(_ bytesPerSecond: Int) {
        uploadLimit = bytesPerSecond
    }

    func getAllTorrents() -> [[String: Any]] {
        sessions.values.map { $0.snapshot.toDict() }
    }

    func session(for id: String) -> TorrentSession? {
        sessions[id]
    }

    private func broadcastEvent(_ event: TorrentEvent) {
        DispatchQueue.main.async { [weak self] in
            self?.eventSink?(event.toDict())
        }
    }

    private func persistSessions() {
        let snapshots = sessions.values.map { $0.snapshot }
        storage.saveTorrents(snapshots)
    }

    private func extractHash(from magnet: String) -> String {
        if magnet.hasPrefix("magnet:?xt=urn:btih:"),
           let range = magnet.range(of: "xt=urn:btih:([^&]+)", options: .regularExpression)
        {
            return String(magnet[range].dropFirst("xt=urn:btih:".count))
        }
        return magnet
    }
}
