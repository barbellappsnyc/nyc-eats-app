import 'package:latlong2/latlong.dart';

class Restaurant {
  final int id; // <--- 1. ADD THIS FIELD
  final String name;
  final String cuisine; 
  final String price;
  final double rating; 
  final bool hasMichelin;
  final LatLng location;
  final String imageUrl;
  
  // --- NEW FIELDS ---
  final String? phone;
  final String? website;
  final String? openingHours;
  final bool delivery;
  final bool takeaway;
  final bool reservations;
  final bool cocktails;
  final bool isVegetarian; // NEW
  final bool isVegan;      // NEW
  // 🌟 ADD THESE TWO LINES 🌟
  final int michelinStars; 
  final bool bibGourmand;

  int get priceLevel => price.length;

  Restaurant({
    required this.id, // <--- 2. ADD TO CONSTRUCTOR
    required this.name,
    required this.cuisine,
    required this.price,
    required this.rating,
    required this.hasMichelin,
    required this.location,
    required this.imageUrl,
    // --- NEW ---
    this.phone,
    this.website,
    this.openingHours,
    required this.delivery,
    required this.takeaway,
    required this.reservations,
    required this.cocktails,
    this.isVegetarian = false, // NEW (Default to false)
    this.isVegan = false,      // NEW

    // 🌟 ADD THESE TWO LINES 🌟
    this.michelinStars = 0,
    this.bibGourmand = false,
  });

  factory Restaurant.fromMap(Map<String, dynamic> map) {
    return Restaurant(
      id: map['id'] as int, // <--- 3. EXTRACT ID FROM DATABASE
      name: map['name'] ?? 'Unknown',
      cuisine: map['cuisine'] ?? 'Other',
      price: map['price'] ?? '\$\$',
      rating: (map['rating'] as num?)?.toDouble() ?? 0.0,
      hasMichelin: map['has_michelin'] ?? false,
      location: LatLng(
        (map['lat'] as num?)?.toDouble() ?? 40.7, 
        (map['lng'] as num?)?.toDouble() ?? -74.0
      ),
      imageUrl: map['image_url'] ?? "https://images.unsplash.com/photo-1414235077428-338989a2e8c0?q=80&w=600",
      
      // --- MAPPING NEW FIELDS ---
      phone: map['phone'],
      website: map['website'],
      openingHours: map['opening_hours'],
      delivery: map['delivery'] ?? false,
      takeaway: map['takeaway'] ?? false,
      reservations: map['reservations'] ?? false,
      cocktails: map['cocktails'] ?? false,

      // NEW: Supabase might return null, so we default to false
      isVegetarian: map['is_vegetarian'] ?? false, 
      isVegan: map['is_vegan'] ?? false,

      // 🌟 ADD THESE MAPPINGS 🌟
      // Note: Make sure your Supabase columns match these names ('michelin_stars' and 'bib_gourmand')
      michelinStars: map['michelin_stars'] ?? 0, 
      bibGourmand: map['bib_gourmand'] ?? false,

    );
  }

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
      'reservations': reservations,
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

