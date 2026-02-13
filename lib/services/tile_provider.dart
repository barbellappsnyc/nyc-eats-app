import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:cached_network_image/cached_network_image.dart';

// 1. THE PROVIDER (Used by the Map Widget)
class CachedTileProvider extends TileProvider {
  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    return CachedNetworkImageProvider(
      getTileUrl(coordinates, options),
      // Keep your headers! This prevents getting banned by the server.
      headers: const {'User-Agent': 'com.nyceats.app'},
    );
  }
}

// 2. THE HEATER (Used by the Loading Screen)
class MapHeater {
  // Convert Lat/Lng to Tile Numbers (The Math)
  static Point<int> _getTileXY(double lat, double lng, int zoom) {
    var n = pow(2.0, zoom);
    var rad = lat * pi / 180;
    var xtile = (n * ((lng + 180) / 360)).floor();
    var ytile = (n * (1 - (log(tan(rad) + 1 / cos(rad)) / pi)) / 2).floor();
    return Point(xtile, ytile);
  }

  // The Warm Up Function
  static Future<void> preCacheTiles(double lat, double lng, bool isDarkMode) async {
    // Pre-load City View (13) and Street View (14)
    final List<int> zooms = [13, 14];
    final String theme = isDarkMode ? 'dark_all' : 'voyager';
    // CartoDB uses subdomains a, b, c. We'll pick 'a' for simplicity.
    const String subdomain = 'a'; 

    for (var z in zooms) {
      final center = _getTileXY(lat, lng, z);
      
      // 📦 DOWNLOAD A 3x3 GRID (Center + 8 neighbors)
      for (var x = center.x - 1; x <= center.x + 1; x++) {
        for (var y = center.y - 1; y <= center.y + 1; y++) {
          final url = 'https://$subdomain.basemaps.cartocdn.com/rastertiles/$theme/$z/$x/$y@2x.png';
          
          try {
            // This triggers the download and saves it to disk automatically
            final provider = CachedNetworkImageProvider(
              url,
              headers: const {'User-Agent': 'com.nyceats.app'},
            );
            // Force it to resolve (download) now
            provider.resolve(const ImageConfiguration());
          } catch (e) {
            // Ignore network errors during pre-warming
          }
        }
      }
    }
  }
}