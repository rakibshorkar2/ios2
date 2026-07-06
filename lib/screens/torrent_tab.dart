import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:ui';
import '../providers/app_state.dart';
import '../providers/torrent_provider.dart';
import '../models/torrent_item.dart';
import '../services/torrent_service.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:dtorrent_task_v2/dtorrent_task_v2.dart';
import 'media_player_screen.dart';

class TorrentTab extends StatefulWidget {
  const TorrentTab({super.key});

  @override
  State<TorrentTab> createState() => _TorrentTabState();
}

class _TorrentTabState extends State<TorrentTab> with WidgetsBindingObserver {
  final TextEditingController _searchController = TextEditingController();
  List<TorrentSearchResult> _searchResults = [];
  bool _isLoadingSearch = false;
  String _sortBy = 'seeds';
  TorrentCategory _selectedCategory = TorrentCategory.all;
  Timer? _clipboardTimer;
  String _lastClipboard = '';
  bool get _isIOS => Platform.isIOS;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startClipboardMonitor();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _clipboardTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkClipboard();
    }
  }

  void _startClipboardMonitor() {
    _clipboardTimer?.cancel();
    _clipboardTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _checkClipboard();
    });
  }

  Future<void> _checkClipboard() async {
    final appState = Provider.of<AppState>(context, listen: false);
    if (!appState.monitorClipboardMagnet) return;

    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final text = data?.text ?? '';
      if (text.isEmpty || text == _lastClipboard) return;

      if (text.startsWith('magnet:?xt=urn:btih:')) {
        _lastClipboard = text;
        if (mounted) {
          _showMagnetDetectedDialog(text);
        }
      }
    } catch (_) {}
  }

  void _showMagnetDetectedDialog(String magnet) {
    showDialog(
      context: context,
      builder: (ctx) => _buildGlassDialog(
        title: 'Magnet Link Detected',
        icon: Icons.link_rounded,
        iconColor: Colors.green,
        customContent: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text('A magnet link was found in your clipboard. Would you like to add it to your downloads?',
              style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                  height: 1.4)),
        ),
        dialogActions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Ignore',
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6))),
          ),
          _glassButton(
            label: 'Add Torrent',
            onPressed: () {
              Navigator.pop(ctx);
              _handleNewTorrent(context, 'New Torrent', magnet, 'Unknown');
            },
          ),
        ],
      ),
    );
  }

  Widget _glassContainer({required Widget child, EdgeInsets? padding, EdgeInsets? margin, double blur = 20}) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.white.withValues(alpha: 0.3),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            padding: padding ?? const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.white.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(20),
            ),
            child: child,
          ),
        ),
      ),
    );
  }

  Widget _glassButton({required String label, required VoidCallback onPressed, Color? color}) {
    final cs = Theme.of(context).colorScheme;
    final btnColor = color ?? cs.primary;
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: btnColor.withValues(alpha: 0.2),
        foregroundColor: btnColor,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: btnColor.withValues(alpha: 0.3)),
        ),
      ),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
    );
  }

  Widget _buildGlassDialog({
    required String title,
    required IconData icon,
    required Color iconColor,
    Widget? customContent,
    List<Widget> dialogActions = const [],
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AlertDialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      contentPadding: EdgeInsets.zero,
      content: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.grey.shade900.withValues(alpha: 0.85)
                  : Colors.white.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.1)
                    : Colors.white.withValues(alpha: 0.5),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: iconColor.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, color: iconColor, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Text(title,
                        style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.3)),
                  ],
                ),
                const SizedBox(height: 16),
                if (customContent != null)
                  customContent
                else
                  const SizedBox.shrink(),
                if (dialogActions.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: dialogActions,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final tProvider = context.watch<TorrentProvider>();
    final isAmoled = appState.trueAmoledDark && Theme.of(context).brightness == Brightness.dark;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Container(
          decoration: BoxDecoration(
            color: isAmoled ? Colors.black : null,
            gradient: isAmoled
                ? null
                : LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Theme.of(context).colorScheme.surface,
                      Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest
                          .withValues(alpha: 0.8),
                    ],
                  ),
          ),
          child: NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) {
              return [
                SliverAppBar(
                  expandedHeight: 120,
                  floating: true,
                  pinned: true,
                  stretch: true,
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  flexibleSpace: FlexibleSpaceBar(
                    title: Text(
                      'Torrents',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5,
                      ),
                    ),
                    centerTitle: false,
                    titlePadding: const EdgeInsetsDirectional.only(start: 16, bottom: 16),
                    background: ClipRect(
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                        child: Container(
                          color: Theme.of(context)
                              .colorScheme
                              .surface
                              .withValues(alpha: 0.15),
                        ),
                      ),
                    ),
                  ),
                  actions: [
                    _buildStatusIcon(context, Icons.vpn_lock, 'VPN Active', Colors.green),
                    _buildStatusIcon(
                      context,
                      appState.torrentWifiOnly ? Icons.wifi : Icons.signal_cellular_alt,
                      appState.torrentWifiOnly ? 'Wi-Fi Only' : 'All Networks',
                      appState.torrentWifiOnly ? Colors.blue : Colors.orange,
                    ),
                    const SizedBox(width: 8),
                  ],
                ),
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _SliverAppBarDelegate(
                    Container(
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: Theme.of(context)
                                .colorScheme
                                .outlineVariant
                                .withValues(alpha: 0.15),
                            width: 0.5,
                          ),
                        ),
                      ),
                      child: ClipRRect(
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                          child: Container(
                            color: Theme.of(context)
                                .colorScheme
                                .surface
                                .withValues(alpha: 0.6),
                            child: TabBar(
                              tabs: const [
                                Tab(text: 'Search'),
                                Tab(text: 'Active'),
                              ],
                              labelColor: Theme.of(context).colorScheme.primary,
                              unselectedLabelColor: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.5),
                              indicatorColor: Theme.of(context).colorScheme.primary,
                              indicatorSize: TabBarIndicatorSize.label,
                              dividerColor: Colors.transparent,
                              labelStyle: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  letterSpacing: -0.3),
                              unselectedLabelStyle: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                  fontSize: 15,
                                  letterSpacing: -0.3),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ];
            },
            body: TabBarView(
              children: [
                _buildSearchTab(context, appState),
                _buildActiveTab(tProvider),
              ],
            ),
          ),
        ),
        floatingActionButton: Padding(
          padding: const EdgeInsets.only(bottom: 80),
          child: FloatingActionButton.extended(
            onPressed: () => _showAddTorrentDialog(context),
            icon: const Icon(Icons.link),
            label: const Text('Add Link'),
            backgroundColor: Theme.of(context)
                .colorScheme
                .primary
                .withValues(alpha: 0.25),
            foregroundColor: Theme.of(context).colorScheme.primary,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: BorderSide(
                color: Theme.of(context)
                    .colorScheme
                    .primary
                    .withValues(alpha: 0.3),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchTab(BuildContext context, AppState appState) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Expanded(child: _buildSearchBar(context, appState)),
              const SizedBox(width: 10),
              _buildProviderSelector(context, appState),
            ],
          ),
        ),
        _buildFilterHeader(),
        Expanded(child: _buildSearchResults()),
      ],
    );
  }

  Widget _buildFilterHeader() {
    return Column(
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              Icon(Icons.category_outlined, size: 13, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4)),
              const SizedBox(width: 8),
              ...TorrentCategory.values.map((cat) => _categoryChip(cat)),
            ],
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              Icon(Icons.sort_outlined, size: 13, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4)),
              const SizedBox(width: 8),
              _sortChip('Seeds', 'seeds'),
              _sortChip('Size', 'size'),
              _sortChip('Name', 'name'),
            ],
          ),
        ),
        const SizedBox(height: 4),
      ],
    );
  }

  Widget _categoryChip(TorrentCategory cat) {
    final isSelected = _selectedCategory == cat;
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(
          cat.name.toUpperCase(),
          style: TextStyle(
            fontSize: 10,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? cs.onPrimary : cs.onSurface.withValues(alpha: 0.6),
            letterSpacing: 0.5,
          ),
        ),
        selected: isSelected,
        onSelected: (val) {
          if (val) {
            setState(() => _selectedCategory = cat);
            if (_searchController.text.isNotEmpty) {
              _performSearch(_searchController.text, context.read<AppState>());
            }
          }
        },
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
        selectedColor: cs.primary,
        backgroundColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(
            color: isSelected
                ? cs.primary.withValues(alpha: 0.5)
                : cs.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
        showCheckmark: false,
      ),
    );
  }

  Widget _sortChip(String label, String key) {
    final isSelected = _sortBy == key;
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 10,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? cs.onPrimary : cs.onSurface.withValues(alpha: 0.6),
            letterSpacing: 0.5,
          ),
        ),
        selected: isSelected,
        onSelected: (val) {
          if (val) {
            setState(() {
              _sortBy = key;
              _sortResults();
            });
          }
        },
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
        selectedColor: cs.primary,
        backgroundColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(
            color: isSelected
                ? cs.primary.withValues(alpha: 0.5)
                : cs.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
        showCheckmark: false,
      ),
    );
  }

  int _parseSize(String size) {
    size = size.trim().toUpperCase();
    final n = double.tryParse(RegExp(r'[\d.]+').firstMatch(size)?.group(0) ?? '0') ?? 0;
    if (size.contains('TB')) return (n * 1024 * 1024 * 1024 * 1024).toInt();
    if (size.contains('GB')) return (n * 1024 * 1024 * 1024).toInt();
    if (size.contains('MB')) return (n * 1024 * 1024).toInt();
    if (size.contains('KB')) return (n * 1024).toInt();
    return n.toInt();
  }

  void _sortResults() {
    if (_searchResults.isEmpty) return;
    setState(() {
      if (_sortBy == 'seeds') {
        _searchResults.sort((a, b) =>
            (int.tryParse(b.seeds) ?? 0).compareTo(int.tryParse(a.seeds) ?? 0));
      } else if (_sortBy == 'size') {
        _searchResults.sort((a, b) => _parseSize(b.size).compareTo(_parseSize(a.size)));
      } else if (_sortBy == 'name') {
        _searchResults.sort((a, b) =>
            a.title.toLowerCase().compareTo(b.title.toLowerCase()));
      }
    });
  }

  Widget _buildActiveTab(TorrentProvider provider) {
    final activeList = provider.torrents
        .where((t) =>
            t.status != TorrentStatus.completed && t.status != TorrentStatus.error)
        .toList();

    if (activeList.isEmpty) {
      return _buildEmptyState('No active downloads', Icons.downloading);
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: activeList.length,
      itemBuilder: (context, index) =>
          _buildTorrentItem(context, activeList[index], provider),
    );
  }

  Widget _buildEmptyState(String msg, IconData icon) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 48, color: cs.primary.withValues(alpha: 0.4)),
          ),
          const SizedBox(height: 24),
          Text(
            msg,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: cs.onSurface.withValues(alpha: 0.5),
              fontSize: 15,
              fontWeight: FontWeight.w500,
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusIcon(BuildContext context, IconData icon, String tooltip, Color color) {
    return Tooltip(
      message: tooltip,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Icon(icon, color: color, size: 15),
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context, AppState appState) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          height: 48,
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.white.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.1)
                  : Colors.white.withValues(alpha: 0.4),
            ),
          ),
          child: TextField(
            controller: _searchController,
            style: TextStyle(fontSize: 14, color: cs.onSurface),
            decoration: InputDecoration(
              hintText: 'Search movies, TV shows...',
              hintStyle: TextStyle(
                color: cs.onSurface.withValues(alpha: 0.4),
                fontSize: 14,
              ),
              prefixIcon: Icon(Icons.search,
                  color: cs.primary.withValues(alpha: 0.6), size: 20),
              suffixIcon: _isLoadingSearch
                  ? Container(
                      padding: const EdgeInsets.all(14),
                      width: 20,
                      height: 20,
                      child: const CircularProgressIndicator(strokeWidth: 2))
                  : IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () => _searchController.clear(),
                    ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
            ),
            onSubmitted: (val) => _performSearch(val, appState),
          ),
        ),
      ),
    );
  }

  Widget _buildProviderSelector(BuildContext context, AppState appState) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.white.withValues(alpha: 0.5),
            child: IconButton(
              icon: const Icon(Icons.filter_list, size: 20),
              onPressed: () => _showProviderSelection(context, appState),
              tooltip: 'Select Providers',
            ),
          ),
        ),
      ),
    );
  }

  void _showProviderSelection(BuildContext context, AppState appState) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Container(
            height: MediaQuery.of(context).size.height * 0.7,
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.grey.shade900.withValues(alpha: 0.9)
                  : Colors.white.withValues(alpha: 0.9),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              border: Border(
                top: BorderSide(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.1)
                      : Colors.white.withValues(alpha: 0.5),
                ),
              ),
            ),
            child: Column(
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withValues(alpha: 0.2) : Colors.black.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                Text('Search Providers',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
                        letterSpacing: -0.3,
                        color: isDark ? Colors.white : Colors.black)),
                const SizedBox(height: 8),
                const Divider(height: 1),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    itemCount: TorrentSearchProvider.values.length,
                    separatorBuilder: (_, __) => Divider(
                      height: 1,
                      indent: 56,
                      color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.2),
                    ),
                    itemBuilder: (context, index) {
                      final p = TorrentSearchProvider.values[index];
                      final isSelected = appState.selectedTorrentProviders.contains(p);
                      return CheckboxListTile(
                        title: Text(p.name.toUpperCase(),
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                        value: isSelected,
                        onChanged: (val) => appState.toggleTorrentProvider(p),
                        activeColor: Theme.of(context).colorScheme.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _performSearch(String query, AppState appState) async {
    if (query.isEmpty) return;
    setState(() => _isLoadingSearch = true);

    final results = await TorrentService.searchAll(
      query,
      useProxy: appState.useProxyForTorrents,
      providers: appState.selectedTorrentProviders,
      category: _selectedCategory,
    );

    setState(() {
      _searchResults = results;
      _isLoadingSearch = false;
    });
  }

  Widget _buildSearchResults() {
    if (_searchResults.isEmpty && !_isLoadingSearch) {
      return _buildEmptyState('No torrents found. Try searching for something!', Icons.search_off);
    }
    final cs = Theme.of(context).colorScheme;
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final res = _searchResults[index];
        return _glassContainer(
          margin: const EdgeInsets.only(bottom: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      res.title,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        letterSpacing: -0.3,
                        color: cs.onSurface,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: cs.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: cs.primary.withValues(alpha: 0.2)),
                    ),
                    child: Text(
                      res.provider.toUpperCase(),
                      style: TextStyle(
                        fontSize: 9,
                        color: cs.primary,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _infoBadge(Icons.storage_outlined, res.size, cs.onSurface.withValues(alpha: 0.5)),
                  const SizedBox(width: 20),
                  _infoBadge(Icons.arrow_upward, res.seeds, Colors.green),
                  const SizedBox(width: 20),
                  _infoBadge(Icons.arrow_downward, res.peers, Colors.orange),
                ],
              ),
              const SizedBox(height: 14),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _actionButtonCompact(label: 'Magnet', icon: Icons.copy_rounded, color: cs.primary, onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: res.magnet));
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('Magnet link copied to clipboard'),
                            behavior: SnackBarBehavior.floating,
                            backgroundColor: cs.inverseSurface,
                          ),
                        );
                      }
                    }),
                    const SizedBox(width: 8),
                    _actionButtonCompact(label: 'Stream', icon: Icons.play_arrow_rounded, color: Colors.green, onPressed: () => _handleNewTorrent(context, res.title, res.magnet, res.size, autoStream: true)),
                    const SizedBox(width: 8),
                    _actionButtonCompact(label: 'VLC', icon: Icons.video_library_rounded, color: Colors.purple, onPressed: () => _handleExternalPlayerSearch(context, res.title, res.magnet)),
                    const SizedBox(width: 8),
                    _actionButtonCompact(label: '1DM', icon: Icons.download_rounded, color: Colors.orange, onPressed: () => _launchExternal(res.magnet)),
                    const SizedBox(width: 8),
                    _actionButtonCompact(label: 'Add', icon: Icons.add_rounded, color: cs.onSurface.withValues(alpha: 0.5), onPressed: () => _handleNewTorrent(context, res.title, res.magnet, res.size)),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _infoBadge(IconData icon, String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _actionButtonCompact({required String label, required IconData icon, required Color color, required VoidCallback onPressed}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 13, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _launchExternal(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      debugPrint('Could not launch $url');
    }
  }

  Future<void> _handleExternalPlayerSearch(BuildContext context, String title, String magnet) async {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Starting engine for external play...')));
    final provider = context.read<TorrentProvider>();
    final appState = context.read<AppState>();

    String? id;
    final existing = provider.torrents.where((t) => t.magnetLink == magnet).toList();
    if (existing.isNotEmpty) {
      id = existing.first.id;
    } else {
      await provider.addTorrent(title, magnet, appState.defaultSavePath, '0', isSequential: true);
      id = provider.torrents.first.id;
    }

    await Future.delayed(const Duration(seconds: 3));
    final url = await provider.startStreaming(id);
    if (url != null) {
      _launchExternal(url);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to start stream server.')));
      }
    }
  }

  void _handleNewTorrent(BuildContext context, String title, String magnet, String size, {bool autoStream = false}) {
    bool isSequential = autoStream;
    Uint8List? metadata;
    bool isFetchingMetadata = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => _buildGlassDialog(
          title: 'Add Torrent',
          icon: Icons.download_rounded,
          iconColor: Theme.of(context).colorScheme.primary,
          customContent: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
              const SizedBox(height: 20),
              _glassContainer(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: SwitchListTile(
                  title: const Text('Sequential Download', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                  subtitle: const Text('Stream while downloading', style: TextStyle(fontSize: 12)),
                  value: isSequential,
                  onChanged: (val) => setDialogState(() => isSequential = val),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const SizedBox(height: 16),
              if (isFetchingMetadata)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Column(
                      children: [
                        CircularProgressIndicator(strokeWidth: 3),
                        SizedBox(height: 12),
                        Text('Fetching metadata...',
                            style: TextStyle(fontSize: 13)),
                      ],
                    ),
                  ),
                )
              else
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      if (metadata != null) {
                        _showFileSelection(context, title, metadata!);
                        return;
                      }
                      setDialogState(() => isFetchingMetadata = true);
                      final fetched = await context
                          .read<TorrentProvider>()
                          .fetchMetadata(magnet);
                      if (context.mounted) {
                        setDialogState(() {
                          isFetchingMetadata = false;
                          metadata = fetched;
                        });
                        if (metadata != null) {
                          _showFileSelection(context, title, metadata!);
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Failed to fetch metadata. Check your connection.'),
                                behavior: SnackBarBehavior.floating),
                          );
                        }
                      }
                    },
                    icon: const Icon(Icons.list_rounded, size: 20),
                    label: const Text('Select Specific Files'),
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(
                          color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5),
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
            ],
          ),
          dialogActions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel',
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6))),
            ),
            _glassButton(
              label: autoStream ? 'Stream Now' : 'Add',
              onPressed: () async {
                final aState = context.read<AppState>();
                final provider = context.read<TorrentProvider>();
                await provider.addTorrent(title, magnet, aState.defaultSavePath, size,
                    isSequential: isSequential, metadata: metadata);

                if (context.mounted) {
                  Navigator.pop(ctx);
                  if (autoStream) {
                    final item = provider.torrents.firstWhere((t) => t.magnetLink == magnet);
                    _handleStream(context, item.id, item.name);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Torrent added successfully'),
                          behavior: SnackBarBehavior.floating),
                    );
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showFileSelection(BuildContext context, String title, Uint8List metadata) {
    final model = TorrentParser.parseBytes(metadata);
    final files = model.files;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selected = List.filled(files.length, true);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) => ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
            child: Container(
              height: MediaQuery.of(context).size.height * 0.7,
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.grey.shade900.withValues(alpha: 0.9)
                    : Colors.white.withValues(alpha: 0.9),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                border: Border(
                  top: BorderSide(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.1)
                        : Colors.white.withValues(alpha: 0.5),
                  ),
                ),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withValues(alpha: 0.2) : Colors.black.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text('Select Files',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, letterSpacing: -0.5)),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 24),
                    child: Text(
                      title,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      itemCount: files.length,
                      itemBuilder: (context, i) {
                        final file = files[i];
                        final isVideo = file.name.toLowerCase().endsWith('.mp4') ||
                            file.name.toLowerCase().endsWith('.mkv') ||
                            file.name.toLowerCase().endsWith('.avi');
                        return CheckboxListTile(
                          title: Text(file.name, style: const TextStyle(fontSize: 14)),
                          secondary: Icon(
                            isVideo ? Icons.video_file_rounded : Icons.insert_drive_file_rounded,
                            color: isVideo ? Colors.blue : Colors.grey),
                          subtitle: Text(TorrentService.formatBytes(file.length),
                              style: const TextStyle(fontSize: 12)),
                          value: selected[i],
                          onChanged: (val) => setSheetState(() => selected[i] = val ?? true),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: SizedBox(
                      width: double.infinity,
                      child: _glassButton(
                        label: 'Confirm Selection (${selected.where((s) => s).length} files)',
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTorrentItem(BuildContext context, TorrentItem t, TorrentProvider provider) {
    final isDownloading = t.status == TorrentStatus.downloading;
    final isPaused = t.status == TorrentStatus.paused;
    final isCompleted = t.status == TorrentStatus.completed;
    final cs = Theme.of(context).colorScheme;

    Color statusColor = cs.primary;
    if (isCompleted) statusColor = Colors.green;
    if (isPaused) statusColor = Colors.orange;
    if (t.status == TorrentStatus.error) statusColor = cs.error;

    return _glassContainer(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isCompleted
                      ? Icons.check_rounded
                      : (isPaused ? Icons.pause_rounded : Icons.download_rounded),
                  color: statusColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t.name,
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: cs.onSurface, letterSpacing: -0.2),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${t.size} • ${t.status.name.toUpperCase()}',
                      style: TextStyle(fontSize: 11, color: cs.onSurface.withValues(alpha: 0.5), fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              PopupMenuButton(
                icon: Icon(Icons.more_vert_rounded, size: 20, color: cs.onSurface.withValues(alpha: 0.6)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                itemBuilder: (ctx) => [
                  if (isPaused)
                    const PopupMenuItem(value: 'resume', child: Text('Resume'))
                  else if (isDownloading)
                    const PopupMenuItem(value: 'pause', child: Text('Pause')),
                  const PopupMenuItem(value: 'stop', child: Text('Stop')),
                  const PopupMenuItem(value: 'stream', child: Text('Stream / Play Online')),
                  const PopupMenuItem(value: 'details', child: Text('Torrent Details')),
                  const PopupMenuItem(value: 'open', child: Text('Open Folder')),
                  PopupMenuItem(
                    value: 'sequential',
                    child: Row(
                      children: [
                        Text(t.isSequential ? 'Sequential: ON' : 'Sequential: OFF'),
                        const Spacer(),
                        Icon(
                          t.isSequential ? Icons.check : Icons.close,
                          size: 16,
                          color: t.isSequential ? Colors.green : Colors.grey,
                        ),
                      ],
                    ),
                  ),
                  const PopupMenuItem(value: 'copy', child: Text('Copy Magnet')),
                  const PopupMenuItem(value: 'copyHash', child: Text('Copy Hash')),
                  const PopupMenuItem(value: 'share', child: Text('Share Magnet')),
                  const PopupMenuItem(value: 'delete', child: Text('Delete')),
                  const PopupMenuItem(value: 'deleteData', child: Text('Delete + Data')),
                ],
                onSelected: (val) async {
                  if (val == 'pause') provider.pauseTorrent(t.id);
                  if (val == 'resume') provider.resumeTorrent(t.id);
                  if (val == 'stop') provider.pauseTorrent(t.id);
                  if (val == 'details') _showTorrentDetails(context, t);
                  if (val == 'delete') provider.deleteTorrent(t.id);
                  if (val == 'deleteData') {
                    if (_isIOS) {
                      const MethodChannel('com.dirxplore/torrent').invokeMethod('removeTorrent', {
                        'id': t.id,
                        'deleteFiles': true,
                      });
                    } else {
                      provider.deleteTorrent(t.id);
                    }
                  }
                  if (val == 'copy') {
                    await Clipboard.setData(ClipboardData(text: t.magnetLink));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Magnet copied!')));
                    }
                  }
                  if (val == 'copyHash') {
                    await Clipboard.setData(ClipboardData(text: t.hash));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Hash copied!')));
                    }
                  }
                  if (val == 'share') {
                    Share.share(t.magnetLink, subject: 'Share Magnet Link');
                  }
                  if (val == 'stream') {
                    if (context.mounted) _handleStream(context, t.id, t.name);
                  }
                  if (val == 'sequential') {
                    provider.toggleSequential(t.id);
                  }
                  if (val == 'open') {
                    final uri = Uri.file(t.savePath);
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri);
                    } else {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Cannot open folder automatically.')));
                      }
                    }
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: t.progress,
              backgroundColor: cs.outlineVariant.withValues(alpha: 0.15),
              color: statusColor,
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _infoBadge(Icons.percent_rounded, '${(t.progress * 100).toStringAsFixed(1)}%', statusColor),
              const SizedBox(width: 16),
              if (isDownloading || t.status == TorrentStatus.seeding) ...[
                _infoBadge(Icons.arrow_downward_rounded, _formatBytes(t.downloadSpeed), statusColor),
                const SizedBox(width: 12),
                _infoBadge(Icons.arrow_upward_rounded, _formatBytes(t.uploadSpeed), Colors.blue),
                const SizedBox(width: 12),
                if (t.eta > 0)
                  _infoBadge(Icons.schedule_rounded, _formatDuration(t.eta), cs.primary),
              ],
              if (t.status == TorrentStatus.completed) ...[
                _infoBadge(Icons.check_circle_outline, 'Completed', Colors.green),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _infoBadge(Icons.storage_rounded, t.size, cs.onSurface.withValues(alpha: 0.5)),
              const SizedBox(width: 16),
              _infoBadge(Icons.download_done_rounded, _formatBytes(t.downloaded), cs.onSurface.withValues(alpha: 0.5)),
              const SizedBox(width: 16),
              _infoBadge(Icons.people_outline, '${t.seeds}S / ${t.peers}P', cs.onSurface.withValues(alpha: 0.5)),
              const SizedBox(width: 16),
              if (t.ratio > 0)
                _infoBadge(Icons.compare_arrows_rounded, t.ratio.toStringAsFixed(2), cs.onSurface.withValues(alpha: 0.5)),
            ],
          ),
        ],
      ),
    );
  }

  void _showAddTorrentDialog(BuildContext context) {
    final nameController = TextEditingController();
    final linkController = TextEditingController();
    bool isSequential = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => _buildGlassDialog(
          title: 'Add Torrent Link',
          icon: Icons.link,
          iconColor: Theme.of(context).colorScheme.primary,
          customContent: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white.withValues(alpha: 0.06)
                          : Colors.white.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.3),
                      ),
                    ),
                    child: TextField(
                      controller: nameController,
                      decoration: InputDecoration(
                        hintText: 'Name (optional)',
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white.withValues(alpha: 0.06)
                          : Colors.white.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.3),
                      ),
                    ),
                    child: TextField(
                      controller: linkController,
                      decoration: InputDecoration(
                        hintText: 'Magnet or .torrent URL',
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _glassContainer(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: SwitchListTile(
                  title: const Text('Sequential Download', style: TextStyle(fontSize: 14)),
                  value: isSequential,
                  onChanged: (val) => setDialogState(() => isSequential = val),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
          dialogActions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel',
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6))),
            ),
            _glassButton(
              label: 'Add',
              onPressed: () {
                if (linkController.text.isNotEmpty) {
                  final appState = context.read<AppState>();
                  context.read<TorrentProvider>().addTorrent(
                        nameController.text.isEmpty ? 'New Torrent' : nameController.text,
                        linkController.text,
                        appState.defaultSavePath,
                        'Unknown size',
                        isSequential: isSequential,
                      );
                  Navigator.pop(ctx);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showTorrentDetails(BuildContext context, TorrentItem t) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Consumer<TorrentProvider>(
        builder: (context, provider, _) {
          final peers = provider.getPeers(t.id);
          final trackers = provider.getTrackers(t.id);
          final files = provider.getTaskFiles(t.id);

          return ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
              child: Container(
                height: MediaQuery.of(context).size.height * 0.85,
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.grey.shade900.withValues(alpha: 0.92)
                      : Colors.white.withValues(alpha: 0.92),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                  border: Border(
                    top: BorderSide(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.1)
                          : Colors.white.withValues(alpha: 0.5),
                    ),
                  ),
                ),
                child: Column(
                  children: [
                    const SizedBox(height: 12),
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withValues(alpha: 0.2) : Colors.black.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(t.name,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, letterSpacing: -0.5),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Hash: ${t.hash.substring(0, 8)}...${t.hash.substring(t.hash.length - 8)}',
                                      style: TextStyle(
                                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                                        fontSize: 11,
                                        fontFeatures: const [FontFeature.tabularFigures()],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              IconButton.filled(
                                onPressed: () => _handleStream(context, t.id, t.name),
                                icon: const Icon(Icons.play_arrow_rounded),
                                style: IconButton.styleFrom(
                                  backgroundColor: Colors.green.withValues(alpha: 0.2),
                                  foregroundColor: Colors.green,
                                  padding: const EdgeInsets.all(12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    side: BorderSide(color: Colors.green.withValues(alpha: 0.3)),
                                  ),
                                ),
                                tooltip: 'Stream Now',
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          _glassContainer(
                            padding: const EdgeInsets.all(16),
                            child: Wrap(
                              spacing: 20,
                              runSpacing: 16,
                              alignment: WrapAlignment.spaceBetween,
                              children: [
                                _detailStat(Icons.cloud_download_rounded, '${(t.progress * 100).toStringAsFixed(1)}%', 'Progress'),
                                _detailStat(Icons.arrow_downward_rounded, _formatBytes(t.downloadSpeed), 'DL Speed'),
                                _detailStat(Icons.arrow_upward_rounded, _formatBytes(t.uploadSpeed), 'UL Speed'),
                                _detailStat(Icons.schedule_rounded, t.eta > 0 ? _formatDuration(t.eta) : '--', 'ETA'),
                                _detailStat(Icons.storage_rounded, t.size, 'Size'),
                                _detailStat(Icons.download_done_rounded, _formatBytes(t.downloaded), 'Downloaded'),
                                _detailStat(Icons.people_outline, '${t.seeds}', 'Seeds'),
                                _detailStat(Icons.people, '${t.peers}', 'Peers'),
                                _detailStat(Icons.compare_arrows_rounded, t.ratio.toStringAsFixed(2), 'Ratio'),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          if (peers != null && peers.isNotEmpty) ...[
                            Text('Peers',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    letterSpacing: -0.3,
                                    color: Theme.of(context).colorScheme.onSurface)),
                            const SizedBox(height: 8),
                            _glassContainer(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                children: peers.take(5).toList().asMap().entries.map((e) => Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 4),
                                  child: Row(
                                    children: [
                                      Icon(Icons.person_outline, size: 14, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text('Peer ${e.key + 1}',
                                            style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7))),
                                      ),
                                    ],
                                  ),
                                )).toList(),
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],
                          if (trackers != null && trackers.isNotEmpty) ...[
                            Text('Trackers',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    letterSpacing: -0.3,
                                    color: Theme.of(context).colorScheme.onSurface)),
                            const SizedBox(height: 8),
                            _glassContainer(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                children: trackers.take(10).toList().asMap().entries.map((e) => Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 4),
                                  child: Row(
                                    children: [
                                      Icon(Icons.dns_outlined, size: 14, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text('${e.value}',
                                            style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7))),
                                      ),
                                    ],
                                  ),
                                )).toList(),
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],
                          if (files != null && files.isNotEmpty) ...[
                            Text('Files',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    letterSpacing: -0.3,
                                    color: Theme.of(context).colorScheme.onSurface)),
                            const SizedBox(height: 8),
                            _glassContainer(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                children: files.take(20).toList().asMap().entries.map((e) => Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 4),
                                  child: Row(
                                    children: [
                                      Icon(
                                        e.value.name.toLowerCase().contains(RegExp(r'\.(mp4|mkv|avi|mov)$'))
                                            ? Icons.video_file_rounded
                                            : Icons.insert_drive_file_rounded,
                                        size: 16,
                                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text('${e.value}',
                                            style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7))),
                                      ),
                                    ],
                                  ),
                                )).toList(),
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _detailStat(IconData icon, String value, String label) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        Icon(icon, size: 20, color: cs.primary.withValues(alpha: 0.7)),
        const SizedBox(height: 4),
        Text(value,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: cs.onSurface)),
        Text(label,
            style: TextStyle(fontSize: 11, color: cs.onSurface.withValues(alpha: 0.5))),
      ],
    );
  }

  Future<void> _handleStream(BuildContext context, String id, String title,
      {String? filePath}) async {
    final provider = context.read<TorrentProvider>();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Starting streaming server...')),
    );

    final url = await provider.startStreaming(id, filePath: filePath);
    if (url != null && context.mounted) {
      final allFiles = provider.getTaskFiles(id);
      final videoFiles = allFiles.where((f) {
        final name = f.name.toLowerCase();
        return name.endsWith('.mp4') ||
            name.endsWith('.mkv') ||
            name.endsWith('.avi') ||
            name.endsWith('.mov') ||
            name.endsWith('.wmv') ||
            name.endsWith('.flv');
      }).toList();

      List<Map<String, String>> playlist = [];
      int initialIndex = 0;

      if (videoFiles.isEmpty) {
        playlist = [{'url': url, 'title': title}];
      } else {
        playlist = videoFiles.map((f) {
          final fileUrl = 'http://127.0.0.1:9090/${Uri.encodeComponent(f.path)}';
          return {'url': fileUrl, 'title': f.name};
        }).toList();

        if (filePath != null) {
          initialIndex = videoFiles.indexWhere((f) => f.path == filePath);
          if (initialIndex == -1) initialIndex = 0;
        } else {
          initialIndex = playlist.indexWhere((item) => item['url'] == url);
          if (initialIndex == -1) initialIndex = 0;
        }
      }

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => MediaPlayerScreen(
            url: playlist[initialIndex]['url']!,
            title: playlist[initialIndex]['title']!,
            playlist: playlist,
            initialIndex: initialIndex,
          ),
        ),
      );
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to start streaming.')),
      );
    }
  }
}

  String _formatBytes(int bytes) {
    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB/s';
    } else if (bytes >= 1024) {
      return '${(bytes / 1024).toStringAsFixed(0)} KB/s';
    }
    return '$bytes B/s';
  }

  String _formatDuration(int seconds) {
    if (seconds >= 3600) {
      final h = seconds ~/ 3600;
      final m = (seconds % 3600) ~/ 60;
      return '${h}h ${m}m';
    } else if (seconds >= 60) {
      final m = seconds ~/ 60;
      final s = seconds % 60;
      return '${m}m ${s}s';
    }
    return '${seconds}s';
  }

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  _SliverAppBarDelegate(this.child);

  @override
  double get minExtent => 48;
  @override
  double get maxExtent => 48;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return child;
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) => child != oldDelegate.child;
}
