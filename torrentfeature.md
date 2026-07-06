

You are working on an existing Flutter iOS application. The app already has a fully designed **Torrents** tab with Flutter UI. **Do not redesign or replace any existing UI.** Only implement the native torrent engine behind the existing interface.

### Goal

Integrate **LibTorrent-Swift** from the XITRIX GitHub repository as the native iOS torrent engine and connect it to the existing Flutter Torrent tab.

Requirements:

* Integrate LibTorrent-Swift into the iOS project using Swift Package Manager (or the repository's recommended integration method).
* Create a clean native bridge using **Pigeon** (preferred) or **MethodChannel** and **EventChannel**.
* Keep all torrent logic in Swift.
* Keep all UI in Flutter.
* Do not modify unrelated parts of the app.

### Native Swift Architecture

Create separate files/classes:

* `TorrentPlugin.swift`
* `TorrentManager.swift`
* `TorrentSession.swift`
* `TorrentEvents.swift`
* `TorrentStorage.swift`

Avoid putting all logic into one file.

### Flutter API

Expose these methods to Flutter:

* initialize()
* shutdown()
* addMagnet(String magnet)
* addTorrentFile(String path)
* pauseTorrent(String id)
* resumeTorrent(String id)
* removeTorrent(String id, bool deleteFiles)
* getAllTorrents()
* setSequentialDownload(String id, bool enabled)
* setDownloadLimit(int bytesPerSecond)
* setUploadLimit(int bytesPerSecond)

### Event Stream

Send real-time updates through an EventChannel.

Each update should include:

```json
{
  "id": "",
  "name": "",
  "progress": 0.0,
  "downloadSpeed": 0,
  "uploadSpeed": 0,
  "downloaded": 0,
  "totalSize": 0,
  "eta": 0,
  "peers": 0,
  "seeds": 0,
  "state": "",
  "ratio": 0.0
}
```

Updates should be smooth without blocking the UI.

### Required Features

Implement support for:

* Magnet links
* .torrent files
* Multiple simultaneous torrents
* Pause/Resume
* Remove torrent
* Remove torrent + data
* Persistent session restore
* Sequential download
* File selection
* File priorities
* Download/upload speed limits
* Progress tracking
* ETA calculation
* Peer and seed count
* Save path selection
* Error handling and recovery

### Integration

Reuse the existing Torrent tab.

Connect existing:

* Add Torrent button
* Magnet input
* Torrent list
* Progress cards
* Pause button
* Resume button
* Delete button

Do not replace the existing widgets.

### Code Quality

* Use modern Swift concurrency where appropriate.
* Write modular, production-quality code.
* Avoid duplicate code.
* Handle lifecycle correctly.
* Clean up sessions on app termination.
* Include logging for debugging.

### Deliverables

* Complete iOS integration.
* Flutter bridge.
* Working implementation connected to the existing Torrent tab.
* Any required `pubspec.yaml`, `Podfile`, or iOS project changes.
* Brief setup notes if additional configuration is required.

Do not generate placeholder code. Produce a complete, working implementation that integrates with the existing Flutter application while preserving the current UI.
