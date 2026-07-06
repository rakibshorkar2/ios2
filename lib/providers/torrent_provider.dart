import 'package:flutter/foundation.dart';
import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/services.dart';
import 'package:dtorrent_task_v2/dtorrent_task_v2.dart';
import '../models/torrent_item.dart';
import '../services/database_helper.dart';

class TorrentProvider with ChangeNotifier {
  final List<TorrentItem> _torrents = [];
  final Map<String, TorrentTask> _activeTasks = {};
  bool _isInitialized = false;

  List<TorrentItem> get torrents => _torrents;
  final List<String> _rssFeeds = [];
  List<String> get rssFeeds => _rssFeeds;

  double _downloadLimit = 0; // 0 = Unlimited
  double _uploadLimit = 0;

  static const MethodChannel _channel =
      MethodChannel('com.dirxplore/torrent');
  static const EventChannel _events =
      EventChannel('com.dirxplore/torrent_events');
  StreamSubscription<dynamic>? _eventSub;
  bool get _isIOS => Platform.isIOS;

  void setLimits(double dl, double ul) {
    _downloadLimit = dl;
    _uploadLimit = ul;
    if (_isIOS) {
      _channel.invokeMethod('setDownloadLimit', {'bytesPerSecond': dl.toInt()});
      _channel.invokeMethod('setUploadLimit', {'bytesPerSecond': ul.toInt()});
    }
    notifyListeners();
  }

  Future<void> init() async {
    if (_isInitialized) return;

    if (_isIOS) {
      await _initIOS();
    } else {
      final data = await DatabaseHelper().getTorrents();
      _torrents.clear();
      _torrents.addAll(data.map((json) => TorrentItem.fromJson(json)));
    }
    _isInitialized = true;
    notifyListeners();
  }

  Future<void> _initIOS() async {
    try {
      await _channel.invokeMethod('initialize');
      final list = await _channel.invokeMethod<List<dynamic>>('getAllTorrents');
      if (list != null) {
        for (final item in list) {
          if (item is Map) {
            _torrents.add(TorrentItem.fromJson(
              Map<String, dynamic>.from(item as Map),
            ));
          }
        }
      }
      _eventSub = _events.receiveBroadcastStream().listen(_handleNativeEvent);
    } catch (e) {
      debugPrint('Torrent iOS init error: $e');
    }
  }

  void _handleNativeEvent(dynamic event) {
    if (event is! Map) return;
    final map = Map<String, dynamic>.from(event);
    final id = map['id'] as String?;
    if (id == null) return;

    final index = _torrents.indexWhere((t) => t.id == id);
    if (index == -1) return;

    final item = _torrents[index];
    final state = map['state'] as String? ?? 'downloading';

    item.progress = (map['progress'] as num?)?.toDouble() ?? item.progress;
    item.downloadSpeed = (map['downloadSpeed'] as num?)?.toInt() ?? item.downloadSpeed;
    item.uploadSpeed = (map['uploadSpeed'] as num?)?.toInt() ?? item.uploadSpeed;
    item.downloaded = (map['downloaded'] as num?)?.toInt() ?? item.downloaded;
    item.totalSize = (map['totalSize'] as num?)?.toInt() ?? item.totalSize;
    item.eta = (map['eta'] as num?)?.toInt() ?? item.eta;
    item.peers = (map['peers'] as num?)?.toInt() ?? item.peers;
    item.seeds = (map['seeds'] as num?)?.toInt() ?? item.seeds;
    item.speed = _formatSpeed(item.downloadSpeed);
    item.ratio = (map['ratio'] as num?)?.toDouble() ?? item.ratio;

    switch (state) {
      case 'completed':
        item.status = TorrentStatus.completed;
        break;
      case 'paused':
        item.status = TorrentStatus.paused;
        break;
      case 'seeding':
        item.status = TorrentStatus.seeding;
        break;
      case 'error':
        item.status = TorrentStatus.error;
        break;
      default:
        item.status = TorrentStatus.downloading;
    }

    notifyListeners();
  }

  String _formatSpeed(int bytesPerSecond) {
    if (bytesPerSecond >= 1024 * 1024) {
      return '${(bytesPerSecond / (1024 * 1024)).toStringAsFixed(1)} MB/s';
    } else if (bytesPerSecond >= 1024) {
      return '${(bytesPerSecond / 1024).toStringAsFixed(0)} KB/s';
    }
    return '$bytesPerSecond B/s';
  }

  Future<Uint8List?> fetchMetadata(String magnet) async {
    try {
      final metadataDownloader = MetadataDownloader.fromMagnet(magnet);
      final completer = Completer<Uint8List?>();

      metadataDownloader.events.on<MetaDataDownloadComplete>((event) {
        if (!completer.isCompleted) completer.complete(Uint8List.fromList(event.data));
      });
      metadataDownloader.events.on<MetaDataDownloadFailed>((event) {
        if (!completer.isCompleted) completer.completeError(event.error);
      });

      await metadataDownloader.startDownload();
      // Timeout after 30 seconds if no metadata
      return await completer.future.timeout(const Duration(seconds: 30), onTimeout: () => null);
    } catch (e) {
      debugPrint('Error fetching metadata: $e');
      return null;
    }
  }

  Future<void> addTorrent(
      String name, String magnet, String savePath, String size,
      {bool isSequential = false, Uint8List? metadata}) async {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final hash = _extractHash(magnet);

    final newItem = TorrentItem(
      id: id,
      name: name,
      hash: hash,
      magnetLink: magnet,
      savePath: savePath,
      size: size,
      status: TorrentStatus.downloading,
      addedAt: DateTime.now(),
      isSequential: isSequential,
    );

    _torrents.insert(0, newItem);
    await DatabaseHelper().insertTorrent(newItem.toJson());
    notifyListeners();

    if (_isIOS) {
      _channel.invokeMethod('addMagnet', {
        'id': id,
        'name': name,
        'magnet': magnet,
        'savePath': savePath,
        'isSequential': isSequential,
      });
    } else {
      _initAndStartTask(newItem, metadata: metadata);
    }
  }

  String _extractHash(String magnet) {
    if (magnet.startsWith('magnet:?xt=urn:btih:')) {
      final xtMatch = RegExp(r'xt=urn:btih:([^&]+)').firstMatch(magnet);
      return xtMatch?.group(1) ?? 'unknown';
    }
    return 'unknown';
  }

  Future<void> _initAndStartTask(TorrentItem item, {Uint8List? metadata}) async {
    try {
      TorrentTask task;
      if (metadata != null) {
        final model = TorrentParser.parseBytes(metadata);
        task = TorrentTask.newTask(model, item.savePath, item.isSequential);
      } else if (item.magnetLink.isNotEmpty) {
        final metadataDownloader =
            MetadataDownloader.fromMagnet(item.magnetLink);

        // Wait for metadata to download via Events
        final completer = Completer<List<int>>();
        metadataDownloader.events.on<MetaDataDownloadComplete>((event) {
          if (!completer.isCompleted) completer.complete(event.data);
        });
        metadataDownloader.events.on<MetaDataDownloadFailed>((event) {
          if (!completer.isCompleted) completer.completeError(event.error);
        });

        await metadataDownloader.startDownload();
        final metadataBytes = await completer.future;
        final model = TorrentParser.parseBytes(Uint8List.fromList(metadataBytes));
        task = TorrentTask.newTask(model, item.savePath, item.isSequential);
      } else {
        throw UnimplementedError('File torrent creation not implemented');
      }

      // Listen for download completion
      task.events.on<TaskCompleted>((event) {
        final index = _torrents.indexWhere((t) => t.id == item.id);
        if (index != -1) {
          _torrents[index].progress = 1.0;
          _torrents[index].status = TorrentStatus.completed;
          _torrents[index].speed = '0 KB/s';
          DatabaseHelper().updateTorrent(_torrents[index].toJson());
          notifyListeners();
        }
      });

      _activeTasks[item.id] = task;
      await task.start();

      // We will need a timer here anyway to poll task speed and progress
      // since the Task API might not emit continuous stream events depending on version
      _startStatusPoller(item.id);
    } catch (e) {
      debugPrint('Error starting torrent task: \$e');
      final index = _torrents.indexWhere((t) => t.id == item.id);
      if (index != -1) {
        _torrents[index].status = TorrentStatus.error;
        notifyListeners();
      }
    }
  }

  void _startStatusPoller(String id) {
    Timer.periodic(const Duration(seconds: 1), (timer) {
      final task = _activeTasks[id];
      final index = _torrents.indexWhere((t) => t.id == id);

      if (task == null ||
          index == -1 ||
          _torrents[index].status == TorrentStatus.error) {
        timer.cancel();
        return;
      }

      final progress = task.progress;
      final speed = task.currentDownloadSpeed; // Bytes per second

      double currentSpeedMB = speed / (1024 * 1024);

      if (_downloadLimit > 0 && currentSpeedMB > _downloadLimit) {
        // Bandwidth limiting would happen in dtorrent_task_v2
      }

      _torrents[index].progress = progress;
      _torrents[index].speed = '${currentSpeedMB.toStringAsFixed(1)} MB/s';
      
      // Also check if task is completed
      if (progress >= 1.0 && _torrents[index].status != TorrentStatus.completed) {
        _torrents[index].status = TorrentStatus.completed;
      }
      
      notifyListeners();

      if ((progress * 100).toInt() % 10 == 0) {
        DatabaseHelper().updateTorrent(_torrents[index].toJson());
      }
    });
  }

  Future<String?> startStreaming(String id, {String? filePath}) async {
    if (_isIOS) return null;
    final task = _activeTasks[id];
    if (task == null) return null;

    try {
      await task.startStreaming();
      
      String targetPath;
      if (filePath != null) {
        targetPath = filePath;
      } else {
        // Find the first video file
        String? videoPath;
        for (var file in task.metaInfo.files) {
          final name = file.name.toLowerCase();
          if (name.endsWith('.mp4') || 
              name.endsWith('.mkv') || 
              name.endsWith('.avi') || 
              name.endsWith('.mov')) {
            videoPath = file.path;
            break;
          }
        }
        targetPath = videoPath ?? task.metaInfo.files.first.path;
      }
      
      // Default port for dtorrent_task_v2 is 9090
      return 'http://127.0.0.1:9090/${Uri.encodeComponent(targetPath)}'; 
    } catch (e) {
      debugPrint('Error starting stream: $e');
      return null;
    }
  }

  // Get all files for a task
  List<TorrentFileModel> getTaskFiles(String id) {
    if (_isIOS) return [];
    final task = _activeTasks[id];
    if (task == null) return [];
    return task.metaInfo.files;
  }

  List<dynamic> getPeers(String id) {
    if (_isIOS) return [];
    final task = _activeTasks[id];
    if (task == null) return [];
    return task.activePeers?.toList() ?? [];
  }

  // Helper to get tracker info if possible
  List<String> getTrackers(String id) {
    if (_isIOS) return [];
    // TorrentTask doesn't easily expose tracker list in a public way without deep access
    // For now return dummy or based on metainfo
    final task = _activeTasks[id];
    if (task == null) return [];
    return task.metaInfo.announces.map((e) => e.toString()).toList();
  }

  void pauseTorrent(String id) {
    if (_isIOS) {
      _channel.invokeMethod('pauseTorrent', {'id': id});
    } else {
      final task = _activeTasks[id];
      if (task != null) {
        task.pause();
      }
    }
    final index = _torrents.indexWhere((t) => t.id == id);
    if (index != -1) {
      _torrents[index].status = TorrentStatus.paused;
      _torrents[index].speed = '0 KB/s';
      DatabaseHelper().updateTorrent(_torrents[index].toJson());
      notifyListeners();
    }
  }

  void resumeTorrent(String id) async {
    final index = _torrents.indexWhere((t) => t.id == id);
    if (index != -1) {
      _torrents[index].status = TorrentStatus.downloading;

      if (_isIOS) {
        _channel.invokeMethod('resumeTorrent', {'id': id});
      } else if (_activeTasks.containsKey(id)) {
        final task = _activeTasks[id];
        if (task != null) {
          task.resume();
        }
        _startStatusPoller(id);
      } else {
        await _initAndStartTask(_torrents[index]);
      }

      DatabaseHelper().updateTorrent(_torrents[index].toJson());
      notifyListeners();
    }
  }

  void toggleSequential(String id) async {
    final index = _torrents.indexWhere((t) => t.id == id);
    if (index != -1) {
      final item = _torrents[index];
      item.isSequential = !item.isSequential;

      if (_isIOS) {
        _channel.invokeMethod('setSequentialDownload', {
          'id': id,
          'enabled': item.isSequential,
        });
      } else {
        // If task is active, we might need to restart it to change selector
        // dtorrent_task_v2 doesn't support changing selector on the fly easily
        final task = _activeTasks[id];
        if (task != null) {
          await task.stop();
          _activeTasks.remove(id);
          await _initAndStartTask(item);
        }
      }

      DatabaseHelper().updateTorrent(item.toJson());
      notifyListeners();
    }
  }

  void deleteTorrent(String id) async {
    if (_isIOS) {
      _channel.invokeMethod('removeTorrent', {'id': id, 'deleteFiles': false});
    } else {
      final task = _activeTasks[id];
      if (task != null) {
        await task.stop();
        _activeTasks.remove(id);
      }
    }
    _torrents.removeWhere((t) => t.id == id);
    DatabaseHelper().deleteTorrent(id);
    notifyListeners();
  }

  void addRSSFeed(String url) {
    if (!_rssFeeds.contains(url)) {
      _rssFeeds.add(url);
      notifyListeners();
    }
  }

  void removeRSSFeed(String url) {
    _rssFeeds.remove(url);
    notifyListeners();
  }

  Future<void> refreshRSSFeeds() async {
    // Simulation: Add a random torrent when refreshing
    if (_rssFeeds.isNotEmpty) {
      await addTorrent(
        'RSS Released Movie ${DateTime.now().second}',
        'magnet:?xt=urn:btih:rssMock${DateTime.now().millisecondsSinceEpoch}',
        '/storage/emulated/0/Download',
        '2.4 GB',
      );
    }
  }

  @override
  void dispose() {
    _eventSub?.cancel();
    if (_isIOS) {
      _channel.invokeMethod('shutdown');
    } else {
      for (var task in _activeTasks.values) {
        task.stop();
      }
      _activeTasks.clear();
    }
    super.dispose();
  }
}
