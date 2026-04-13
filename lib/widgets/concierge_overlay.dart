import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/restaurant.dart';
import '../services/telemetry_service.dart';
import '../config/cuisine_constants.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart'; // Needed for HapticFeedback

class ConciergeOverlay extends StatefulWidget {
  final bool isDarkMode;
  final LatLng userLocation;
  final VoidCallback onClose;
  final Function(Restaurant) onRestaurantTapped;

  const ConciergeOverlay({
    super.key,
    required this.isDarkMode,
    required this.userLocation,
    required this.onClose,
    required this.onRestaurantTapped,
  });

  @override
  State<ConciergeOverlay> createState() => _ConciergeOverlayState();
}

class _ConciergeOverlayState extends State<ConciergeOverlay> {
  List<Restaurant> _recommendations = [];
  final Map<int, bool> _interactionState = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _generateRecommendations();
  }

  Future<void> _generateRecommendations() async {
    setState(() => _isLoading = true);

    try {
      // Phase 1: Try a 1-Mile radius
      List<Restaurant> candidates = await _fetchBoundingBox(1.0);

      // Phase 2: If we didn't find enough, expand to 3 miles
      if (candidates.length < 10) {
        candidates = await _fetchBoundingBox(3.0);
      }

      // Filter out corners of the square to make it a true circle
      const Distance distanceCalc = Distance();
      final double maxDistanceMeters = candidates.length >= 10
          ? 1609.0
          : 4828.0;

      List<Restaurant> nearby = candidates.where((r) {
        final double dist = distanceCalc.as(
          LengthUnit.Meter,
          widget.userLocation,
          r.location,
        );
        return dist <= maxDistanceMeters;
      }).toList();

      // Score and Sort
      nearby.sort((a, b) => _scoreRestaurant(b).compareTo(_scoreRestaurant(a)));

      // 🌟 INJECTED: Load previous votes from device memory
      final prefs = await SharedPreferences.getInstance();
      for (var r in nearby) {
        final String memKey = 'concierge_vote_${r.id}';
        if (prefs.containsKey(memKey)) {
          _interactionState[r.id] = prefs.getBool(memKey)!;
        }
      }

      if (mounted) {
        setState(() {
          _recommendations = nearby.take(10).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("🚨 Concierge Fetch Error: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // The Bounding Box Engine
  Future<List<Restaurant>> _fetchBoundingBox(double radiusMiles) async {
    // Approx degrees per mile in NYC
    double latOffset = 0.0145 * radiusMiles;
    double lngOffset = 0.0191 * radiusMiles;

    final data = await Supabase.instance.client
        .from('restaurants')
        .select()
        .gte('lat', widget.userLocation.latitude - latOffset)
        .lte('lat', widget.userLocation.latitude + latOffset)
        .gte('lng', widget.userLocation.longitude - lngOffset)
        .lte('lng', widget.userLocation.longitude + lngOffset);

    return data.map((json) => Restaurant.fromMap(json)).toList();
  }

  int _scoreRestaurant(Restaurant r) {
    int score = 0;
    if (r.michelinStars > 0) score += 1000 * r.michelinStars;
    if (r.hasMichelin) score += 500;
    if (r.bibGourmand) score += 400;

    if (r.price.length == 4) score += 40;
    if (r.price.length == 3) score += 30;
    if (r.price.length == 2) score += 20;
    if (r.price.length == 1) score += 10;

    return score;
  }

  String _getEmoji(String cuisineRaw) {
    String searchKey = cuisineRaw.split(';').first.trim().toLowerCase();
    for (var key in CuisineConstants.emojiPalettes.keys) {
      if (key.toLowerCase() == searchKey) {
        return CuisineConstants.emojiPalettes[key]!.first;
      }
    }
    return '🍽️';
  }

  void _recordFeedback(Restaurant r, bool isInterested) async {
    // 1. Update UI state instantly
    setState(() {
      _interactionState[r.id] = isInterested;
    });

    // 2. Save to permanent device memory
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('concierge_vote_${r.id}', isInterested);

    // 3. Show the sleek confirmation Toast
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                isInterested ? Icons.check_circle : Icons.cancel,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 12),
              Text(
                isInterested
                    ? "Added to your interests! 🌟"
                    : "We'll skip this one.",
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontFamily: 'SFPro',
                ),
              ),
            ],
          ),
          backgroundColor: isInterested
              ? Colors.green[700]
              : Colors.redAccent[700],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          margin: const EdgeInsets.only(bottom: 20, left: 20, right: 20),
          duration: const Duration(seconds: 2),
        ),
      );
    }

    // 4. Send telemetry silently in the background
    TelemetryService.logInteraction(
      actionType: isInterested
          ? 'concierge_interested'
          : 'concierge_not_interested',
      metadata: {
        'restaurant_id': r.id,
        'restaurant_name': r.name,
        'cuisine': r.cuisine,
        'price': r.price,
        'has_michelin': r.hasMichelin,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = widget.isDarkMode;
    final Color textColor = isDark ? Colors.white : Colors.black;

    return Positioned(
      top: 80,
      bottom: 120,
      left: 20,
      right: 20,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.black.withOpacity(0.7)
                  : Colors.white.withOpacity(0.8),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withOpacity(0.2)),
            ),
            child: Column(
              children: [
                // HEADER
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // 🌟 THE FIX: Wrap this entire left side in an Expanded
                      Expanded(
                        child: Row(
                          children: [
                            Icon(
                              Icons.room_service,
                              color: Colors.amber[700],
                              size: 28,
                            ),
                            const SizedBox(width: 10),
                            // 🌟 THE FIX: Wrap the Text in Expanded so it gracefully truncates instead of overflowing
                            Expanded(
                              child: Text(
                                "Recommendations",
                                style: TextStyle(
                                  color: textColor,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'AppleGaramond',
                                  fontStyle: FontStyle.italic,
                                ),
                                maxLines: 1, // 🌟 ADDED
                                overflow: TextOverflow.ellipsis, // 🌟 ADDED
                              ),
                            ),
                          ],
                        ),
                      ),
                      // 🌟 INJECTED: Info Button and Close Button Row
                      Row(
                        children: [
                          IconButton(
                            icon: Icon(
                              Icons.info_outline,
                              color: isDark ? Colors.white54 : Colors.black54,
                            ),
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  backgroundColor: isDark
                                      ? const Color(0xFF2C2C2E)
                                      : Colors.white,
                                  title: Text(
                                    "How it Works",
                                    style: TextStyle(
                                      fontFamily: 'AppleGaramond',
                                      fontWeight: FontWeight.bold,
                                      color: textColor,
                                    ),
                                  ),
                                  // 👇 YOUR NEW, FRIENDLY COPY 👇
                                  content: Text(
                                    "Help us learn your tastes!\n\n"
                                    "Tap ✅ if a spot looks good, or ❌ to pass. This helps the Concierge learn your vibe so we can suggest even better spots to you next time!",
                                    style: TextStyle(
                                      height: 1.4,
                                      color: textColor,
                                    ),
                                  ),
                                  // 👆 ---------------------- 👆
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: Text(
                                        "Got it",
                                        style: TextStyle(
                                          color: Colors.amber[700],
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                          IconButton(
                            icon: Icon(Icons.close, color: textColor),
                            onPressed: widget.onClose,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                Divider(color: Colors.grey.withOpacity(0.3), height: 1),

                // LIST OR LOADER
                Expanded(
                  child: _isLoading
                      ? const Center(
                          child: CupertinoActivityIndicator(radius: 16),
                        )
                      : _recommendations.isEmpty
                      ? Center(
                          child: Text(
                            "The Concierge is resting.\nNo matches found nearby.",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: isDark
                                  ? Colors.grey[400]
                                  : Colors.grey[600],
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: _recommendations.length,
                          itemBuilder: (context, index) {
                            final r = _recommendations[index];
                            final bool? votedState = _interactionState[r.id];

                            return InkWell(
                              onTap: () => widget.onRestaurantTapped(r),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                child: Row(
                                  children: [
                                    // Emoji
                                    Container(
                                      width: 40,
                                      height: 40,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: isDark
                                            ? Colors.grey[800]
                                            : Colors.grey[200],
                                        shape: BoxShape.circle,
                                      ),
                                      child: Text(
                                        _getEmoji(r.cuisine),
                                        style: const TextStyle(fontSize: 20),
                                      ),
                                    ),
                                    const SizedBox(width: 12),

                                    // Details
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            r.name,
                                            style: TextStyle(
                                              color: textColor,
                                              fontWeight: FontWeight.bold,
                                              fontSize:
                                                  18, // Bumped up slightly
                                              fontFamily:
                                                  'AppleGaramond', // 🌟 ADDED FONT
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            "${r.cuisine.split(';').first} • ${r.price}",
                                            style: TextStyle(
                                              color: isDark
                                                  ? Colors.grey[400]
                                                  : Colors.grey[600],
                                              fontSize: 13,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                    // Action Buttons
                                    if (votedState == null) ...[
                                      // 🌟 THE FIX: Call the custom Animation Engine
                                      SparkleActionArea(
                                        onVote: (isInterested) =>
                                            _recordFeedback(r, isInterested),
                                      ),
                                    ] else ...[
                                      // ... (Keep your beautiful Rest State Badge exactly as is)
                                      // 🌟 THE NEW REST STATE: A stylish, non-faded badge
                                      AnimatedSwitcher(
                                        duration: const Duration(
                                          milliseconds: 300,
                                        ),
                                        child: Container(
                                          key: ValueKey<bool>(votedState),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: votedState
                                                ? Colors.green.withOpacity(0.15)
                                                : Colors.redAccent.withOpacity(
                                                    0.15,
                                                  ),
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            border: Border.all(
                                              color: votedState
                                                  ? Colors.green.withOpacity(
                                                      0.3,
                                                    )
                                                  : Colors.redAccent
                                                        .withOpacity(0.3),
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                votedState
                                                    ? "Interested"
                                                    : "Skipped",
                                                style: TextStyle(
                                                  color: votedState
                                                      ? Colors.green
                                                      : Colors.redAccent,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 12,
                                                ),
                                              ),
                                              const SizedBox(width: 4),
                                              Icon(
                                                votedState
                                                    ? Icons.check_circle
                                                    : Icons.cancel,
                                                color: votedState
                                                    ? Colors.green
                                                    : Colors.redAccent,
                                                size: 14,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
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
}

// ============================================================================
// ✨ CUSTOM SPARKLE & BUMP ANIMATION ENGINE
// ============================================================================

class SparkleActionArea extends StatefulWidget {
  final Function(bool) onVote;
  const SparkleActionArea({super.key, required this.onVote});

  @override
  State<SparkleActionArea> createState() => _SparkleActionAreaState();
}

class _SparkleActionAreaState extends State<SparkleActionArea>
    with SingleTickerProviderStateMixin {
  bool? _animatingVote;
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    // The animation takes 700ms total to bump, shoot sparkles, and fade the other button
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onVote(
          _animatingVote!,
        ); // Triggers the badge swap AFTER the animation finishes
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _triggerVote(bool isCheck) {
    if (_animatingVote != null) return; // Prevent double-taps
    HapticFeedback.mediumImpact();
    setState(() => _animatingVote = isCheck);
    _controller.forward();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final progress = _controller.value;

        // 📈 THE BUMP MATH: Peaks at 1.3x scale around 30% of the way through the animation
        final bump = progress < 0.6 ? sin((progress / 0.6) * pi) * 0.3 : 0.0;
        final scaleCheck = _animatingVote == true ? 1.0 + bump : 1.0;
        final scaleCross = _animatingVote == false ? 1.0 + bump : 1.0;

        // 💨 THE FADE MATH: The unselected button shrinks and vanishes
        final hideCheck = _animatingVote == false ? 1.0 - progress : 1.0;
        final hideCross = _animatingVote == true ? 1.0 - progress : 1.0;

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ❌ CROSS BUTTON (Red)
            if (hideCross > 0.0)
              Opacity(
                opacity: hideCross.clamp(0.0, 1.0),
                child: Transform.scale(
                  scale: scaleCross * hideCross.clamp(0.5, 1.0),
                  child: Stack(
                    alignment: Alignment.center,
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: const Icon(
                            Icons.close,
                            color: Colors.redAccent,
                            size: 20,
                          ),
                          onPressed: () => _triggerVote(false),
                        ),
                      ),
                      if (_animatingVote == false)
                        Positioned.fill(
                          child: CustomPaint(
                            painter: SparklePainter(
                              progress: progress,
                              isUp: false,
                              color: Colors.redAccent,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

            // ✅ CHECK BUTTON (Green)
            if (hideCheck > 0.0)
              Opacity(
                opacity: hideCheck.clamp(0.0, 1.0),
                child: Transform.scale(
                  scale: scaleCheck * hideCheck.clamp(0.5, 1.0),
                  child: Stack(
                    alignment: Alignment.center,
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: const Icon(
                            Icons.check,
                            color: Colors.green,
                            size: 20,
                          ),
                          onPressed: () => _triggerVote(true),
                        ),
                      ),
                      if (_animatingVote == true)
                        Positioned.fill(
                          child: CustomPaint(
                            painter: SparklePainter(
                              progress: progress,
                              isUp: true,
                              color: Colors.green,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class SparklePainter extends CustomPainter {
  final double progress;
  final bool isUp;
  final Color color;

  SparklePainter({
    required this.progress,
    required this.isUp,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (progress == 0 || progress == 1) return;

    final paint = Paint()
      ..color = color.withOpacity((1.0 - progress).clamp(0.0, 1.0));
    final center = Offset(size.width / 2, size.height / 2);

    // 🧭 DIRECTION: -1 goes UP, 1 goes DOWN
    final dir = isUp ? -1.0 : 1.0;
    final distance = progress * 35.0; // How far the sparkles travel

    // Draw 3 dynamic particles that expand and fade
    canvas.drawCircle(
      center + Offset(0, distance * dir),
      3.0 * (1 - progress),
      paint,
    ); // Center particle
    canvas.drawCircle(
      center + Offset(-distance * 0.7, distance * 0.8 * dir),
      2.0 * (1 - progress),
      paint,
    ); // Left particle
    canvas.drawCircle(
      center + Offset(distance * 0.7, distance * 0.8 * dir),
      2.5 * (1 - progress),
      paint,
    ); // Right particle
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
