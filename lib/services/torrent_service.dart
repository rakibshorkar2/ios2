import 'dart:math';
import '../services/dio_client.dart';

enum TorrentSearchProvider {
  yts,
  solid,
  pb,
  x1337,
  tGalaxy,
  nyaa,
  lime,
  kickass,
  eztv,
  rarbg,
  rutor,
  idope,
  isohunt,
  soft,
  zooqle,
  animeTime,
  animeTosho,
  anirena,
  anisource,
  arabTorrents,
  bitsearch,
  blueRoms,
  btEtree,
  btDirectory,
  cloudTorrents,
  corsaroNero,
  cpasbien,
  extratorrent,
  fitgirl,
  gamesTorrents,
  linuxTracker,
  megaPeer,
  nonameClub,
  redeTorrent,
  torrentCSV,
  torrentCore,
  torrentFunk,
  torrentoyunindir,
  yourBitTorrent,
}

enum TorrentCategory {
  all,
  movies,
  series,
  games,
  music,
  books,
  apps,
}

class TorrentSearchResult {
  final String title;
  final String magnet;
  final String size;
  final String seeds;
  final String peers;
  final String hash;
  final String provider;

  TorrentSearchResult({
    required this.title,
    required this.magnet,
    required this.size,
    required this.seeds,
    required this.peers,
    required this.hash,
    required this.provider,
  });
}

class TorrentService {
  static Future<List<TorrentSearchResult>> searchAll(String query,
      {bool useProxy = false,
      List<TorrentSearchProvider>? providers,
      TorrentCategory category = TorrentCategory.all}) async {
    if (query.isEmpty) return [];

    final selectedProviders = providers ?? [
      TorrentSearchProvider.yts,
      TorrentSearchProvider.solid,
      TorrentSearchProvider.pb,
      TorrentSearchProvider.x1337,
      TorrentSearchProvider.tGalaxy,
    ];

    final List<Future<List<TorrentSearchResult>>> searchTasks = [];
    
    for (var p in selectedProviders) {
      switch (p) {
        case TorrentSearchProvider.yts:
          searchTasks.add(searchYTS(query, useProxy: useProxy));
          break;
        case TorrentSearchProvider.solid:
          searchTasks.add(searchSolidTorrents(query, useProxy: useProxy));
          break;
        case TorrentSearchProvider.pb:
          searchTasks.add(searchPirateBay(query, useProxy: useProxy));
          break;
        case TorrentSearchProvider.x1337:
          searchTasks.add(search1337x(query, useProxy: useProxy));
          break;
        case TorrentSearchProvider.tGalaxy:
          searchTasks.add(searchTorrentGalaxy(query, useProxy: useProxy, category: category));
          break;
        case TorrentSearchProvider.nyaa:
          searchTasks.add(searchNyaa(query, useProxy: useProxy));
          break;
        case TorrentSearchProvider.kickass:
          searchTasks.add(searchKickass(query, useProxy: useProxy, category: category));
          break;
        case TorrentSearchProvider.lime:
          searchTasks.add(searchLimeTorrents(query, useProxy: useProxy, category: category));
          break;
        case TorrentSearchProvider.eztv:
          searchTasks.add(searchEzTV(query, useProxy: useProxy));
          break;
        case TorrentSearchProvider.idope:
          searchTasks.add(searchIDope(query, useProxy: useProxy));
          break;
        case TorrentSearchProvider.rarbg:
          searchTasks.add(_searchApiListOne('rarbg', query, useProxy: useProxy, provider: 'RARBG'));
          break;
        case TorrentSearchProvider.rutor:
          searchTasks.add(_searchApiListOne('rutor', query, useProxy: useProxy, provider: 'RuTor'));
          break;
        case TorrentSearchProvider.isohunt:
          searchTasks.add(_searchApiListOne('isohunt', query, useProxy: useProxy, provider: 'ISO'));
          break;
        case TorrentSearchProvider.zooqle:
          searchTasks.add(_searchApiListOne('zooqle', query, useProxy: useProxy, provider: 'Zooqle'));
          break;
        case TorrentSearchProvider.bitsearch:
          searchTasks.add(searchBitsearch(query, useProxy: useProxy));
          break;
        case TorrentSearchProvider.extratorrent:
          searchTasks.add(_searchApiListOne('extratorrent', query, useProxy: useProxy, provider: 'ET'));
          break;
        case TorrentSearchProvider.torrentFunk:
          searchTasks.add(_searchApiListOne('torrentfunk', query, useProxy: useProxy, provider: 'TFunk'));
          break;
        case TorrentSearchProvider.soft:
          searchTasks.add(_searchApiListOne('soft', query, useProxy: useProxy, provider: 'Soft'));
          break;
        case TorrentSearchProvider.animeTime:
          searchTasks.add(_searchApiListOne('anime', query, useProxy: useProxy, provider: 'Anime'));
          break;
        case TorrentSearchProvider.animeTosho:
          searchTasks.add(_searchApiListOne('animetosho', query, useProxy: useProxy, provider: 'AT'));
          break;
        case TorrentSearchProvider.anirena:
          searchTasks.add(_searchApiListOne('anirena', query, useProxy: useProxy, provider: 'ARena'));
          break;
        case TorrentSearchProvider.anisource:
          searchTasks.add(_searchApiListOne('anisource', query, useProxy: useProxy, provider: 'ASrc'));
          break;
        case TorrentSearchProvider.arabTorrents:
          searchTasks.add(_searchApiListOne('arab', query, useProxy: useProxy, provider: 'Arab'));
          break;
        case TorrentSearchProvider.blueRoms:
          searchTasks.add(_searchApiListOne('blueroms', query, useProxy: useProxy, provider: 'Blue'));
          break;
        case TorrentSearchProvider.btEtree:
          searchTasks.add(_searchApiListOne('btetree', query, useProxy: useProxy, provider: 'BTE'));
          break;
        case TorrentSearchProvider.btDirectory:
          searchTasks.add(_searchApiListOne('btdb', query, useProxy: useProxy, provider: 'BTDB'));
          break;
        case TorrentSearchProvider.cloudTorrents:
          searchTasks.add(_searchApiListOne('cloudtorrents', query, useProxy: useProxy, provider: 'Cloud'));
          break;
        case TorrentSearchProvider.corsaroNero:
          searchTasks.add(_searchApiListOne('corsaro', query, useProxy: useProxy, provider: 'CN'));
          break;
        case TorrentSearchProvider.cpasbien:
          searchTasks.add(_searchApiListOne('cpasbien', query, useProxy: useProxy, provider: 'CP'));
          break;
        case TorrentSearchProvider.fitgirl:
          searchTasks.add(_searchApiListOne('fitgirl', query, useProxy: useProxy, provider: 'FG'));
          break;
        case TorrentSearchProvider.gamesTorrents:
          searchTasks.add(_searchApiListOne('games', query, useProxy: useProxy, provider: 'Gm'));
          break;
        case TorrentSearchProvider.linuxTracker:
          searchTasks.add(_searchApiListOne('linuxtracker', query, useProxy: useProxy, provider: 'LX'));
          break;
        case TorrentSearchProvider.megaPeer:
          searchTasks.add(_searchApiListOne('megapeer', query, useProxy: useProxy, provider: 'MP'));
          break;
        case TorrentSearchProvider.nonameClub:
          searchTasks.add(_searchApiListOne('noname', query, useProxy: useProxy, provider: 'NN'));
          break;
        case TorrentSearchProvider.redeTorrent:
          searchTasks.add(_searchApiListOne('rede', query, useProxy: useProxy, provider: 'Rede'));
          break;
        case TorrentSearchProvider.torrentCSV:
          searchTasks.add(_searchApiListOne('torrentcsv', query, useProxy: useProxy, provider: 'CSV'));
          break;
        case TorrentSearchProvider.torrentCore:
          searchTasks.add(_searchApiListOne('torrentcore', query, useProxy: useProxy, provider: 'TC'));
          break;
        case TorrentSearchProvider.torrentoyunindir:
          searchTasks.add(_searchApiListOne('torrentoyun', query, useProxy: useProxy, provider: 'TOY'));
          break;
        case TorrentSearchProvider.yourBitTorrent:
          searchTasks.add(_searchApiListOne('yourbittorrent', query, useProxy: useProxy, provider: 'YBT'));
          break;
        default:
          break;
      }
    }

    final List<List<TorrentSearchResult>> results = await Future.wait(searchTasks);

    // Flatten and sort by seeds
    final allResults = results.expand((x) => x).toList();
    allResults.sort((a, b) {
      final sA = int.tryParse(a.seeds) ?? 0;
      final sB = int.tryParse(b.seeds) ?? 0;
      return sB.compareTo(sA);
    });

    return allResults;
  }

  static Future<List<TorrentSearchResult>> searchYTS(String query,
      {bool useProxy = false}) async {
    if (query.isEmpty) return [];

    try {
      final dio = useProxy ? DioClient().dio : DioClient().cleanDio;
      final response = await dio.get(
        'https://yts.mx/api/v2/list_movies.json',
        queryParameters: {'query_term': query, 'limit': 15},
      );

      if (response.data['status'] == 'ok' &&
          response.data['data']['movies'] != null) {
        final List movies = response.data['data']['movies'];
        final List<TorrentSearchResult> results = [];

        for (var movie in movies) {
          final title = movie['title_long'] ?? movie['title'];
          final torrents = movie['torrents'] as List?;

          if (torrents != null) {
            for (var t in torrents) {
              final hash = t['hash'];
              final magnet =
                  'magnet:?xt=urn:btih:$hash&dn=${Uri.encodeComponent(title)}';

              results.add(TorrentSearchResult(
                title: '$title (${t['quality']} ${t['type']})',
                magnet: magnet,
                size: t['size'],
                seeds: t['seeds'].toString(),
                peers: t['peers'].toString(),
                hash: hash,
                provider: 'YTS',
              ));
            }
          }
        }
        return results;
      }
    } catch (_) {}
    return [];
  }

  static Future<List<TorrentSearchResult>> searchSolidTorrents(String query,
      {bool useProxy = false, TorrentCategory category = TorrentCategory.all}) async {
    try {
      String cat = 'all';
      if (category == TorrentCategory.movies) cat = 'movies';
      if (category == TorrentCategory.series) cat = 'series';
      if (category == TorrentCategory.music) cat = 'music';
      if (category == TorrentCategory.games) cat = 'games';
      if (category == TorrentCategory.apps) cat = 'apps';
      if (category == TorrentCategory.books) cat = 'books';

      final dio = useProxy ? DioClient().dio : DioClient().cleanDio;
      final response = await dio.get(
        'https://solidtorrents.to/api/v1/search',
        queryParameters: {'q': query, 'category': cat, 'sort': 'seeders'},
      );

      if (response.data['results'] != null) {
        final List items = response.data['results'];
        return items.map((item) {
          return TorrentSearchResult(
            title: item['title'],
            magnet: item['magnet'],
            size: formatBytes(item['size']),
            seeds: item['swarm']['seeders'].toString(),
            peers: item['swarm']['leechers'].toString(),
            hash: item['infoHash'],
            provider: 'Solid',
          );
        }).toList();
      }
    } catch (_) {}
    return [];
  }

  static Future<List<TorrentSearchResult>> searchPirateBay(String query,
      {bool useProxy = false, TorrentCategory category = TorrentCategory.all}) async {
    try {
      String cat = '0'; // All
      if (category == TorrentCategory.music) cat = '100';
      if (category == TorrentCategory.movies || category == TorrentCategory.series) cat = '200';
      if (category == TorrentCategory.apps) cat = '300';
      if (category == TorrentCategory.games) cat = '400';

      final dio = useProxy ? DioClient().dio : DioClient().cleanDio;
      final response = await dio.get(
        'https://apibay.org/q.php',
        queryParameters: {'q': query, 'cat': cat},
      );

      if (response.data is List) {
        final List items = response.data;
        return items.where((i) => i['id'] != '0').map((item) {
          final hash = item['info_hash'];
          final title = item['name'];
          final magnet =
              'magnet:?xt=urn:btih:$hash&dn=${Uri.encodeComponent(title)}';
          return TorrentSearchResult(
            title: title,
            magnet: magnet,
            size: formatBytes(int.tryParse(item['size'].toString()) ?? 0),
            seeds: item['seeders'].toString(),
            peers: item['leechers'].toString(),
            hash: hash,
            provider: 'PB',
          );
        }).toList();
      }
    } catch (_) {}
    return [];
  }

  static Future<List<TorrentSearchResult>> search1337x(String query,
      {bool useProxy = false}) async {
    // Unofficial API or Scraping. Using apilist.one or similar proxy for stability
    try {
      final dio = useProxy ? DioClient().dio : DioClient().cleanDio;
      final response = await dio.get(
        'https://api.apilist.one/1337x',
        queryParameters: {'q': query},
      );
      
      if (response.data != null && response.data is List) {
        final List items = response.data;
        return items.map((item) {
           return TorrentSearchResult(
            title: item['name'],
            magnet: item['magnet'],
            size: item['size'] ?? 'Unknown',
            seeds: item['seeders'].toString(),
            peers: item['leechers'].toString(),
            hash: _extHash(item['magnet']),
            provider: '1337x',
          );
        }).toList();
      }
    } catch (_) {}
    return [];
  }

  static Future<List<TorrentSearchResult>> searchTorrentGalaxy(String query,
      {bool useProxy = false, TorrentCategory category = TorrentCategory.all}) async {
    try {
      // TGx API uses specific category IDs, simplified here
      final dio = useProxy ? DioClient().dio : DioClient().cleanDio;
      final response = await dio.get(
        'https://api.apilist.one/tgx',
        queryParameters: {'q': query},
      );
      
      if (response.data != null && response.data is List) {
        final List items = response.data;
        return items.map((item) {
           return TorrentSearchResult(
            title: item['name'],
            magnet: item['magnet'],
            size: item['size'] ?? 'Unknown',
            seeds: item['seeders'].toString(),
            peers: item['leechers'].toString(),
            hash: _extHash(item['magnet']),
            provider: 'TGx',
          );
        }).toList();
      }
    } catch (_) {}
    return [];
  }

  static Future<List<TorrentSearchResult>> searchNyaa(String query,
      {bool useProxy = false}) async {
    try {
      final dio = useProxy ? DioClient().dio : DioClient().cleanDio;
      final response = await dio.get(
        'https://api.apilist.one/nyaa',
        queryParameters: {'q': query},
      );
      
      if (response.data != null && response.data is List) {
        final List items = response.data;
        return items.map((item) {
           return TorrentSearchResult(
            title: item['name'],
            magnet: item['magnet'],
            size: item['size'] ?? 'Unknown',
            seeds: item['seeders'].toString(),
            peers: item['leechers'].toString(),
            hash: _extHash(item['magnet']),
            provider: 'Nyaa',
          );
        }).toList();
      }
    } catch (_) {}
    return [];
  }

  static Future<List<TorrentSearchResult>> searchKickass(String query,
      {bool useProxy = false, TorrentCategory category = TorrentCategory.all}) async {
    try {
      final dio = useProxy ? DioClient().dio : DioClient().cleanDio;
      final response = await dio.get(
        'https://api.apilist.one/kickass',
        queryParameters: {'q': query},
      );
      
      if (response.data != null && response.data is List) {
        final List items = response.data;
        return items.map((item) {
           return TorrentSearchResult(
            title: item['name'],
            magnet: item['magnet'],
            size: item['size'] ?? 'Unknown',
            seeds: item['seeders'].toString(),
            peers: item['leechers'].toString(),
            hash: _extHash(item['magnet']),
            provider: 'Kickass',
          );
        }).toList();
      }
    } catch (_) {}
    return [];
  }

  static Future<List<TorrentSearchResult>> searchLimeTorrents(String query,
      {bool useProxy = false, TorrentCategory category = TorrentCategory.all}) async {
    try {
      final dio = useProxy ? DioClient().dio : DioClient().cleanDio;
      final response = await dio.get(
        'https://api.apilist.one/limetorrent',
        queryParameters: {'q': query},
      );
      
      if (response.data != null && response.data is List) {
        final List items = response.data;
        return items.map((item) {
           return TorrentSearchResult(
            title: item['name'],
            magnet: item['magnet'],
            size: item['size'] ?? 'Unknown',
            seeds: item['seeders'].toString(),
            peers: item['leechers'].toString(),
            hash: _extHash(item['magnet']),
            provider: 'Lime',
          );
        }).toList();
      }
    } catch (_) {}
    return [];
  }

  static Future<List<TorrentSearchResult>> searchEzTV(String query,
      {bool useProxy = false}) async {
    try {
      final dio = useProxy ? DioClient().dio : DioClient().cleanDio;
      final response = await dio.get(
        'https://api.apilist.one/eztv',
        queryParameters: {'q': query},
      );
      
      if (response.data != null && response.data is List) {
        final List items = response.data;
        return items.map((item) {
           return TorrentSearchResult(
            title: item['name'],
            magnet: item['magnet'],
            size: item['size'] ?? 'Unknown',
            seeds: item['seeders'].toString(),
            peers: item['leechers'].toString(),
            hash: _extHash(item['magnet']),
            provider: 'EzTV',
          );
        }).toList();
      }
    } catch (_) {}
    return [];
  }

  static Future<List<TorrentSearchResult>> searchIDope(String query,
      {bool useProxy = false}) async {
    try {
      final dio = useProxy ? DioClient().dio : DioClient().cleanDio;
      final response = await dio.get(
        'https://api.apilist.one/idope',
        queryParameters: {'q': query},
      );
      
      if (response.data != null && response.data is List) {
        final List items = response.data;
        return items.map((item) {
           return TorrentSearchResult(
            title: item['name'],
            magnet: item['magnet'],
            size: item['size'] ?? 'Unknown',
            seeds: item['seeders'].toString(),
            peers: item['leechers'].toString(),
            hash: _extHash(item['magnet']),
            provider: 'iDope',
          );
        }).toList();
      }
    } catch (_) {}
    return [];
  }

  static Future<List<TorrentSearchResult>> _searchApiListOne(
    String endpoint, String query, {
    bool useProxy = false,
    String provider = '',
  }) async {
    try {
      final dio = useProxy ? DioClient().dio : DioClient().cleanDio;
      final response = await dio.get(
        'https://api.apilist.one/$endpoint',
        queryParameters: {'q': query},
      );
      final data = response.data;
      final List items = (data is List) ? data : (data['data'] ?? []);
      return items.map((item) {
        return TorrentSearchResult(
          title: item['name'] ?? '',
          magnet: item['magnet'] ?? '',
          size: item['size'] ?? 'Unknown',
          seeds: (item['seeders'] ?? 0).toString(),
          peers: (item['leechers'] ?? 0).toString(),
          hash: _extHash(item['magnet'] ?? ''),
          provider: provider,
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<List<TorrentSearchResult>> searchBitsearch(String query,
      {bool useProxy = false}) async {
    try {
      final dio = useProxy ? DioClient().dio : DioClient().cleanDio;
      final response = await dio.get(
        'https://bitsearch.to/search',
        queryParameters: {'q': query},
      );
      final data = response.data;
      if (data == null) return [];
      final List items = data['data']?['results'] ?? [];
      return items.map((item) {
        final hash = item['infoHash'] ?? '';
        final magnet = 'magnet:?xt=urn:btih:$hash&dn=${Uri.encodeComponent(item['name'] ?? '')}';
        return TorrentSearchResult(
          title: item['name'] ?? '',
          magnet: magnet,
          size: formatBytes(int.tryParse(item['size']?.toString() ?? '0') ?? 0),
          seeds: (item['seeders'] ?? 0).toString(),
          peers: (item['leechers'] ?? 0).toString(),
          hash: hash,
          provider: 'Bitsearch',
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  static String _extHash(String magnet) {
    if (magnet.startsWith('magnet:?xt=urn:btih:')) {
      final xtMatch = RegExp(r'xt=urn:btih:([^&]+)').firstMatch(magnet);
      return xtMatch?.group(1) ?? '';
    }
    return '';
  }

  static String formatBytes(int bytes) {
    if (bytes <= 0) return "0 B";
    const suffixes = ["B", "KB", "MB", "GB", "TB"];
    var i = (log(bytes) / log(1024)).floor();
    return "${(bytes / pow(1024, i)).toStringAsFixed(1)} ${suffixes[i]}";
  }
}
