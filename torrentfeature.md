

You are working on my existing Flutter application.

The project root now contains a folder named **LibTorrent-Swift**, which contains the complete source of the LibTorrent-Swift library.

Your task is to integrate this library into the existing Flutter iOS project and make the existing **Torrent** section fully functional.

### Integration

* Analyze the **LibTorrent-Swift** folder.
* Move or copy **only the files required** for a proper iOS integration into the `ios/` project structure.
* Configure Xcode build settings, Swift Package references, headers, libraries, and linker settings as needed.
* Do **not** copy unnecessary files such as documentation, examples, tests, CI files, or Git metadata.
* Organize the iOS project cleanly and follow Swift best practices.
* Ensure the project builds successfully after integration.

### Flutter ↔ Swift Bridge

Create a clean bridge using **Pigeon** (preferred) or **MethodChannel + EventChannel**.

Keep:

* All torrent logic in Swift.
* All UI in Flutter.

### Torrent Engine

Use the integrated **LibTorrent-Swift** as the only torrent backend.

Implement:

* Initialize torrent session
* Add Magnet links
* Add .torrent files
* Start downloads
* Pause
* Resume
* Stop
* Remove torrent
* Remove torrent and downloaded files
* Multiple simultaneous torrents
* Session persistence
* Sequential download
* File selection
* File priorities
* Download/upload speed limits
* Progress updates
* ETA
* Download/upload speed
* Seed count
* Peer count
* Torrent state
* Error handling

### Native Architecture

Organize native code into separate files such as:

* TorrentPlugin.swift
* TorrentManager.swift
* TorrentSession.swift
* TorrentStorage.swift
* TorrentEvents.swift

Avoid large monolithic files.

### Redesign the Torrent Tab

Redesign the existing Torrent tab while keeping it consistent with the rest of the application's design.

Create two subtabs:

## Search

Features:

* Search bar
* Torrent search results
* Filters
* Sort options
* Torrent details
* Magnet download button
* Add custom magnet link
* Add local .torrent file

## Downloads

Display all active and completed torrents.

Each torrent card should show:

* Name
* Progress bar
* Download speed
* Upload speed
* ETA
* Size
* Downloaded amount
* Seed count
* Peer count
* Status
* Ratio

Provide actions:

* Pause
* Resume
* Stop
* Remove
* Delete data
* Open files
* Share torrent
* Copy magnet
* File priorities
* Sequential download toggle

### Event Updates

Use an EventChannel for live updates.

Send efficient updates without blocking the Flutter UI.

### Existing App

Do **not** break existing:

* Browser tab
* Downloads tab
* Proxy support
* Settings
* Navigation
* Theme
* Existing architecture

Reuse existing components whenever possible.

### Code Quality

* Production-quality implementation
* Modular architecture
* No placeholder code
* No mock implementations
* Proper error handling
* Proper resource cleanup
* Swift concurrency where appropriate
* Efficient memory usage
* Efficient threading

### Final Goal

Deliver a complete, working torrent implementation powered by the integrated local **LibTorrent-Swift** source.

The existing Flutter application should compile successfully, and the redesigned Torrent tab should provide a polished experience with **Search** and **Downloads** subtabs backed by the native LibTorrent-Swift engine.
