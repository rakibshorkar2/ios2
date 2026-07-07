enum DownloadStatus { queued, downloading, paused, error, done }

enum DownloadType { http, torrent }

class DownloadItem {
  final String id;
  final String url;
  final String fileName;
  String savePath;
  String? batchId;
  String? batchName;
  DownloadStatus status;
  int totalBytes;
  int downloadedBytes;
  double speedBytesPerSec;
  int etaSeconds;
  int retryCount;
  String? errorMessage;
  DateTime addedAt;

  // Torrent-specific fields
  final DownloadType downloadType;
  final String? torrentHash;
  final String? torrentMagnetLink;
  String? torrentName;
  int seeders;
  int peers;
  double uploadSpeedBytesPerSec;

  DownloadItem({
    required this.id,
    required this.url,
    required this.fileName,
    required this.savePath,
    this.batchId,
    this.batchName,
    this.status = DownloadStatus.queued,
    this.totalBytes = 0,
    this.downloadedBytes = 0,
    this.speedBytesPerSec = 0,
    this.etaSeconds = 0,
    this.retryCount = 0,
    this.errorMessage,
    DateTime? addedAt,
    this.downloadType = DownloadType.http,
    this.torrentHash,
    this.torrentMagnetLink,
    this.torrentName,
    this.seeders = 0,
    this.peers = 0,
    this.uploadSpeedBytesPerSec = 0,
  }) : addedAt = addedAt ?? DateTime.now();

  double get progress =>
      totalBytes > 0 ? (downloadedBytes / totalBytes).clamp(0.0, 1.0) : 0.0;

  bool get isTorrent => downloadType == DownloadType.torrent;

  String get statusLabel {
    switch (status) {
      case DownloadStatus.queued:
        return 'Queued';
      case DownloadStatus.downloading:
        return 'Downloading';
      case DownloadStatus.paused:
        return 'Paused';
      case DownloadStatus.error:
        return 'Error';
      case DownloadStatus.done:
        return 'Done';
    }
  }

  DownloadItem copyWith({
    DownloadStatus? status,
    int? totalBytes,
    int? downloadedBytes,
    double? speedBytesPerSec,
    int? etaSeconds,
    int? retryCount,
    String? errorMessage,
    int? seeders,
    int? peers,
    double? uploadSpeedBytesPerSec,
    String? torrentName,
  }) =>
      DownloadItem(
        id: id,
        url: url,
        fileName: fileName,
        savePath: savePath,
        batchId: batchId,
        batchName: batchName,
        status: status ?? this.status,
        totalBytes: totalBytes ?? this.totalBytes,
        downloadedBytes: downloadedBytes ?? this.downloadedBytes,
        speedBytesPerSec: speedBytesPerSec ?? this.speedBytesPerSec,
        etaSeconds: etaSeconds ?? this.etaSeconds,
        retryCount: retryCount ?? this.retryCount,
        errorMessage: errorMessage ?? this.errorMessage,
        addedAt: addedAt,
        downloadType: downloadType,
        torrentHash: torrentHash,
        torrentMagnetLink: torrentMagnetLink,
        torrentName: torrentName ?? this.torrentName,
        seeders: seeders ?? this.seeders,
        peers: peers ?? this.peers,
        uploadSpeedBytesPerSec: uploadSpeedBytesPerSec ?? this.uploadSpeedBytesPerSec,
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'url': url,
    'fileName': fileName,
    'savePath': savePath,
    'batchId': batchId,
    'batchName': batchName,
    'status': status.index,
    'totalBytes': totalBytes,
    'downloadedBytes': downloadedBytes,
    'retryCount': retryCount,
    'errorMessage': errorMessage,
    'addedAt': addedAt.toIso8601String(),
    'downloadType': downloadType.index,
    'torrentHash': torrentHash,
    'torrentMagnetLink': torrentMagnetLink,
    'torrentName': torrentName,
    'seeders': seeders,
    'peers': peers,
    'uploadSpeedBytesPerSec': uploadSpeedBytesPerSec,
  };

  factory DownloadItem.fromJson(Map<String, dynamic> json) {
    return DownloadItem(
      id: json['id'],
      url: json['url'],
      fileName: json['fileName'],
      savePath: json['savePath'],
      batchId: json['batchId'],
      batchName: json['batchName'],
      status: DownloadStatus.values[json['status'] ?? 0],
      totalBytes: json['totalBytes'] ?? 0,
      downloadedBytes: json['downloadedBytes'] ?? 0,
      retryCount: json['retryCount'] ?? 0,
      errorMessage: json['errorMessage'],
      addedAt: json['addedAt'] != null ? DateTime.parse(json['addedAt']) : null,
      downloadType: json['downloadType'] != null ? DownloadType.values[json['downloadType']] : DownloadType.http,
      torrentHash: json['torrentHash'],
      torrentMagnetLink: json['torrentMagnetLink'],
      torrentName: json['torrentName'],
      seeders: json['seeders'] ?? 0,
      peers: json['peers'] ?? 0,
      uploadSpeedBytesPerSec: (json['uploadSpeedBytesPerSec'] ?? 0).toDouble(),
    );
  }
}
