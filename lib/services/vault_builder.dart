import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class VaultBuilder {
  static Future<Map<String, String>> buildVaultIfNeeded({bool forceRefresh = false}) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final heroesFile = File('${directory.path}/nyc_heroes.geojson');
      final regularFile = File('${directory.path}/nyc_regular.geojson');
      final hoursFile = File('${directory.path}/nyc_hours.json'); // 🌟 NEW: Time Dictionary

      if (await heroesFile.exists() && await regularFile.exists() && await hoursFile.exists() && !forceRefresh) {
        debugPrint("✅ Split Vaults found. Bypassing download.");
        return {'heroes': heroesFile.path, 'regular': regularFile.path, 'hours': hoursFile.path};
      }

      debugPrint("📥 Building Split Vaults...");

      List<Map<String, dynamic>> allRows = [];
      const int pageSize = 1000;
      int offset = 0;
      bool hasMore = true;

      while (hasMore) {
        final response = await Supabase.instance.client
            .from('restaurants')
            // 🌟 THE FIX: Select ALL columns needed for Mapbox filtering!
            .select('id, name, lat, lng, cuisine, michelin_stars, bib_gourmand, price, is_vegetarian, is_vegan, opening_hours')
            .range(offset, offset + pageSize - 1)
            .timeout(const Duration(seconds: 5)); // 🌟 THE ZOMBIE KILL SWITCH

        allRows.addAll(response);
        if (response.length < pageSize) hasMore = false;
        else offset += pageSize;
      }

      List<Map<String, dynamic>> heroesFeatures = [];
      List<Map<String, dynamic>> regularFeatures = [];
      Map<String, String> hoursDict = {}; // 🌟 Track hours separately

      for (var row in allRows) {
        final double lat = row['lat'] is num ? row['lat'].toDouble() : double.tryParse(row['lat']?.toString() ?? '') ?? 0.0;
        final double lng = row['lng'] is num ? row['lng'].toDouble() : double.tryParse(row['lng']?.toString() ?? '') ?? 0.0;

        // Clean nulls to prevent Mapbox parsing errors
        final cleanProperties = Map<String, dynamic>.from(row);
        cleanProperties.removeWhere((key, value) => value == null);

        final feature = {
          "type": "Feature",
          "geometry": {"type": "Point", "coordinates": [lng, lat]},
          "properties": cleanProperties, 
        };

        // Populate the Time Dictionary
        if (row['opening_hours'] != null && row['opening_hours'].toString().isNotEmpty) {
           hoursDict[row['id'].toString()] = row['opening_hours'].toString();
        }

        final stars = row['michelin_stars'];
        final int starCount = stars is num ? stars.toInt() : int.tryParse(stars?.toString() ?? '0') ?? 0;
        final bib = row['bib_gourmand'];
        final bool isBib = bib == true || bib?.toString().toLowerCase() == 'true';

        if (starCount > 0 || isBib) {
          heroesFeatures.add(feature);
        } else {
          regularFeatures.add(feature);
        }
      }

      await heroesFile.writeAsString(jsonEncode({"type": "FeatureCollection", "features": heroesFeatures}));
      await regularFile.writeAsString(jsonEncode({"type": "FeatureCollection", "features": regularFeatures}));
      await hoursFile.writeAsString(jsonEncode(hoursDict)); // 🌟 Save the Time Dictionary

      debugPrint("🔥 Vaults sealed! Heroes: ${heroesFeatures.length}, Regular: ${regularFeatures.length}");
      return {'heroes': heroesFile.path, 'regular': regularFile.path, 'hours': hoursFile.path};

    } catch (e) {
      debugPrint("🚨 Error building vault: $e");
      rethrow;
    }
  }
}