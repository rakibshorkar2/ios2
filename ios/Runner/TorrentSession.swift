import Foundation
#if canImport(LibTorrent)
import LibTorrent
#endif

@available(iOS 16.0, *)
class TorrentSession: Identifiable {
    let id: String
    let magnetLink: String
    let savePath: String
    let addedAt: Date

    private var _name: String
    private var _hash: String
    private var _progress: Double = 0.0
    private var _downloadSpeed: Int = 0
    private var _uploadSpeed: Int = 0
    private var _downloaded: Int64 = 0
    private var _totalSize: Int64 = 0
    private var _eta: Int = 0
    private var _peers: Int = 0
    private var _seeds: Int = 0
    private var _state: String = "queued"
    private var _ratio: Double = 0.0
    private var _isSequential: Bool = false

    private var timer: Timer?
    let onUpdate: ((TorrentEvent) -> Void)?

    var snapshot: TorrentSnapshot {
        TorrentSnapshot(
            id: id,
            name: _name,
            hash: _hash,
            magnetLink: magnetLink,
            savePath: savePath,
            state: _state,
            progress: _progress,
            totalSize: _totalSize,
            downloaded: _downloaded,
            addedAt: addedAt,
            isSequential: _isSequential
        )
    }

    init(
        id: String,
        name: String,
        hash: String,
        magnetLink: String,
        savePath: String,
        onUpdate: ((TorrentEvent) -> Void)? = nil
    ) {
        self.id = id
        self._name = name
        self._hash = hash
        self.magnetLink = magnetLink
        self.savePath = savePath
        self.addedAt = Date()
        self.onUpdate = onUpdate
    }

    func start() {
        _state = "downloading"
        startPolling()
    }

    func pause() {
        _state = "paused"
        _downloadSpeed = 0
        _uploadSpeed = 0
        emitUpdate()
    }

    func resume() {
        _state = "downloading"
        emitUpdate()
    }

    func setSequential(_ enabled: Bool) {
        _isSequential = enabled
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        _state = "paused"
    }

    func remove() {
        timer?.invalidate()
        timer = nil
    }

    func updateProgress(
        progress: Double,
        downloadSpeed: Int,
        uploadSpeed: Int,
        downloaded: Int64,
        totalSize: Int64,
        eta: Int,
        peers: Int,
        seeds: Int,
        state: String,
        ratio: Double
    ) {
        _progress = progress
        _downloadSpeed = downloadSpeed
        _uploadSpeed = uploadSpeed
        _downloaded = downloaded
        _totalSize = totalSize
        _eta = eta
        _peers = peers
        _seeds = seeds
        _state = state
        _ratio = ratio
        emitUpdate()
    }

    private func startPolling() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.emitUpdate()
        }
    }

    private func emitUpdate() {
        let event = TorrentEvent(
            id: id,
            name: _name,
            progress: _progress,
            downloadSpeed: _downloadSpeed,
            uploadSpeed: _uploadSpeed,
            downloaded: _downloaded,
            totalSize: _totalSize,
            eta: _eta,
            peers: _peers,
            seeds: _seeds,
            state: _state,
            ratio: _ratio
        )
        onUpdate?(event)
    }

    deinit {
        timer?.invalidate()
    }
}
