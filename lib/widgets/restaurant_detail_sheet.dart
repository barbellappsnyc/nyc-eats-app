import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/restaurant.dart';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'animated_cuisine_placeholder.dart';
import '../screens/passport_stack_screen.dart';
import '../screens/passport_collection_screen.dart'; // Make sure this is imported

class RestaurantDetailSheet extends StatefulWidget {
  final Restaurant restaurant;
  final bool isDarkMode;
  final bool isSaved;
  final LatLng? myLocation;
  final VoidCallback onFavoriteToggle;

  const RestaurantDetailSheet({
    super.key,
    required this.restaurant,
    required this.isDarkMode,
    required this.isSaved,
    this.myLocation,
    required this.onFavoriteToggle,
  });

  @override
  State<RestaurantDetailSheet> createState() => _RestaurantDetailSheetState();
}

class _RestaurantDetailSheetState extends State<RestaurantDetailSheet> {
  late bool _currentSavedStatus;
  
  // 🌟 NEW: Scroll Controller & Visibility State
  final ScrollController _scrollController = ScrollController();
  bool _showScrollButton = false;
  bool _isNavigatingToPassport = false;

  @override
  void initState() {
    super.initState();
    _currentSavedStatus = widget.isSaved;
    
    // 🌟 NEW: Listen to scrolling to hide/show button
    _scrollController.addListener(_checkScroll);
    
    // Check initially after layout
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkScroll());
  }
  
  @override
  void dispose() {

    // 🧹 THE MEMORY FLUSH: Nuke the images from RAM the second this sheet closes!
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
    _scrollController.dispose();
    super.dispose();
  }

  // 🌟 NEW: Logic to determine if button should show
  void _checkScroll() {
    if (!_scrollController.hasClients) return;
    
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.offset;
    
    // Show button if:
    // 1. There is scrollable content (maxScroll > 0)
    // 2. We are not yet at the bottom (with 50px buffer)
    final bool shouldShow = maxScroll > 0 && (maxScroll - currentScroll > 50);
    
    if (shouldShow != _showScrollButton) {
      setState(() {
        _showScrollButton = shouldShow;
      });
    }
  }

  // 🌟 NEW: Action to scroll to bottom
  void _scrollToBottom() {
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutQuart,
    );
  }

  // --- HELPERS ---
  String _getDistanceString(LatLng dest) {
    if (widget.myLocation == null) return "";
    final Distance distance = const Distance();
    final double meters = distance.as(LengthUnit.Meter, widget.myLocation!, dest);
    final double miles = meters / 1609.34;
    return "${miles.toStringAsFixed(1)} mi";
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final cleaned = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
    final Uri launchUri = Uri(scheme: 'tel', path: cleaned);
    if (!await launchUrl(launchUri, mode: LaunchMode.externalApplication)) {
      debugPrint("Could not launch dialer");
    }
  }

  Future<void> _searchOnGoogle(String restaurantName) async {
    final query = Uri.encodeComponent("$restaurantName NYC opening hours");
    final url = Uri.parse("https://www.google.com/search?q=$query");
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _openWebUrl(String url) async {
    String safeUrl = url;
    if (!safeUrl.startsWith('http')) safeUrl = 'https://$safeUrl';
    final Uri uri = Uri.parse(safeUrl);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      debugPrint("Could not launch $url");
    }
  }

  String _formatOpenHours(String raw) {
    String clean = raw.replaceAll(';', '\n');
    clean = clean
        .replaceAll('Mo', 'Mon').replaceAll('Tu', 'Tue')
        .replaceAll('We', 'Wed').replaceAll('Th', 'Thu')
        .replaceAll('Fr', 'Fri').replaceAll('Sa', 'Sat')
        .replaceAll('Su', 'Sun').replaceAll('Ph', 'Public Holidays');
    return clean.replaceAll('-', ' - ');
  }

  Future<void> _launchMaps(double lat, double lng) async {
    Uri targetUrl;
    if (Platform.isAndroid) {
      targetUrl = Uri.parse("https://www.google.com/maps/search/?api=1&query=$lat,$lng");
    } else {
      targetUrl = Uri.parse("https://maps.apple.com/?daddr=$lat,$lng");
    }
    try {
      await launchUrl(targetUrl, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint("Could not launch maps: $e");
    }
  }

  void _goToPassport() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PassportCollectionScreen(
          incomingRestaurant: widget.restaurant, 
          initialBookId: null, 
        ),
      ),
    );
  }

  Widget _buildAmenityChip(String label, String emoji, Color bg, Color text) {
    return Container(
      margin: const EdgeInsets.only(right: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(color: text, fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildCuisineTags(String rawCuisines) {
    if (rawCuisines.isEmpty) return const SizedBox.shrink();

    final List<String> categories = rawCuisines
        .split(RegExp(r'[;,/]'))
        .map((e) => e.trim().toLowerCase())
        .where((e) => e.isNotEmpty && e != "other" && e != "n/a")
        .toList();

    final Map<String, String> categoryEmojis = {
      'pizza': '🍕', 'italian': '🇮🇹', 'american': '🇺🇸', 'burger': '🍔',
      'mexican': '🇲🇽', 'taco': '🌮', 'chinese': '🇨🇳', 'asian': '🥢',
      'japanese': '🇯🇵', 'sushi': '🍣', 'indian': '🇮🇳', 'thai': '🇹🇭',
      'french': '🇫🇷', 'bakery': '🥐', 'coffee': '☕', 'cafe': '☕',
      'deli': '🥪', 'sandwich': '🥪', 'bagel': '🥯', 'steak': '🥩',
      'seafood': '🦞', 'bar': '🍷', 'cocktail': '🍸', 'gastropub': '🍺',
      'ice cream': '🍦', 'dessert': '🍰', 'vegan': '🥗', 'vegetarian': '🥦',
      'healthy': '🥑', 'salad': '🥗', 'breakfast': '🍳', 'brunch': '🥂',
      'colombian': '🇨🇴', 'korean': '🇰🇷', 'vietnamese': '🇻🇳', 'mediterranean': '🫒',
      'greek': '🇬🇷', 'spanish': '🇪🇸', 'middle eastern': '🥙', 'halal': '🕌',
      'chicken': '🍗', 'wings': '🍗', 'fast food': '🍟', 'street food': '🌭',
    };

    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: categories.map((cat) {
        final String formattedName = cat[0].toUpperCase() + cat.substring(1);
        final String emoji = categoryEmojis.entries
            .firstWhere((e) => cat.contains(e.key), orElse: () => const MapEntry('', ''))
            .value;

        return Text(
          "• $formattedName $emoji",
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: widget.isDarkMode ? Colors.white70 : Colors.grey[800],
            height: 1.4,
          ),
        );
      }).toList()
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.restaurant;
    final isDark = widget.isDarkMode;

    final List<Widget> amenities = [];

    // Michelin & Bib Gourmand
    if (r.michelinStars == 1) {
      amenities.add(_buildAmenityChip("1 Michelin Star", "⭐", Colors.red.withOpacity(0.1), Colors.red));
    } else if (r.michelinStars == 2) {
      amenities.add(_buildAmenityChip("2 Michelin Stars", "⭐⭐", Colors.red.withOpacity(0.1), Colors.red));
    } else if (r.michelinStars == 3) {
      amenities.add(_buildAmenityChip("3 Michelin Stars", "⭐⭐⭐", Colors.red.withOpacity(0.1), Colors.red));
    }
    if (r.bibGourmand) {
      amenities.add(_buildAmenityChip("Bib Gourmand", "🍽️", Colors.red.withOpacity(0.1), Colors.red));
    }
    if (r.hasMichelin && r.michelinStars == 0 && !r.bibGourmand) {
      amenities.add(_buildAmenityChip("Michelin Guide", "⭐", Colors.red.withOpacity(0.1), Colors.red));
    }

    // Dietary
    if (r.isVegan) {
      amenities.add(_buildAmenityChip("Vegan Friendly", "🌱", Colors.green.withOpacity(0.15), Colors.green[700]!));
    }
    if (r.isVegetarian) {
      amenities.add(_buildAmenityChip("Veg Options", "🥦", Colors.lightGreen.withOpacity(0.15), Colors.green[800]!));
    }

    // Standard Amenities
    if (r.cocktails) amenities.add(_buildAmenityChip("Cocktails", "🍸", Colors.purple.withOpacity(0.1), Colors.purple));
    if (r.reservations) amenities.add(_buildAmenityChip("Reservations", "📅", Colors.blue.withOpacity(0.1), Colors.blue));
    if (r.delivery) amenities.add(_buildAmenityChip("Delivery", "🛵", Colors.green.withOpacity(0.1), Colors.green));
    if (r.takeaway) amenities.add(_buildAmenityChip("Takeaway", "🥡", Colors.orange.withOpacity(0.1), Colors.orange));

    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.90),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
        boxShadow: [const BoxShadow(color: Colors.black26, blurRadius: 20, spreadRadius: 5)],
      ),
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          // 🌟 NEW: Wrap ScrollView in NotificationListener to update metrics immediately
          NotificationListener<ScrollMetricsNotification>(
            onNotification: (notification) {
              _checkScroll();
              return true;
            },
            child: SingleChildScrollView(
              controller: _scrollController, // 🌟 Attached Controller
              physics: const ClampingScrollPhysics(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- IMAGE BANNER ---
                  Stack(
                    children: [
                      SizedBox(
                        height: 250,
                        width: double.infinity,
                        child: AnimatedCuisinePlaceholder(cuisine: r.cuisine),
                      ),
                      Positioned(
                        top: 15, right: 15,
                        child: GestureDetector(
                          onTap: () {
                            widget.onFavoriteToggle();
                            setState(() {
                              _currentSavedStatus = !_currentSavedStatus;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(
                              color: Colors.white, shape: BoxShape.circle,
                              boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10)]
                            ),
                            child: Icon(
                              _currentSavedStatus ? Icons.favorite : Icons.favorite_border,
                              color: _currentSavedStatus ? Colors.red : Colors.grey,
                              size: 24,
                            ),
                          ),
                        ),
                      )
                    ],
                  ),
                  
                  // --- INFO CONTENT ---
                  Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title & Rating
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                r.name,
                                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: isDark ? Colors.white : Colors.black),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (r.rating > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(color: isDark ? Colors.white : Colors.black, borderRadius: BorderRadius.circular(8)),
                                child: Row(
                                  children: [
                                    const Icon(Icons.star, color: Colors.amber, size: 14),
                                    const SizedBox(width: 4),
                                    Text(r.rating.toString(), style: TextStyle(color: isDark ? Colors.black : Colors.white, fontWeight: FontWeight.bold))
                                  ],
                                ),
                              )
                          ],
                        ),
                        const SizedBox(height: 8),
                        
                        // Cuisine & Price
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildCuisineTags(r.cuisine),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Text(
                                  r.price,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? Colors.white : Colors.black
                                  )
                                ),
                                const SizedBox(width: 8),
                                const Icon(Icons.circle, size: 4, color: Colors.grey),
                                const SizedBox(width: 8),
                                if (widget.myLocation != null)
                                  Text(
                                    _getDistanceString(r.location),
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue
                                    )
                                  ),
                              ],
                            ),
                          ],
                        ),
    
                        // Amenities
                        if (amenities.isNotEmpty) ...[
                          const SizedBox(height: 20),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(children: amenities),
                          ),
                        ],
    
                        // Collect Stamp
                        const SizedBox(height: 30),
                        SizedBox(
                          width: double.infinity,
                          height: 55,
                          child: ElevatedButton.icon(
                            onPressed: _goToPassport,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFE53935),
                              foregroundColor: Colors.white,
                              elevation: 8,
                              shadowColor: Colors.redAccent.withOpacity(0.4),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            icon: const Icon(Icons.approval, size: 28),
                            label: const Text(
                              "COLLECT STAMP",
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Center(
                          child: Text(
                            "Add this spot to your passport",
                            style: TextStyle(color: isDark ? Colors.grey[500] : Colors.grey[600], fontSize: 12),
                          ),
                        ),
    
                        // Hours
                        const SizedBox(height: 30),
                        Builder(
                          builder: (context) {
                            if (r.openingHours != null && r.openingHours!.isNotEmpty) {
                              final bool isOpen = r.isOpenNow;
                              final statusColor = isOpen ? Colors.green : Colors.red;
                              final statusBg = isOpen ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1);
                              final statusText = isOpen ? "Open Now" : "Closed Now";
                              
                              return Container(
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: isDark ? Colors.grey[900] : Colors.grey[50],
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: isDark ? Colors.grey[800]! : Colors.grey[200]!),
                                ),
                                child: Column(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                      decoration: BoxDecoration(
                                        color: statusBg,
                                        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(Icons.access_time_filled, color: statusColor, size: 20),
                                          const SizedBox(width: 8),
                                          Text(statusText, style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 15)),
                                        ],
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.all(16.0),
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              _formatOpenHours(r.openingHours!),
                                              style: TextStyle(
                                                color: isDark ? Colors.white70 : Colors.black87,
                                                fontSize: 14,
                                                height: 1.6,
                                                fontFamily: Platform.isIOS ? "Courier" : null,
                                                fontFeatures: Platform.isAndroid
                                                    ? const [FontFeature.tabularFigures()]
                                                    : null,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            } else {
                              return Container(
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: isDark ? Colors.grey[900] : Colors.grey[50],
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: isDark ? Colors.grey[800]! : Colors.grey[200]!),
                                ),
                                child: Column(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                      decoration: BoxDecoration(
                                        color: Colors.amber.withOpacity(0.1),
                                        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.info_outline_rounded, color: Colors.amber, size: 20),
                                          const SizedBox(width: 8),
                                          const Text(
                                            "Verify Hours",
                                            style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 15)
                                          ),
                                        ],
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.all(16.0),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            "Opening times may vary. We recommend checking the latest schedule.",
                                            style: TextStyle(
                                              color: isDark ? Colors.white70 : Colors.black87,
                                              fontSize: 14,
                                              height: 1.4,
                                            ),
                                          ),
                                          const SizedBox(height: 12),
                                          SizedBox(
                                            width: double.infinity,
                                            child: OutlinedButton.icon(
                                              style: OutlinedButton.styleFrom(
                                                foregroundColor: isDark ? Colors.white : Colors.black,
                                                side: BorderSide(color: isDark ? Colors.grey[700]! : Colors.grey[300]!),
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                                padding: const EdgeInsets.symmetric(vertical: 12),
                                              ),
                                              onPressed: () => _searchOnGoogle(r.name),
                                              icon: const Icon(Icons.search, size: 18),
                                              label: const Text("Check on Google"),
                                            ),
                                          )
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }
                          }
                        ),
    
                        const SizedBox(height: 30),
    
                        // Bottom Buttons (Action Row)
                        Padding(
                          padding: EdgeInsets.only(
                            bottom: 12 + MediaQuery.of(context).padding.bottom
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              if (r.phone != null && r.phone!.isNotEmpty) ...[
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: isDark ? Colors.white : Colors.black,
                                    foregroundColor: isDark ? Colors.black : Colors.white,
                                    elevation: 4,
                                    shadowColor: Colors.black.withOpacity(0.4),
                                    shape: const CircleBorder(),
                                    padding: const EdgeInsets.all(16),
                                  ),
                                  onPressed: () => _makePhoneCall(r.phone!),
                                  child: const Icon(CupertinoIcons.phone_fill, size: 24),
                                ),
                                const SizedBox(width: 8),
                              ],
                              if (r.website != null && r.website!.isNotEmpty) ...[
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: isDark ? Colors.white : Colors.black,
                                    foregroundColor: isDark ? Colors.black : Colors.white,
                                    elevation: 4,
                                    shadowColor: Colors.black.withOpacity(0.4),
                                    shape: const CircleBorder(),
                                    padding: const EdgeInsets.all(16),
                                  ),
                                  onPressed: () => _openWebUrl(r.website!),
                                  child: const Icon(CupertinoIcons.globe, size: 24),
                                ),
                                const SizedBox(width: 8),
                              ],
                              Expanded(
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: isDark ? Colors.white : Colors.black,
                                    foregroundColor: isDark ? Colors.black : Colors.white,
                                    elevation: 4,
                                    shadowColor: Colors.black.withOpacity(0.4),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                                    padding: const EdgeInsets.symmetric(vertical: 18),
                                  ),
                                  onPressed: () => _launchMaps(widget.restaurant.location.latitude, widget.restaurant.location.longitude),
                                  child: const FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      "Go There",
                                      style: TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 20,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Handle
          Positioned(
            top: 10,
            child: Container(
              width: 50,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.8),
                borderRadius: BorderRadius.circular(10),
                boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 2)],
              ),
            ),
          ),

          // 🌟 NEW: FLOATING "SCROLL DOWN" BUTTON 🌟
          // Only appears when there is more content below and we aren't at the bottom.
          if (_showScrollButton)
            Positioned(
              bottom: 30 + MediaQuery.of(context).padding.bottom, 
              right: 24,
              child: Material(
                color: Colors.transparent,
                elevation: 10,
                shadowColor: Colors.black45,
                borderRadius: BorderRadius.circular(30),
                child: InkWell(
                  onTap: _scrollToBottom,
                  borderRadius: BorderRadius.circular(30),
                  child: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white : Colors.black,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
                    ),
                    child: Icon(
                      Icons.arrow_downward_rounded,
                      color: isDark ? Colors.black : Colors.white,
                      size: 28,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}