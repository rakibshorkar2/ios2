import Foundation
import LibTorrent

@available(iOS 16.0, *)
class TorrentSession: Identifiable {
    let id: String
    let magnetLink: String
    let savePath: String
    let addedAt: Date

    private(set) var handle: TorrentHandle?

    var snapshot: TorrentSnapshot? {
        guard let h = handle else { return nil }
        h.updateSnapshot()
        let s = h.snapshot
        guard s.isValid else { return nil }
        return TorrentSnapshot(
            id: id,
            name: s.name ?? "",
            hash: h.infoHashes.best.hex,
            magnetLink: s.magnetLink ?? "",
            savePath: s.downloadPath?.path ?? savePath,
            state: stateString(from: s.state),
            progress: s.progress,
            totalSize: Int64(s.total),
            downloaded: Int64(s.totalDone),
            addedAt: addedAt,
            isSequential: s.isSequential
        )
    }

    init(id: String, magnetLink: String, savePath: String) {
        self.id = id
        self.magnetLink = magnetLink
        self.savePath = savePath
        self.addedAt = Date()
    }

    func attach(handle: TorrentHandle) {
        self.handle = handle
    }

    func pause() { handle?.pause() }
    func resume() { handle?.resume() }
    func setSequential(_ enabled: Bool) { handle?.setSequentialDownload(enabled) }
    func stop() { handle?.pause() }

    func remove(deleteFiles: Bool = false) {
        guard let h = handle else { return }
        h.session.removeTorrent(h, deleteFiles: deleteFiles)
        handle = nil
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
}
