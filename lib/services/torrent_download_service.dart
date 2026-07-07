import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:dtorrent_task_v2/dtorrent_task_v2.dart';
import '../models/download_item.dart';
import '../models/proxy_model.dart';

class MetadataResult {
  final String name;
  final String infoHash;
  final List<String> trackers;
  final List<TorrentFileModel> files;
  final int totalSize;
  final Uint8List metadataBytes;

  MetadataResult({
    required this.name,
    required this.infoHash,
    required this.trackers,
    required this.files,
    required this.totalSize,
    required this.metadataBytes,
  });
}

class ActiveTorrentDownload {
  final DownloadItem item;
  final TorrentTask task;
  Timer? _poller;
  bool _disposed = false;

  ActiveTorrentDownload({required this.item, required this.task});

  void startPolling(void Function(DownloadItem) onUpdate) {
    _poller = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_disposed) return;
      onUpdate(item);
    });
  }

  void stopPolling() {
    _disposed = true;
    _poller?.cancel();
    _poller = null;
  }

  bool get isDisposed => _disposed;
}

class TorrentDownloadService {
  final Map<String, ActiveTorrentDownload> _activeDownloads = {};

  static bool isMagnetLink(String input) {
    return input.trim().toLowerCase().startsWith('magnet:?xt=urn:btih:');
  }

  ProxyConfig? _buildProxyConfig(ProxyModel? activeProxy) {
    if (activeProxy == null) return null;
    if (activeProxy.protocol != ProxyProtocol.SOCKS5) return null;

    return ProxyConfig.socks5(
      host: activeProxy.host,
      port: activeProxy.port,
      username: activeProxy.username,
      password: activeProxy.password,
    );
  }

  Future<MetadataResult?> fetchMetadata(String magnetLink) async {
    try {
      final magnet = MagnetParser.parse(magnetLink);
      if (magnet == null) return null;

      final metadataDownloader = MetadataDownloader.fromMagnet(magnetLink);
      final completer = Completer<Uint8List?>();

      metadataDownloader.events.on<MetaDataDownloadComplete>((event) {
        if (!completer.isCompleted) {
          completer.complete(Uint8List.fromList(event.data));
        }
      });
      metadataDownloader.events.on<MetaDataDownloadFailed>((event) {
        if (!completer.isCompleted) {
          completer.completeError(Exception(event.error));
        }
      });

      await metadataDownloader.startDownload();
      final bytes = await completer.future
          .timeout(const Duration(seconds: 30), onTimeout: () => null);

      if (bytes == null) return null;

      final model = TorrentParser.parseBytes(bytes);
      final files = model.files;
      final totalSize = model.totalSize;
      final trackers = model.announces.map((u) => u.toString()).toList();

      return MetadataResult(
        name: model.name,
        infoHash: magnet.infoHashString,
        trackers: trackers,
        files: files,
        totalSize: totalSize,
        metadataBytes: bytes,
      );
    } catch (e) {
      debugPrint('Torrent metadata fetch error: $e');
      return null;
    }
  }

  Future<void> startDownload({
    required DownloadItem item,
    required Uint8List metadataBytes,
    required List<int> selectedFileIndices,
    ProxyModel? activeProxy,
    required void Function(DownloadItem) onProgress,
    required void Function(DownloadItem) onComplete,
    required void Function(DownloadItem, String) onError,
  }) async {
    try {
      final model = TorrentParser.parseBytes(metadataBytes);
      final task = TorrentTask.newTask(
        model,
        item.savePath,
        false,
        null,
        null,
        null,
        _buildProxyConfig(activeProxy),
      );

      task.events.on<TaskCompleted>((event) {
        item.status = DownloadStatus.done;
        item.speedBytesPerSec = 0;
        item.etaSeconds = 0;
        item.downloadedBytes = item.totalBytes;
        onComplete(item);
        final active = _activeDownloads[item.id];
        active?.stopPolling();
        _activeDownloads.remove(item.id);
      });

      if (selectedFileIndices.isNotEmpty) {
        final priorities = <int, FilePriority>{};
        for (var i = 0; i < model.files.length; i++) {
          priorities[i] = selectedFileIndices.contains(i)
              ? FilePriority.normal
              : FilePriority.skip;
        }
        task.setFilePriorities(priorities);
      }

      final active = ActiveTorrentDownload(item: item, task: task);
      _activeDownloads[item.id] = active;

      active.startPolling((_) {
        final progress = task.progress;
        final dlSpeed = task.currentDownloadSpeed;
        final ulSpeed = task.uploadSpeed;
        final peers = task.connectedPeersNumber;
        final seeders = task.seederNumber;

        item.downloadedBytes = (progress * item.totalBytes).round();
        item.speedBytesPerSec = dlSpeed;
        item.uploadSpeedBytesPerSec = ulSpeed;
        item.peers = peers;
        item.seeders = seeders;

        if (dlSpeed > 0 && item.totalBytes > 0) {
          final remaining = item.totalBytes - item.downloadedBytes;
          item.etaSeconds = (remaining / dlSpeed).round();
        }

        if (progress >= 1.0 && item.status != DownloadStatus.done) {
          item.status = DownloadStatus.done;
          item.downloadedBytes = item.totalBytes;
          item.speedBytesPerSec = 0;
          item.etaSeconds = 0;
          onComplete(item);
          active.stopPolling();
          _activeDownloads.remove(item.id);
          return;
        }

        onProgress(item);
      });

      await task.start();
    } catch (e) {
      debugPrint('Torrent start error: $e');
      onError(item, e.toString());
      _activeDownloads.remove(item.id);
    }
  }

  void pauseDownload(String id) {
    final active = _activeDownloads[id];
    if (active != null && !active.isDisposed) {
      active.task.pause();
    }
  }

  void resumeDownload(String id) {
    final active = _activeDownloads[id];
    if (active != null && !active.isDisposed) {
      active.task.resume();
    }
  }

  Future<void> stopDownload(String id) async {
    final active = _activeDownloads[id];
    if (active != null) {
      active.stopPolling();
      await active.task.stop();
      _activeDownloads.remove(id);
    }
  }

  String extractHash(String magnet) {
    final parsed = MagnetParser.parse(magnet);
    return parsed?.infoHashString ?? 'unknown';
  }

  String? extractNameFromMagnet(String magnet) {
    final parsed = MagnetParser.parse(magnet);
    return parsed?.displayName;
  }

  void dispose() {
    for (final active in _activeDownloads.values) {
      active.stopPolling();
      active.task.stop();
    }
    _activeDownloads.clear();
  }
}
