~~Run flutter build ios --release --no-codesign~~

~~Xcode failed to resolve Swift Package Manager dependencies:  
-[PBXContainerItemProxy _uncachedOrderedRecursiveDependencies:...] unrecognized selector~~

**FIXED:** PBXContainerItemProxy `remoteGlobalIDString` was `D151479D2AE7BE56000407AE` (a PBXContainerItemProxy inside LibTorrent-Swift's own project), corrected to `D15147642AE6AE9C000407AE` (the actual LibTorrent framework target UUID).

---

**Current error (2026-07-06):**
```
Lexical or Preprocessor Issue (Xcode): 'libtorrent/torrent_handle.hpp' file not found
/Users/runner/work/ios2/ios2/ios/LibTorrent-Swift/LibTorrent/Core/TorrentHandle/TorrentHandle_Internal.h:10:8
```

**Fix needed:** Add `ios/setup_libtorrent.sh` step to CI workflow before `flutter build ios` to clone arvidn/libtorrent v2.0.10 and run CMake.
