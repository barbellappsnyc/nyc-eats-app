import 'package:latlong2/latlong.dart';

class Restaurant {
  final int id;
  final String name;
  final String cuisine;
  final String price;
  final double rating;
  final bool hasMichelin;
  final LatLng location;
  final String imageUrl;
  final String? phone;
  final String? website;
  final String? openingHours;
  final bool delivery;
  final bool takeaway;
  final bool reservations;
  final bool cocktails;
  final bool isVegetarian;
  final bool isVegan;
  final int michelinStars;
  final bool bibGourmand;

  int get priceLevel => price.length;

  Restaurant({
    required this.id,
    required this.name,
    required this.cuisine,
    required this.price,
    required this.rating,
    required this.hasMichelin,
    required this.location,
    required this.imageUrl,
    this.phone,
    this.website,
    this.openingHours,
    required this.delivery,
    required this.takeaway,
    required this.reservations,
    required this.cocktails,
    this.isVegetarian = false,
    this.isVegan = false,
    this.michelinStars = 0,
    this.bibGourmand = false,
  });

  factory Restaurant.fromMap(Map<dynamic, dynamic> rawMap) {
    // 🛡️ THE SHIELD: Safely convert any Map type (Supabase or Mapbox) into a usable one
    final Map<String, dynamic> map = Map<String, dynamic>.from(rawMap);

    bool toBool(dynamic value) {
      if (value == null) return false;
      if (value is bool) return value;
      if (value is String) {
        return value.toLowerCase() == 'true' || value == '1';
      }
      if (value is int) return value == 1;
      return false;
    }

    // 🛡️ NUMERIC SHIELD: Handles cases where a number might be an int OR a double
    double toDouble(dynamic value) {
      if (value == null) return 0.0;
      if (value is num) return value.toDouble();
      return double.tryParse(value.toString()) ?? 0.0;
    }

    return Restaurant(
      id: int.tryParse(map['id']?.toString() ?? '0') ?? 0,
      name: map['name'] ?? 'Unknown Restaurant',
      cuisine: map['cuisine'] ?? 'other',
      price: map['price']?.toString() ?? '\$\$', 
      rating: toDouble(map['rating']),
      hasMichelin: toBool(map['has_michelin']),
      location: LatLng(
        toDouble(map['lat']),
        toDouble(map['lng']),
      ),
      imageUrl: map['image_url'] ?? '',
      phone: map['phone']?.toString(),
      website: map['website']?.toString(),
      openingHours: map['opening_hours']?.toString(),
      delivery: toBool(map['delivery']),
      takeaway: toBool(map['takeaway']),
      reservations: toBool(map['reservation']),
      cocktails: toBool(map['cocktails']),
      isVegetarian: toBool(map['is_vegetarian']),
      isVegan: toBool(map['is_vegan']),
      bibGourmand: toBool(map['bib_gourmand']),
      michelinStars: map['michelin_stars'] != null 
          ? int.tryParse(map['michelin_stars'].toString().split('.')[0]) ?? 0 
          : 0,
    );
  }

//   factory Restaurant.fromMap(Map<String, dynamic> map) {
//     return Restaurant(
//       id: map['id'] as int, // <--- 3. EXTRACT ID FROM DATABASE
//       name: map['name'] ?? 'Unknown',
//       cuisine: map['cuisine'] ?? 'Other',
//       price: map['price'] ?? '\$\$',
//       rating: (map['rating'] as num?)?.toDouble() ?? 0.0,
//       hasMichelin: map['has_michelin'] ?? false,
//       location: LatLng(
//         (map['lat'] as num?)?.toDouble() ?? 40.7, 
//         (map['lng'] as num?)?.toDouble() ?? -74.0
//       ),
//       imageUrl: map['image_url'] ?? "https://images.unsplash.com/photo-1414235077428-338989a2e8c0?q=80&w=600",
      
//       // --- MAPPING NEW FIELDS ---
//       phone: map['phone'],
//       website: map['website'],
//       openingHours: map['opening_hours'],
//       delivery: map['delivery'] ?? false,
//       takeaway: map['takeaway'] ?? false,
//       reservations: map['reservation'] ?? false,
//       cocktails: map['cocktails'] ?? false,

//       // // NEW: Supabase might return null, so we default to false
//       // isVegetarian: map['is_vegetarian'] ?? false, 
//       // isVegan: map['is_vegan'] ?? false,

//       // // 🌟 ADD THESE MAPPINGS 🌟
//       // // Note: Make sure your Supabase columns match these names ('michelin_stars' and 'bib_gourmand')
//       // michelinStars: map['michelin_stars'] ?? 0, 
//       // bibGourmand: map['bib_gourmand'] ?? false,
//       // Inside Restaurant.fromMap...

// michelinStars: map['michelin_stars'] != null ? int.parse(map['michelin_stars'].toString().split('.')[0]) : 0,

// // This handles cases where Supabase sends strings like "false" instead of actual booleans
// bibGourmand: map['bib_gourmand'] == true || map['bib_gourmand'].toString().toLowerCase() == 'true',
// isVegetarian: map['is_vegetarian'] == true || map['is_vegetarian'].toString().toLowerCase() == 'true',
// isVegan: map['is_vegan'] == true || map['is_vegan'].toString().toLowerCase() == 'true',

//     );
//   }

  // factory Restaurant.fromMap(Map<String, dynamic> map) {
  //   // 🛡️ INTERNAL HELPER: Converts "True", true, or 1 into a real Dart bool
  //   bool toBool(dynamic value) {
  //     if (value == null) return false;
  //     if (value is bool) return value;
  //     if (value is String) {
  //       return value.toLowerCase() == 'true' || value == '1';
  //     }
  //     if (value is int) return value == 1;
  //     return false;
  //   }

  //   return Restaurant(
  //     id: map['id'] ?? 0,
  //     name: map['name'] ?? 'Unknown Restaurant',
  //     cuisine: map['cuisine'] ?? 'other',
  //     price: map['price'] ?? '$$',
  //     rating: (map['rating'] ?? 0.0).toDouble(),
  //     hasMichelin: toBool(map['has_michelin']),
  //     location: LatLng(
  //       (map['lat'] ?? 0.0).toDouble(),
  //       (map['lng'] ?? 0.0).toDouble(),
  //     ),
  //     imageUrl: map['image_url'] ?? '',
  //     phone: map['phone'],
  //     website: map['website'],
  //     openingHours: map['opening_hours'],
  //     // 🛡️ APPLYING THE SHIELD TO EVERY BOOLEAN
  //     delivery: toBool(map['delivery']),
  //     takeaway: toBool(map['takeaway']),
  //     reservations: toBool(map['reservation']),
  //     cocktails: toBool(map['cocktails']),
  //     isVegetarian: toBool(map['is_vegetarian']),
  //     isVegan: toBool(map['is_vegan']),
  //     bibGourmand: toBool(map['bib_gourmand']),
  //     // 🛡️ MICHELIN STARS SAFETY
  //     michelinStars: map['michelin_stars'] != null 
  //         ? int.tryParse(map['michelin_stars'].toString().split('.')[0]) ?? 0 
  //         : 0,
  //   );
  // }

  // Use this if you need to save back to cache
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'cuisine': cuisine,
      'price': price,
      'rating': rating,
      'has_michelin': hasMichelin,
      'lat': location.latitude,
      'lng': location.longitude,
      'image_url': imageUrl,
      'phone': phone,
      'website': website,
      'opening_hours': openingHours,
      'delivery': delivery,
      'takeaway': takeaway,
      'reservation': reservations,
      'cocktails': cocktails,
    };
  }

// ... existing fields and constructor ...

bool get isOpenNow {
    if (openingHours == null || openingHours!.isEmpty) return false;

    // --- FIX FOR 24/7 PLACES ---
    final lower = openingHours!.toLowerCase();
    if (lower.contains("24 hours") || lower.contains("24/7") || lower.contains("open 24")) {
      return true;
    }

    // ... (Keep your existing parsing logic below) ...
    final now = DateTime.now();
    final days = {1: 'Mo', 2: 'Tu', 3: 'We', 4: 'Th', 5: 'Fr', 6: 'Sa', 7: 'Su'};
    final todayStr = days[now.weekday]!;
    
    String hours = openingHours!.replaceAll(';', ' ').replaceAll(',', ' ');
    
    // Quick check: If today isn't listed, it might be closed
    bool specificDays = hours.contains('Mo') || hours.contains('Su');
    if (specificDays && !hours.contains(todayStr) && !hours.contains('Mo-Su')) {
       if (hours.contains('Mo-Fr') && now.weekday <= 5) { /* It's a weekday */ }
       else if (hours.contains('Mo-Sa') && now.weekday <= 6) { /* It's Mon-Sat */ }
       else { return false; } 
    }

    try {
      final regex = RegExp(r'(\d{1,2}):(\d{2})\s*-\s*(\d{1,2}):(\d{2})');
      final matches = regex.allMatches(hours);
      
      for (final match in matches) {
        final startH = int.parse(match.group(1)!);
        final startM = int.parse(match.group(2)!);
        var endH = int.parse(match.group(3)!);
        final endM = int.parse(match.group(4)!);
        
        final start = DateTime(now.year, now.month, now.day, startH, startM);
        var end = DateTime(now.year, now.month, now.day, endH, endM);
        
        // Handle closing after midnight (e.g., 11:00 - 02:00)
        if (end.isBefore(start)) end = end.add(const Duration(days: 1));
        
        if (now.isAfter(start) && now.isBefore(end)) return true;
      }
    } catch (e) {
      return false;
    }
    return false;
  }
}

