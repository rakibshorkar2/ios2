# Torrent Feature — Implementation Status

## ✅ Completed

### Xcode Subproject Integration
- LibTorrent-Swift copied to `ios/LibTorrent-Swift/`
- PBXFileReference, PBXContainerItemProxy, PBXTargetDependency, Frameworks phase, FRAMEWORK_SEARCH_PATHS, Runner dependency all configured in `project.pbxproj`
- `setup_libtorrent.sh` — clones arvidn/libtorrent v2.0.10 with `--recurse-submodules`, runs CMake via `make.sh`

### CI Workflow
- `build-ipa.yml` runs `brew install boost` and `setup_libtorrent.sh` before `flutter build ios`

### Flutter ↔ Swift Bridge (5 files)
- `TorrentPlugin.swift` — MethodChannel (11 methods) + EventChannel with `addTorrentFile` implemented
- `TorrentManager.swift` — Uses real `Session` from LibTorrent-Swift, implements `SessionDelegate`, maps Flutter IDs to `TorrentHandle`
- `TorrentSession.swift` — Thin wrapper around `TorrentHandle` for snapshot generation
- `TorrentEvents.swift` — `TorrentEvent` + `TorrentSnapshot` models, mapped from `TorrentHandleSnapshot`
- `TorrentStorage.swift` — File-based JSON persistence

### Dart Provider & Models
- `torrent_provider.dart` — Platform-aware (iOS native, Android dtorrent_task_v2), `_handleNativeEvent` reads all 12 event fields
- `torrent_item.dart` — Full model with `downloadSpeed`, `uploadSpeed`, `downloaded`, `totalSize`, `eta`, `peers`, `seeds`, `ratio`

## ❌ Not Yet Implemented

### Torrent Engine Features
- [ ] Sequential download (API wired, not tested on iOS)
- [ ] File selection / file priorities (API exists in LibTorrent-Swift)
- [ ] Download/upload speed limits (API wired via `SessionSettings`)
- [ ] ETA (calculated in TorrentManager)
- [ ] Multiple simultaneous torrents (supported by Session)
- [ ] Session persistence (load/save via TorrentStorage)
- [ ] Proper error handling (SessionDelegate.didErrorOccur: wired)

### Flutter UI
- [ ] Search tab enhancements — filters, sort, details, magnet button
- [ ] Downloads tab — torrent cards with all fields (name, progress, speeds, ETA, size, seeds, peers, status, ratio)
- [ ] Actions: Open files, Share torrent, Copy magnet, File priorities, Sequential toggle
- [ ] Torrent details sheet — display peers, trackers, file list
- [ ] File selection in add-torrent dialog (currently cosmetic no-op)

### Other
- [ ] 26 of 44 search providers not implemented in `torrent_service.dart`
- [ ] Database schema missing `isSequential` column
- [ ] File-based persistence for settings (currently UserDefaults)
