import Flutter
import Foundation

@available(iOS 16.0, *)
class TorrentPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
    private static let methodChannel = "com.dirxplore/torrent"
    private static let eventChannel = "com.dirxplore/torrent_events"

    static func register(with registrar: FlutterPluginRegistrar) {
        let messenger = registrar.messenger()
        let methodHandler = FlutterMethodChannel(
            name: methodChannel,
            binaryMessenger: messenger
        )
        let eventHandler = FlutterEventChannel(
            name: eventChannel,
            binaryMessenger: messenger
        )

        let instance = TorrentPlugin()
        methodHandler.setMethodCallHandler(instance.handle)
        eventHandler.setStreamHandler(instance)
    }

    // MARK: - FlutterStreamHandler

    func onListen(
        withArguments arguments: Any?,
        eventSink events: @escaping FlutterEventSink
    ) -> FlutterError? {
        TorrentManager.shared.setEventSink(events)
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        TorrentManager.shared.setEventSink(nil)
        return nil
    }

    // MARK: - Method Call Handler

    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as? [String: Any] ?? [:]
        let manager = TorrentManager.shared

        switch call.method {
        case "initialize":
            manager.initialize()
            result(nil)

        case "shutdown":
            manager.shutdown()
            result(nil)

        case "addMagnet":
            guard let id = args["id"] as? String,
                  let name = args["name"] as? String,
                  let magnet = args["magnet"] as? String,
                  let savePath = args["savePath"] as? String
            else {
                result(FlutterError(
                    code: "INVALID_ARGS",
                    message: "Missing required arguments for addMagnet",
                    details: nil
                ))
                return
            }
            let sequential = args["isSequential"] as? Bool ?? false
            manager.addMagnet(id: id, name: name, magnet: magnet, savePath: savePath, isSequential: sequential)
            result(nil)

        case "addTorrentFile":
            result(FlutterError(
                code: "NOT_IMPLEMENTED",
                message: "addTorrentFile not yet implemented",
                details: nil
            ))

        case "pauseTorrent":
            guard let id = args["id"] as? String else {
                result(FlutterError(code: "INVALID_ARGS", message: "Missing id", details: nil))
                return
            }
            manager.pauseTorrent(id)
            result(nil)

        case "resumeTorrent":
            guard let id = args["id"] as? String else {
                result(FlutterError(code: "INVALID_ARGS", message: "Missing id", details: nil))
                return
            }
            manager.resumeTorrent(id)
            result(nil)

        case "removeTorrent":
            guard let id = args["id"] as? String else {
                result(FlutterError(code: "INVALID_ARGS", message: "Missing id", details: nil))
                return
            }
            let deleteFiles = args["deleteFiles"] as? Bool ?? false
            manager.removeTorrent(id, deleteFiles: deleteFiles)
            result(nil)

        case "getAllTorrents":
            let torrents = manager.getAllTorrents()
            result(torrents)

        case "setSequentialDownload":
            guard let id = args["id"] as? String,
                  let enabled = args["enabled"] as? Bool
            else {
                result(FlutterError(code: "INVALID_ARGS", message: "Missing id or enabled", details: nil))
                return
            }
            manager.setSequential(id, enabled: enabled)
            result(nil)

        case "setDownloadLimit":
            let limit = args["bytesPerSecond"] as? Int ?? 0
            manager.setDownloadLimit(limit)
            result(nil)

        case "setUploadLimit":
            let limit = args["bytesPerSecond"] as? Int ?? 0
            manager.setUploadLimit(limit)
            result(nil)

        default:
            result(FlutterMethodNotImplemented)
        }
    }
}
