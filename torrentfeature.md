# Torrent Feature — Implementation Status

## ✅ Completed

### Xcode Subproject Integration
- LibTorrent-Swift copied to `ios/LibTorrent-Swift/`
- PBXFileReference, PBXContainerItemProxy, PBXTargetDependency, Frameworks phase, FRAMEWORK_SEARCH_PATHS, Runner dependency all configured in `project.pbxproj`
- `setup_libtorrent.sh` — clones arvidn/libtorrent v2.0.10 with `--recurse-submodules`, runs CMake via `make.sh`

### CI Workflow
- `build-ipa.yml` runs `brew install boost` and `setup_libtorrent.sh` before `flutter build ios`

### Flutter ↔ Swift Bridge (5 files)
- `TorrentPlugin.swift` — MethodChannel (12 methods) + EventChannel, `addTorrentFile` accepts `FlutterStandardTypedData`
- `TorrentManager.swift` — Uses real `Session` from LibTorrent-Swift, implements `SessionDelegate`, maps Flutter IDs to `TorrentHandle`
- `TorrentSession.swift` — Thin wrapper around `TorrentHandle` for snapshot generation
- `TorrentEvents.swift` — `TorrentEvent` + `TorrentSnapshot` models, mapped from `TorrentHandleSnapshot`
- `TorrentStorage.swift` — File-based JSON persistence (iOS Documents dir)

### Dart Provider & Models
- `torrent_provider.dart` — Platform-aware (iOS native, Android dtorrent_task_v2), `_handleNativeEvent` reads all 12 event fields
- `torrent_item.dart` — Full model with `downloadSpeed`, `uploadSpeed`, `downloaded`, `totalSize`, `eta`, `peers`, `seeds`, `ratio`, `isSequential`

### Torrent Engine Features
- Sequential download — API wired, UI toggle in popup menu
- File selection — functional checkboxes via `StatefulBuilder` + checked list
- File priorities — API on Swift side
- ETA — calculated and displayed in torrent cards + details sheet
- Multiple simultaneous torrents — supported by Session
- Session persistence — save/load via TorrentStorage
- Proper error handling — `SessionDelegate.didErrorOccur` wired

### Flutter UI
- Search tab — 39/39 search providers implemented (10 direct API + 29 via apilist.one proxy)
- Search sort by size (numeric), seeds, name
- Torrent cards — all fields: name, progress, DL speed, UL speed, ETA, size, downloaded, seeds, peers, ratio
- Actions popup menu — Stop, Sequential toggle (ON/OFF), Copy Magnet, Delete + Data
- Torrent details sheet — 9 stats: Progress, DL Speed, UL Speed, ETA, Size, Downloaded, Seeds, Peers, Ratio
- File selection in add-torrent dialog — functional checkboxes with tracked state
- Magnet button in search results

### Database
- Schema version 3 with `isSequential INTEGER DEFAULT 0` column
- v2→v3 migration (`ALTER TABLE torrents ADD COLUMN`)
- Fresh install includes column in `CREATE TABLE`
