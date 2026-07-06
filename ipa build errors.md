~~Run flutter build ios --release --no-codesign~~

~~Xcode failed to resolve Swift Package Manager dependencies:  
-[PBXContainerItemProxy _uncachedOrderedRecursiveDependencies:...] unrecognized selector~~

**FIXED:** PBXContainerItemProxy `remoteGlobalIDString` was `D151479D2AE7BE56000407AE` (a PBXContainerItemProxy inside LibTorrent-Swift's own project), corrected to `D15147642AE6AE9C000407AE` (the actual LibTorrent framework target UUID).

---

~~setup_libtorrent.sh runs but CMake fails: Could NOT find Boost (missing: Boost_INCLUDE_DIR)~~

**FIXED:** Added `brew install boost` to CI workflow before `setup_libtorrent.sh`.

---

~~CMake Error: Cannot find source file: deps/try_signal/try_signal.cpp~~

**FIXED:** Added `--recurse-submodules` to `git clone` in `setup_libtorrent.sh` to fetch the `deps/try_signal` git submodule.
