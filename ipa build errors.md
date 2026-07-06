# Build Error Log

~~**Error 1:** Xcode SPM crash: `-[PBXContainerItemProxy _uncachedOrderedRecursiveDependencies:...]`~~
**FIXED (1c417a9):** Wrong `remoteGlobalIDString` in PBXContainerItemProxy — pointed to a PBXContainerItemProxy inside LibTorrent-Swift's own project, not the actual LibTorrent framework target.

~~**Error 2:** `'libtorrent/torrent_handle.hpp' file not found`~~
**FIXED (fce3c92):** Added `setup_libtorrent.sh` step to CI workflow before `flutter build ios`.

~~**Error 3:** CMake: `Could NOT find Boost (missing: Boost_INCLUDE_DIR)`~~
**FIXED (d017e78):** Added `brew install boost` to CI workflow.

~~**Error 4:** CMake: `Cannot find source file: deps/try_signal/try_signal.cpp`~~
**FIXED (04c145b):** Added `--recurse-submodules` to `git clone` in `setup_libtorrent.sh`.

# Current Status

All 5 Swift bridge files rewritten to use the real LibTorrent-Swift APIs:

| File | Status |
|------|--------|
| `TorrentPlugin.swift` | ✅ `addTorrentFile` implemented, all method channels wired |
| `TorrentManager.swift` | ✅ Uses real `Session`, `MagnetURI`, `TorrentFile`, `TorrentHandle` via `import LibTorrent`; implements `SessionDelegate` |
| `TorrentSession.swift` | ✅ Thin wrapper around `TorrentHandle` |
| `TorrentEvents.swift` | ✅ Clean models, mapped from `TorrentHandleSnapshot` |
| `TorrentStorage.swift` | ✅ File-based JSON persistence |

**Dart side:**
- `torrent_item.dart` — Added missing fields: `downloadSpeed`, `uploadSpeed`, `downloaded`, `totalSize`, `eta`, `peers`, `seeds`, `ratio`
- `torrent_provider.dart` — `_handleNativeEvent` now reads all fields from native events

**Still needed for feature completion:**
- CI build passing with real LibTorrent integration (waiting for next CI run)
- `torrent_tab.dart` could be enhanced to display new fields (peers, seeds, ratio, etc.)
- File selection in add-torrent dialog is cosmetic only
- 26 of 44 search providers not implemented in `torrent_service.dart`
- Database schema missing `isSequential` column
