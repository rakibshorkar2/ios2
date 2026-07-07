import Foundation
import Flutter
import LibTorrent

@available(iOS 16.0, *)
class TorrentManager: NSObject {
    static let shared = TorrentManager()

    private var session: Session?
    private var torrents: [String: TorrentHandle] = [:]
    private var idByHash: [String: String] = [:]
    private var eventSink: FlutterEventSink?
    private let storage = TorrentStorage()
    private var isInitialized = false

    private override init() {}

    func initialize() {
        guard !isInitialized else { return }
        isInitialized = true

        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let dlPath = docs.appendingPathComponent("Downloads")
        let torPath = docs.appendingPathComponent("Torrents")
        let frPath = docs.appendingPathComponent("FastResume")

        for p in [dlPath, torPath, frPath] {
            try? FileManager.default.createDirectory(at: p, withIntermediateDirectories: true)
        }

        let settings = Session.Settings()
        settings.maxDownloadSpeed = UInt(max(0, UserDefaults.standard.integer(forKey: "download_limit")))
        settings.maxUploadSpeed = UInt(max(0, UserDefaults.standard.integer(forKey: "upload_limit")))

        session = Session()
        session?.downloadPath = dlPath
        session?.torrentsPath = torPath
        session?.fastResumePath = frPath
        session?.settings = settings
        session?.storages = [:]
        session?.add(self)
        session?.restore()

        let saved = storage.loadTorrents()
        for snap in saved {
            if let hash = torrentHash(fromHex: snap.hash) {
                idByHash[snap.hash] = snap.id
            }
        }
    }

    func shutdown() {
        session?.remove(self)
        session = nil
        torrents.removeAll()
        idByHash.removeAll()
        isInitialized = false
    }

    func setEventSink(_ sink: FlutterEventSink?) {
        eventSink = sink
    }

    func addMagnet(id: String, name: String, magnet: String, savePath: String, isSequential: Bool = false) {
        guard let url = URL(string: magnet),
              let magnetObj = MagnetURI(with: url),
              let session = session
        else { return }

        if let handle = session.addTorrent(magnetObj) {
            torrents[id] = handle
            if let hashStr = hashString(from: handle) {
                idByHash[hashStr] = id
            }
            if isSequential { handle.setSequentialDownload(true) }
            persist()
        }
    }

    func addTorrentFile(id: String, name: String, data: Data, savePath: String, isSequential: Bool = false) {
        guard let file = TorrentFile(with: data),
              let session = session
        else { return }

        if let handle = session.addTorrent(file) {
            torrents[id] = handle
            if let hashStr = hashString(from: handle) {
                idByHash[hashStr] = id
            }
            if isSequential { handle.setSequentialDownload(true) }
            persist()
        }
    }

    func pauseTorrent(_ id: String) {
        torrents[id]?.pause()
    }

    func resumeTorrent(_ id: String) {
        torrents[id]?.resume()
    }

    func removeTorrent(_ id: String, deleteFiles: Bool = false) {
        guard let handle = torrents[id] else { return }
        session?.removeTorrent(handle, deleteFiles: deleteFiles)
        torrents.removeValue(forKey: id)
        if let hashStr = hashString(from: handle) {
            idByHash.removeValue(forKey: hashStr)
        }
        persist()
    }

    func setSequential(_ id: String, enabled: Bool) {
        torrents[id]?.setSequentialDownload(enabled)
    }

    func setDownloadLimit(_ bytesPerSecond: Int) {
        session?.settings.maxDownloadSpeed = UInt(max(0, bytesPerSecond))
        UserDefaults.standard.set(bytesPerSecond, forKey: "download_limit")
    }

    func setUploadLimit(_ bytesPerSecond: Int) {
        session?.settings.maxUploadSpeed = UInt(max(0, bytesPerSecond))
        UserDefaults.standard.set(bytesPerSecond, forKey: "upload_limit")
    }

    func getAllTorrents() -> [[String: Any]] {
        torrents.compactMap { id, handle in
            event(from: handle, id: id)?.toDict()
        }
    }

    private func event(from handle: TorrentHandle, id: String) -> TorrentEvent? {
        handle.updateSnapshot()
        let s = handle.snapshot
        guard s.isValid else { return nil }
        return TorrentEvent(
            id: id,
            name: s.name ?? "",
            progress: s.progress,
            downloadSpeed: Int(s.downloadRate),
            uploadSpeed: Int(s.uploadRate),
            downloaded: Int64(s.totalDone),
            totalSize: Int64(s.total),
            eta: eta(from: s),
            peers: Int(s.numberOfPeers),
            seeds: Int(s.numberOfSeeds),
            state: stateString(from: s.state),
            ratio: s.totalDownload > 0 ? Double(s.totalUpload) / Double(s.totalDownload) : 0
        )
    }

    private func hashString(from handle: TorrentHandle) -> String? {
        handle.infoHashes.best.hex
    }

    private func torrentHash(fromHex hex: String) -> TorrentHashes? {
        nil
    }

    private func eta(from snapshot: TorrentHandle.Snapshot) -> Int {
        guard snapshot.downloadRate > 0 else { return 0 }
        let remaining = snapshot.total - snapshot.totalDone
        return Int(remaining / snapshot.downloadRate)
    }

    private func stateString(from state: TorrentHandle.State) -> String {
        switch state {
        case .checkingFiles, .checkingResumeData: return "checking"
        case .downloadingMetadata, .downloading: return "downloading"
        case .finished: return "completed"
        case .seeding: return "seeding"
        case .paused: return "paused"
        case .storageError: return "error"
        default: return "unknown"
        }
    }

    private func broadcast(event: TorrentEvent) {
        DispatchQueue.main.async { [weak self] in
            self?.eventSink?(event.toDict())
        }
    }

    private func persist() {
        let snapshots = torrents.compactMap { id, handle -> TorrentSnapshot? in
            handle.updateSnapshot()
            let s = handle.snapshot
            guard s.isValid else { return nil }
            return TorrentSnapshot(
                id: id,
                name: s.name ?? "",
                hash: handle.infoHashes.best.hex,
                magnetLink: s.magnetLink ?? "",
                savePath: s.downloadPath?.path ?? "",
                state: stateString(from: s.state),
                progress: s.progress,
                totalSize: Int64(s.total),
                downloaded: Int64(s.totalDone),
                addedAt: Date(),
                isSequential: s.isSequential
            )
        }
        storage.saveTorrents(snapshots)
    }
}

@available(iOS 16.0, *)
extension TorrentManager: SessionDelegate {
    func torrentManager(_ manager: Session, didAddTorrent torrent: TorrentHandle) {
        guard let hashStr = hashString(from: torrent),
              let id = idByHash[hashStr]
        else { return }
        torrents[id] = torrent
        persist()
    }

    func torrentManager(_ manager: Session, didRemoveTorrentWithHash hashesData: TorrentHashes) {
        let hashStr = hashesData.best.hex
        guard let id = idByHash[hashStr]
        else { return }
        torrents.removeValue(forKey: id)
        idByHash.removeValue(forKey: hashStr)
        persist()
    }

    func torrentManager(_ manager: Session, didReceiveUpdateForTorrent torrent: TorrentHandle) {
        guard let hashStr = hashString(from: torrent),
              let id = idByHash[hashStr],
              let event = event(from: torrent, id: id)
        else { return }
        broadcast(event: event)
    }

    func torrentManager(_ manager: Session, didErrorOccur error: Error) {
        DispatchQueue.main.async { [weak self] in
            self?.eventSink?(FlutterError(code: "TORRENT_ERROR", message: error.localizedDescription, details: nil))
        }
    }
}
