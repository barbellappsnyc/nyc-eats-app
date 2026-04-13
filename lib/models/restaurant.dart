import 'package:latlong2/latlong.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:nyc_eats/screens/map_screen.dart'; // This connects it to your OSMTimeParser

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
      location: LatLng(toDouble(map['lat']), toDouble(map['lng'])),
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
    // If there are no hours listed, assume it's closed
    if (openingHours == null || openingHours!.isEmpty) return false;

    // 1. Get the exact current time in NYC (handles Daylight Saving automatically)
    final nyLocation = tz.getLocation('America/New_York');
    final nycTime = tz.TZDateTime.now(nyLocation);

    // 2. Ask the Master Parser if it's open right now
    return OSMTimeParser.isOpen(openingHours!, nycTime);
  }
}
