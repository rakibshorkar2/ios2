import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';
import 'dart:io';
import '../providers/download_provider.dart';
import '../providers/app_state.dart';
import '../services/dio_client.dart';
import '../services/haptic_service.dart';
import '../services/torrent_download_service.dart';

class NewDownloadSheet extends StatefulWidget {
  const NewDownloadSheet({super.key});

  @override
  State<NewDownloadSheet> createState() => _NewDownloadSheetState();
}

class _NewDownloadSheetState extends State<NewDownloadSheet> {
  final _urlController = TextEditingController();
  final _filenameController = TextEditingController();
  bool _isLoading = false;
  String? _error;

  bool _infoFetched = false;
  int _fileSize = -1;
  String _fileType = '';
  bool _resumeSupported = false;
  String _detectedFileName = '';

  bool _isMagnet = false;
  MetadataResult? _metadataResult;
  Set<int> _selectedFileIndices = {};

  @override
  void dispose() {
    _urlController.dispose();
    _filenameController.dispose();
    super.dispose();
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null && data!.text!.isNotEmpty) {
      _urlController.text = data.text!.trim();
      if (_infoFetched || _isMagnet) {
        setState(() {
          _infoFetched = false;
          _isMagnet = false;
          _error = null;
          _metadataResult = null;
        });
      }
    }
  }

  String? _validateUrl(String url) {
    if (url.isEmpty) return 'Please enter a URL';
    final trimmed = url.trim();

    if (TorrentDownloadService.isMagnetLink(trimmed)) return null;

    final uri = Uri.tryParse(trimmed);
    if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
      return 'Invalid URL format';
    }
    if (uri.scheme != 'http' && uri.scheme != 'https') {
      return 'Only HTTP, HTTPS, and Magnet links are supported';
    }
    return null;
  }

  String _fileNameFromUrl(String url) {
    final uri = Uri.parse(url);
    final path = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    if (path.isNotEmpty) {
      return path.last;
    }
    return 'download';
  }

  String _fileNameFromContentDisposition(String? disposition) {
    if (disposition == null) return '';
    final match = RegExp(
      r"filename\*?=(?:UTF-8''\s*)?([^;\s]+)",
    ).firstMatch(disposition);
    if (match != null) {
      return Uri.decodeComponent(
        match.group(1)!.trim().replaceAll(RegExp(r'^"|"$'), ''),
      );
    }
    return '';
  }

  String _formatFileSize(int bytes) {
    if (bytes <= 0) return 'Unknown';
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    var i = (log(bytes) / log(1024)).floor();
    return '${(bytes / pow(1024, i)).toStringAsFixed(1)} ${suffixes[i]}';
  }

  Future<bool> _tryHeadRequest(String url) async {
    try {
      final dio = DioClient().dio;
      final response = await dio.head(url);
      _parseHeaders(response.headers);
      return true;
    } on DioException catch (e) {
      if (e.type == DioExceptionType.badResponse &&
          e.response?.statusCode == 405) {
        return false;
      }
      rethrow;
    }
  }

  Future<void> _tryGetFallback(String url) async {
    final dio = DioClient().dio;
    final response = await dio.get(
      url,
      options: Options(
        responseType: ResponseType.stream,
        followRedirects: true,
        headers: {'Range': 'bytes=0-0'},
      ),
    );
    _parseHeaders(response.headers);
    if (_fileSize <= 0) {
      final contentRange = response.headers.value(HttpHeaders.contentRangeHeader);
      if (contentRange != null) {
        final match = RegExp(r'/(\d+)$').firstMatch(contentRange);
        if (match != null) {
          _fileSize = int.tryParse(match.group(1)!) ?? -1;
        }
      }
    }
  }

  void _parseHeaders(Headers headers) {
    final contentLength = headers.value(HttpHeaders.contentLengthHeader);
    final contentType = headers.value(HttpHeaders.contentTypeHeader);
    final contentDisposition = headers.value('content-disposition');
    final acceptRanges = headers.value(HttpHeaders.acceptRangesHeader);

    _fileSize = int.tryParse(contentLength ?? '') ?? -1;
    _fileType = contentType?.split(';').first ?? 'Unknown';
    _resumeSupported = acceptRanges?.toLowerCase() == 'bytes';

    String fileName = _filenameController.text.trim();
    if (fileName.isEmpty) {
      fileName = _fileNameFromContentDisposition(contentDisposition);
    }
    if (fileName.isEmpty) {
      fileName = _fileNameFromUrl(_urlController.text.trim());
    }
    _detectedFileName = fileName;
  }

  Future<void> _fetchInfo() async {
    final url = _urlController.text.trim();
    final validationError = _validateUrl(url);
    if (validationError != null) {
      setState(() => _error = validationError);
      return;
    }

    if (TorrentDownloadService.isMagnetLink(url)) {
      await _handleMagnetLink(url);
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
      _infoFetched = false;
      _isMagnet = false;
    });

    try {
      HapticService.medium();
      final headOk = await _tryHeadRequest(url);
      if (!headOk) {
        await _tryGetFallback(url);
      }

      if (_filenameController.text.trim().isNotEmpty) {
        _detectedFileName = _filenameController.text.trim();
      }
      if (_detectedFileName.isEmpty) {
        _detectedFileName = _fileNameFromUrl(url);
      }
      if (_filenameController.text.trim().isEmpty) {
        _filenameController.text = _detectedFileName;
      }

      if (!mounted) return;
      setState(() {
        _infoFetched = true;
        _isLoading = false;
      });
    } on DioException catch (e) {
      if (mounted) {
        setState(() {
          _error = _dioErrorToString(e);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to fetch file info: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleMagnetLink(String magnetLink) async {
    setState(() {
      _isLoading = true;
      _error = null;
      _isMagnet = true;
      _infoFetched = false;
      _metadataResult = null;
    });

    try {
      HapticService.medium();
      final dlProvider = context.read<DownloadProvider>();
      final result = await dlProvider.torrentService.fetchMetadata(magnetLink);

      if (!mounted) return;

      if (result == null) {
        setState(() {
          _error = 'Failed to fetch torrent metadata. The magnet link may be invalid or timed out.';
          _isLoading = false;
          _isMagnet = false;
        });
        return;
      }

      setState(() {
        _metadataResult = result;
        _selectedFileIndices = Set.from(List.generate(result.files.length, (i) => i));
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to fetch torrent metadata: $e';
          _isLoading = false;
          _isMagnet = false;
        });
      }
    }
  }

  Future<void> _startDownload() async {
    final url = _urlController.text.trim();
    final fileName = _filenameController.text.trim();

    if (_isMagnet && _metadataResult != null) {
      final dlProvider = context.read<DownloadProvider>();
      final appState = context.read<AppState>();

      await dlProvider.addTorrentDownload(
        magnetLink: url,
        torrentName: _metadataResult!.name,
        infoHash: _metadataResult!.infoHash,
        saveDir: appState.defaultSavePath,
        metadataBytes: _metadataResult!.metadataBytes,
        selectedFileIndices: _selectedFileIndices.toList()..sort(),
        totalSize: _metadataResult!.totalSize,
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Added torrent: ${_metadataResult!.name}')),
        );
      }
      return;
    }

    if (!mounted) return;
    final appState = context.read<AppState>();
    final dlProvider = context.read<DownloadProvider>();
    await dlProvider.addDownload(url, fileName, appState.defaultSavePath);
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Added: $fileName')),
      );
    }
  }

  String _dioErrorToString(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
        return 'Connection timed out';
      case DioExceptionType.receiveTimeout:
        return 'Server is not responding';
      case DioExceptionType.badResponse:
        return 'Server error: ${e.response?.statusCode ?? 'Unknown'}';
      case DioExceptionType.connectionError:
        return 'Could not connect to server';
      default:
        return 'Network error: ${e.message ?? 'Unknown error'}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.only(bottom: bottomInset),
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        color: cs.surface.withValues(alpha: 0.97),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: cs.onSurface.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('New Download',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    )),
            const SizedBox(height: 20),
            TextField(
              controller: _urlController,
              decoration: InputDecoration(
                labelText: 'URL or Magnet Link',
                hintText: 'https://example.com/file.zip or magnet:?...',
                prefixIcon: const Icon(Icons.link),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                errorText: _error,
              ),
              keyboardType: TextInputType.url,
              textInputAction: TextInputAction.next,
              autocorrect: false,
              onChanged: (_) {
                if (_infoFetched || _isMagnet) {
                  setState(() {
                    _infoFetched = false;
                    _isMagnet = false;
                    _error = null;
                    _metadataResult = null;
                  });
                }
              },
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                icon: const Icon(Icons.content_paste, size: 18),
                label: const Text('Paste from Clipboard'),
                onPressed: _pasteFromClipboard,
              ),
            ),
            if (!_isMagnet) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _filenameController,
                decoration: InputDecoration(
                  labelText: 'Filename',
                  hintText: 'Auto-detected from URL',
                  prefixIcon: const Icon(Icons.description),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                textInputAction: TextInputAction.next,
                onChanged: (_) {
                  if (_infoFetched) {
                    setState(() => _infoFetched = false);
                  }
                },
              ),
            ],
            if (_infoFetched && !_isMagnet) ...[
              const SizedBox(height: 16),
              _buildFileInfoCard(cs),
            ],
            if (_isMagnet && _metadataResult != null) ...[
              const SizedBox(height: 16),
              _buildTorrentInfoCard(cs),
            ],
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: _isLoading
                      ? FilledButton.icon(
                          onPressed: null,
                          icon: const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          ),
                          label: Text(_isMagnet ? 'Fetching Metadata...' : 'Fetching...'),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        )
                      : (_infoFetched || (_isMagnet && _metadataResult != null))
                          ? FilledButton.icon(
                              onPressed: _startDownload,
                              icon: Icon(_isMagnet ? Icons.download_rounded : Icons.download_rounded),
                              label: Text(_isMagnet ? 'Download Torrent' : 'Download'),
                              style: FilledButton.styleFrom(
                                backgroundColor: Colors.green,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            )
                          : FilledButton.icon(
                              onPressed: _fetchInfo,
                              icon: const Icon(Icons.search),
                              label: const Text('Fetch Info'),
                              style: FilledButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFileInfoCard(ColorScheme cs) {
    final icon = _resumeSupported ? Icons.replay : Icons.block;
    final iconColor = _resumeSupported ? Colors.green : cs.error;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.primaryContainer.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: cs.primary.withValues(alpha: 0.15),
        ),
      ),
      child: Column(
        children: [
          _infoRow(Icons.description, 'Filename', _detectedFileName, cs),
          const Divider(height: 16),
          _infoRow(
            Icons.storage,
            'Size',
            _fileSize > 0 ? _formatFileSize(_fileSize) : 'Unknown',
            cs,
          ),
          const Divider(height: 16),
          _infoRow(Icons.insert_drive_file, 'Type', _fileType, cs),
          const Divider(height: 16),
          _infoRow(
            icon,
            'Resume Support',
            _resumeSupported ? 'Yes' : 'No',
            cs,
            valueColor: iconColor,
          ),
        ],
      ),
    );
  }

  Widget _buildTorrentInfoCard(ColorScheme cs) {
    final meta = _metadataResult!;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.primaryContainer.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: cs.primary.withValues(alpha: 0.15),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _infoRow(Icons.movie, 'Torrent Name', meta.name, cs),
          const Divider(height: 16),
          _infoRow(Icons.fingerprint, 'Info Hash', meta.infoHash, cs),
          const Divider(height: 16),
          _infoRow(
            Icons.storage,
            'Total Size',
            _formatFileSize(meta.totalSize),
            cs,
          ),
          const Divider(height: 16),
          _infoRow(
            Icons.insert_drive_file,
            'Files',
            '${meta.files.length} file(s)',
            cs,
          ),
          if (meta.trackers.isNotEmpty) ...[
            const Divider(height: 16),
            _infoRow(
              Icons.dns,
              'Trackers',
              '${meta.trackers.length} tracker(s)',
              cs,
            ),
          ],
          const Divider(height: 16),
          Row(
            children: [
              Text('Select Files',
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface.withValues(alpha: 0.7),
                      fontSize: 13)),
              const Spacer(),
              TextButton(
                onPressed: () {
                  setState(() {
                    if (_selectedFileIndices.length == meta.files.length) {
                      _selectedFileIndices.clear();
                    } else {
                      _selectedFileIndices = Set.from(
                          List.generate(meta.files.length, (i) => i));
                    }
                  });
                },
                child: Text(
                  _selectedFileIndices.length == meta.files.length
                      ? 'Deselect All'
                      : 'Select All',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Container(
            constraints: const BoxConstraints(maxHeight: 160),
            decoration: BoxDecoration(
              border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.3)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: meta.files.length,
              itemBuilder: (context, index) {
                final file = meta.files[index];
                final isSelected = _selectedFileIndices.contains(index);
                return CheckboxListTile(
                  dense: true,
                  value: isSelected,
                  title: Text(
                    file.name,
                    style: const TextStyle(fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    _formatFileSize(file.length),
                    style: TextStyle(
                      fontSize: 10,
                      color: cs.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  onChanged: (val) {
                    setState(() {
                      if (val == true) {
                        _selectedFileIndices.add(index);
                      } else {
                        _selectedFileIndices.remove(index);
                      }
                    });
                  },
                  controlAffinity: ListTileControlAffinity.leading,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value, ColorScheme cs,
      {Color? valueColor}) {
    return Row(
      children: [
        Icon(icon, size: 18, color: cs.primary.withValues(alpha: 0.7)),
        const SizedBox(width: 10),
        Text(label,
            style: TextStyle(
                fontWeight: FontWeight.w600,
                color: cs.onSurface.withValues(alpha: 0.7),
                fontSize: 13)),
        const Spacer(),
        Flexible(
          child: Text(value,
              style: TextStyle(
                  color: valueColor ?? cs.onSurface,
                  fontSize: 13,
                  fontWeight: FontWeight.w500),
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }
}
