import Flutter
import UIKit
import Foundation
import ActivityKit

class DownloadManager: NSObject {
    static let shared = DownloadManager()

    private var backgroundSession: URLSession!
    private var activeTasks: [String: URLSessionDownloadTask] = [:]
    private var taskIdMap: [Int: String] = [:]
    private var progressMap: [String: (received: Int64, total: Int64)] = [:]
    private var resumeDataMap: [String: Data] = [:]
    private var saveDirMap: [String: String] = [:]
    private var retryCountMap: [String: Int] = [:]
    private var downloadUrlMap: [String: String] = [:]
    private var fileNameMap: [String: String] = [:]
    private let maxRetries = 3
    private var proxyHost: String = ""
    private var proxyPort: Int = 0
    private var proxyUsername: String = ""
    private var proxyPassword: String = ""
    private var proxyEnabled: Bool = false
    private var proxyProtocol: String = "http"
    private var liveActivities: [String: Activity<DownloadActivityAttributes>] = [:]
    var liveActivityEnabled: Bool = true
    var backgroundCompletionHandler: (() -> Void)?

    var eventSink: FlutterEventSink? {
        didSet {
            if eventSink != nil {
                replayPendingEvents()
                restorePendingTasks()
            }
        }
    }
    private var pendingEvents: [[String: Any]] = []

    private func replayPendingEvents() {
        guard let sink = eventSink else { return }
        for event in pendingEvents {
            sink(event)
        }
        pendingEvents.removeAll()
    }

    private override init() {
        super.init()
        backgroundSession = createSession()
        resolvePersistentDownloadFolder()
    }

    deinit {
        persistentFolderURL?.stopAccessingSecurityScopedResource()
    }

    var persistentFolderURL: URL?

    private func resolvePersistentDownloadFolder() {
        guard let bookmarkData = UserDefaults.standard.data(forKey: "persistentDownloadFolderBookmark") else { return }
        var isStale = false
        guard let url = try? URL(resolvingBookmarkData: bookmarkData, options: .withoutUI, relativeTo: nil, bookmarkDataIsStale: &isStale) else { return }
        if url.startAccessingSecurityScopedResource() {
            persistentFolderURL = url
        }
    }

    func setProxy(host: String, port: Int, username: String, password: String, enabled: Bool, protocol proto: String = "http") {
        let newProtocol = proto.lowercased()
        // Skip if nothing changed (avoids tearing down session on every init)
        guard proxyHost != host || proxyPort != port || proxyUsername != username ||
              proxyPassword != password || proxyEnabled != enabled || proxyProtocol != newProtocol else {
            return
        }
        proxyHost = host
        proxyPort = port
        proxyUsername = username
        proxyPassword = password
        proxyEnabled = enabled
        proxyProtocol = newProtocol
        // Recreate session with new proxy if no active downloads
        guard activeTasks.isEmpty else { return }
        backgroundSession.invalidateAndCancel()
        backgroundSession = createSession()
    }

    private func createSession() -> URLSession {
        let config = URLSessionConfiguration.background(withIdentifier: "com.dirxplore.background.download")
        config.isDiscretionary = false
        config.sessionSendsLaunchEvents = true
        config.shouldUseExtendedBackgroundIdleMode = true
        config.allowsCellularAccess = true
        if #available(iOS 13.0, *) {
            config.allowsExpensiveNetworkAccess = true
            config.allowsConstrainedNetworkAccess = true
        }
        config.waitsForConnectivity = true
        config.timeoutIntervalForResource = 604800 // 7 days max for entire resource
        config.timeoutIntervalForRequest = 30 // 30s to establish connection or receive next packet
        if proxyEnabled && !proxyHost.isEmpty && proxyPort > 0 {
            var proxyDict: [String: Any]
            switch proxyProtocol {
            case "socks5", "socks4":
                proxyDict = [
                    "SOCKSEnable": 1,
                    "SOCKSProxy": proxyHost,
                    "SOCKSPort": proxyPort,
                ]
                if !proxyUsername.isEmpty {
                    proxyDict["SOCKSUser"] = proxyUsername
                    proxyDict["SOCKSPassword"] = proxyPassword
                }
            case "https":
                proxyDict = [
                    "HTTPSEnable": 1,
                    "HTTPSProxy": proxyHost,
                    "HTTPSPort": proxyPort,
                ]
                if !proxyUsername.isEmpty {
                    proxyDict["HTTPSUser"] = proxyUsername
                    proxyDict["HTTPSPassword"] = proxyPassword
                }
            default: // http
                proxyDict = [
                    "HTTPEnable": 1,
                    "HTTPProxy": proxyHost,
                    "HTTPPort": proxyPort,
                ]
                if !proxyUsername.isEmpty {
                    proxyDict["HTTPUser"] = proxyUsername
                    proxyDict["HTTPPassword"] = proxyPassword
                }
                // Also set HTTPS to same proxy for HTTPS URLs
                proxyDict["HTTPSEnable"] = 1
                proxyDict["HTTPSProxy"] = proxyHost
                proxyDict["HTTPSPort"] = proxyPort
            }
            config.connectionProxyDictionary = proxyDict
        }
        return URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }

    func startDownload(url: String, fileName: String, downloadId: String, saveDir: String? = nil) {
        if let dir = saveDir {
            saveDirMap[downloadId] = dir
            // Pre-create the download directory so it exists when file arrives
            let dirURL = URL(fileURLWithPath: dir)
            try? FileManager.default.createDirectory(at: dirURL, withIntermediateDirectories: true)
        }
        downloadUrlMap[downloadId] = url
        fileNameMap[downloadId] = fileName
        guard let downloadUrl = URL(string: url) else {
            sendEvent(type: "error", downloadId: downloadId, data: ["message": "Invalid URL"])
            return
        }

        if let resumeData = resumeDataMap[downloadId] {
            let task = backgroundSession.downloadTask(withResumeData: resumeData)
            task.taskDescription = "\(downloadId)|\(fileName)"
            activeTasks[downloadId] = task
            taskIdMap[task.taskIdentifier] = downloadId
            resumeDataMap.removeValue(forKey: downloadId)
            task.resume()
            startLiveActivity(downloadId: downloadId, fileName: fileName)
            sendEvent(type: "resumed", downloadId: downloadId, data: ["fileName": fileName])
        } else {
            var request = URLRequest(url: downloadUrl)
            request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1", forHTTPHeaderField: "User-Agent")

            let task = backgroundSession.downloadTask(with: request)
            task.taskDescription = "\(downloadId)|\(fileName)"
            activeTasks[downloadId] = task
            taskIdMap[task.taskIdentifier] = downloadId
            progressMap[downloadId] = (0, 0)
            task.resume()
            startLiveActivity(downloadId: downloadId, fileName: fileName)
            sendEvent(type: "started", downloadId: downloadId, data: ["fileName": fileName, "url": url])
        }
    }

    func pauseDownload(downloadId: String) {
        guard let task = activeTasks[downloadId] else {
            sendEvent(type: "error", downloadId: downloadId, data: ["message": "No active task to pause"])
            return
        }
        task.cancel { [weak self] possibleResumeData in
            guard let self = self else { return }
            if let resumeData = possibleResumeData {
                self.resumeDataMap[downloadId] = resumeData
            }
            self.activeTasks.removeValue(forKey: downloadId)
            self.taskIdMap.removeValue(forKey: task.taskIdentifier)
            self.sendEvent(type: "paused", downloadId: downloadId, data: [:])
        }
    }

    func cancelDownload(downloadId: String) {
        guard let task = activeTasks[downloadId] else {
            sendEvent(type: "cancelled", downloadId: downloadId, data: [:])
            return
        }
        task.cancel()
        activeTasks.removeValue(forKey: downloadId)
        taskIdMap.removeValue(forKey: task.taskIdentifier)
        resumeDataMap.removeValue(forKey: downloadId)
        progressMap.removeValue(forKey: downloadId)
        retryCountMap.removeValue(forKey: downloadId)
        fileNameMap.removeValue(forKey: downloadId)
        endLiveActivity(downloadId: downloadId, status: "Cancelled")
        sendEvent(type: "cancelled", downloadId: downloadId, data: [:])
    }

    func cancelAll() {
        for (id, task) in activeTasks {
            task.cancel()
            taskIdMap.removeValue(forKey: task.taskIdentifier)
            resumeDataMap.removeValue(forKey: id)
            progressMap.removeValue(forKey: id)
            retryCountMap.removeValue(forKey: id)
            fileNameMap.removeValue(forKey: id)
            endLiveActivity(downloadId: id, status: "Cancelled")
        }
        activeTasks.removeAll()
    }

    func restorePendingTasks() {
        backgroundSession.getAllTasks { [weak self] tasks in
            guard let self = self else { return }
            for task in tasks {
                if let downloadTask = task as? URLSessionDownloadTask,
                   let desc = downloadTask.taskDescription {
                    let parts = desc.split(separator: "|", maxSplits: 1)
                    if parts.count == 2 {
                        let downloadId = String(parts[0])
                        let fileName = String(parts[1])
                        // Skip tasks already tracked from a fresh startDownload call
                        if self.activeTasks[downloadId] != nil { continue }
                        self.activeTasks[downloadId] = downloadTask
                        self.taskIdMap[downloadTask.taskIdentifier] = downloadId
                        self.sendEvent(type: "restored", downloadId: downloadId, data: ["fileName": fileName])
                    }
                }
            }
        }
    }

    private func sendEvent(type: String, downloadId: String, data: [String: Any]) {
        var event: [String: Any] = ["type": type, "downloadId": downloadId]
        event.merge(data) { (_, new) in new }
        if Thread.isMainThread {
            guard let sink = eventSink else {
                pendingEvents.append(event)
                return
            }
            sink(event)
        } else {
            DispatchQueue.main.async { [weak self] in
                guard let sink = self?.eventSink else {
                    self?.pendingEvents.append(event)
                    return
                }
                sink(event)
            }
        }
    }

    private func sendProgress(downloadId: String, received: Int64, total: Int64) {
        sendEvent(type: "progress", downloadId: downloadId, data: [
            "received": received,
            "total": total,
            "progress": total > 0 ? Double(received) / Double(total) : 0.0
        ])
    }

    // MARK: - Live Activities

    func startLiveActivity(downloadId: String, fileName: String) {
        guard #available(iOS 16.2, *), liveActivityEnabled else { return }
        fileNameMap[downloadId] = fileName
        let attributes = DownloadActivityAttributes(downloadId: downloadId)
        let state = DownloadActivityAttributes.ContentState(
            fileName: fileName,
            receivedBytes: 0,
            totalBytes: 0,
            progress: 0,
            status: "Downloading..."
        )
        let content = ActivityContent(state: state, staleDate: nil)
        do {
            let activity = try Activity.request(
                attributes: attributes,
                content: content,
                pushType: nil
            )
            liveActivities[downloadId] = activity
        } catch {
            debugPrint("Failed to start Live Activity: \(error)")
        }
    }

    func updateLiveActivity(downloadId: String, received: Int64, total: Int64) {
        guard #available(iOS 16.2, *),
              let activity = liveActivities[downloadId] else { return }
        let fileName = fileNameMap[downloadId] ?? "Download"
        let state = DownloadActivityAttributes.ContentState(
            fileName: fileName,
            receivedBytes: received,
            totalBytes: total,
            progress: total > 0 ? Double(received) / Double(total) : 0,
            status: total > 0 ? "\(Int(Double(received) / Double(total) * 100))%" : "Downloading..."
        )
        Task {
            await activity.update(using: state)
        }
    }

    func endLiveActivity(downloadId: String, status: String) {
        guard #available(iOS 16.2, *),
              let activity = liveActivities.removeValue(forKey: downloadId) else { return }

        if let current = activity.content.state as? DownloadActivityAttributes.ContentState {
            let finalState = DownloadActivityAttributes.ContentState(
                fileName: current.fileName,
                receivedBytes: current.receivedBytes,
                totalBytes: current.totalBytes,
                progress: current.progress,
                status: status
            )
            Task {
                await activity.end(using: finalState, dismissalPolicy: .after(Date.now.addingTimeInterval(4)))
            }
        } else {
            Task {
                await activity.end(dismissalPolicy: .after(Date.now.addingTimeInterval(4)))
            }
        }
    }

    private func updateLiveActivityFileName(downloadId: String, fileName: String) {
        guard #available(iOS 16.2, *),
              let activity = liveActivities[downloadId] else { return }
        let current = activity.content.state as? DownloadActivityAttributes.ContentState
        let state = DownloadActivityAttributes.ContentState(
            fileName: fileName,
            receivedBytes: current?.receivedBytes ?? 0,
            totalBytes: current?.totalBytes ?? 0,
            progress: current?.progress ?? 0,
            status: current?.status ?? "Downloading..."
        )
        Task {
            await activity.update(using: state)
        }
    }

    func endAllLiveActivities() {
        guard #available(iOS 16.2, *), liveActivityEnabled else { return }
        for (_, activity) in liveActivities {
            Task {
                await activity.end(dismissalPolicy: .immediate)
            }
        }
        liveActivities.removeAll()
    }
}

extension DownloadManager: URLSessionDownloadDelegate {
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        guard let downloadId = taskIdMap[downloadTask.taskIdentifier] else { return }
        progressMap[downloadId] = (totalBytesWritten, totalBytesExpectedToWrite)
        sendProgress(downloadId: downloadId, received: totalBytesWritten, total: totalBytesExpectedToWrite)
        updateLiveActivity(downloadId: downloadId, received: totalBytesWritten, total: totalBytesExpectedToWrite)
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        guard let downloadId = taskIdMap[downloadTask.taskIdentifier],
              let desc = downloadTask.taskDescription else { return }
        let parts = desc.split(separator: "|", maxSplits: 1)
        guard parts.count == 2 else { return }
        let fileName = String(parts[1])

        let destinationDir: URL
        if let customDir = saveDirMap[downloadId] {
            destinationDir = URL(fileURLWithPath: customDir)
        } else if let persistentURL = persistentFolderURL {
            destinationDir = persistentURL
        } else {
            let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            destinationDir = documentsDir.appendingPathComponent("DirXplore", isDirectory: true)
        }
        try? FileManager.default.createDirectory(at: destinationDir, withIntermediateDirectories: true)
        let destinationUrl = destinationDir.appendingPathComponent(fileName)

        try? FileManager.default.removeItem(at: destinationUrl)
        do {
            try FileManager.default.moveItem(at: location, to: destinationUrl)
            sendEvent(type: "completed", downloadId: downloadId, data: [
                "fileName": fileName,
                "savePath": destinationUrl.path
            ])
            endLiveActivity(downloadId: downloadId, status: "Complete")
        } catch {
            sendEvent(type: "error", downloadId: downloadId, data: ["message": "Failed to move file: \(error.localizedDescription)"])
            endLiveActivity(downloadId: downloadId, status: "Failed")
        }

        activeTasks.removeValue(forKey: downloadId)
        taskIdMap.removeValue(forKey: downloadTask.taskIdentifier)
        progressMap.removeValue(forKey: downloadId)
        retryCountMap.removeValue(forKey: downloadId)
        resumeDataMap.removeValue(forKey: downloadId)
        fileNameMap.removeValue(forKey: downloadId)
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let downloadId = taskIdMap[task.taskIdentifier] else { return }
        if let error = error as NSError? {
            if error.code == NSURLErrorCancelled {
                if resumeDataMap[downloadId] == nil {
                    sendEvent(type: "cancelled", downloadId: downloadId, data: [:])
                    endLiveActivity(downloadId: downloadId, status: "Cancelled")
                }
            } else if error.domain == NSURLErrorDomain && error.userInfo[NSURLSessionDownloadTaskResumeData] != nil {
                let resumeData = error.userInfo[NSURLSessionDownloadTaskResumeData] as? Data
                if let data = resumeData {
                    resumeDataMap[downloadId] = data
                    sendEvent(type: "paused", downloadId: downloadId, data: ["resumable": true])
                    endLiveActivity(downloadId: downloadId, status: "Paused")
                } else {
                    sendEvent(type: "error", downloadId: downloadId, data: ["message": error.localizedDescription])
                    endLiveActivity(downloadId: downloadId, status: "Failed")
                }
            } else {
                let attempt = retryCountMap[downloadId] ?? 0
                if attempt < maxRetries, let downloadUrl = downloadUrlMap[downloadId] {
                    retryCountMap[downloadId] = attempt + 1
                    let parts = downloadId.split(separator: "|")
                    let fileName = parts.last ?? "file"
                    let delay = Double(1 << attempt)
                    debugPrint("Retrying download \(downloadId) in \(delay)s (attempt \(attempt + 1)/\(maxRetries))")
                    DispatchQueue.global().asyncAfter(deadline: .now() + delay) { [weak self] in
                        guard let self = self, self.retryCountMap[downloadId] != nil else { return }
                        let resumeData = (error as NSError?)?.userInfo[NSURLSessionDownloadTaskResumeData] as? Data
                        let newTask: URLSessionDownloadTask
                        if let data = resumeData {
                            newTask = self.backgroundSession.downloadTask(withResumeData: data)
                        } else {
                            var request = URLRequest(url: URL(string: downloadUrl)!)
                            request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1", forHTTPHeaderField: "User-Agent")
                            newTask = self.backgroundSession.downloadTask(with: request)
                        }
                        newTask.taskDescription = task.taskDescription ?? "\(downloadId)|\(fileName)"
                        self.activeTasks[downloadId] = newTask
                        self.taskIdMap[newTask.taskIdentifier] = downloadId
                        newTask.resume()
                        self.sendEvent(type: "resumed", downloadId: downloadId, data: ["fileName": fileName])
                    }
                } else {
                    sendEvent(type: "error", downloadId: downloadId, data: ["message": error.localizedDescription])
                    endLiveActivity(downloadId: downloadId, status: "Failed")
                    retryCountMap.removeValue(forKey: downloadId)
                }
            }
        }
    }

    func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.backgroundCompletionHandler?()
            self.backgroundCompletionHandler = nil
        }
    }

}

extension DownloadManager: FlutterStreamHandler {
    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        self.eventSink = nil
        return nil
    }
}
