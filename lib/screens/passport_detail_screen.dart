import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../widgets/coordinate_collage_background.dart';
import '../widgets/postage_stamp_background.dart';
import '../widgets/language_collage_background.dart';
import 'package:screenshot/screenshot.dart';
import '../widgets/checkered_background.dart'; 

import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:gal/gal.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:ui'; 
import 'package:flutter/cupertino.dart';
import '../widgets/mta_background.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/warhol_background.dart';

// 🗺️ FAST & FREE BOROUGH CALCULATOR
String getBorough(double lat, double lng) {
  if (lat > 40.70 && lat < 40.88 && lng > -74.02 && lng < -73.91) return "MANHATTAN";
  if (lat > 40.57 && lat < 40.74 && lng > -74.04 && lng < -73.85) return "BROOKLYN";
  if (lat > 40.69 && lat < 40.80 && lng > -73.96 && lng < -73.70) return "QUEENS";
  if (lat > 40.80 && lat < 40.92 && lng > -73.93 && lng < -73.78) return "BRONX";
  if (lat > 40.50 && lat < 40.65 && lng > -74.26 && lng < -74.05) return "STATEN ISLAND";
  return "NEW YORK"; 
}

class PassportDetailScreen extends StatefulWidget {
  final String heroTag; 
  final Widget cardWidget;
  final Color backgroundColor;
  final String cuisine;
  final List<Map<String, String>> stamps;

  const PassportDetailScreen({
    super.key,
    required this.heroTag,
    required this.cardWidget,
    required this.backgroundColor,
    required this.cuisine,
    required this.stamps,
  });

  @override
  State<PassportDetailScreen> createState() => _PassportDetailScreenState();
}

class _PassportDetailScreenState extends State<PassportDetailScreen> with SingleTickerProviderStateMixin {
  Offset _cardPosition = Offset.zero;
  double _cardScale = 0.85;
  double _cardRotation = 0.0;

  Offset _baseCardPosition = Offset.zero;
  double _baseScale = 0.85;
  double _baseRotation = 0.0;
  Offset _startFocalPoint = Offset.zero;

  late AnimationController _squishController;
  late Animation<double> _squishAnimation;
  
  int _currentBgIndex = 0;
  bool _isMtaNightMode = true; 
  
  int _fontIndex = 0;
  final List<String> _fonts = [
    'Georgia', 'Helvetica', 'Courier', 'Times New Roman', 'Trebuchet MS'
  ];

  // 🏎️ NEW: Tells the animation to turn off when your finger is actively dragging
  bool _isDragging = false;
  
  late List<bool> _bgIsLight;   
  final ScreenshotController _cardOnlyController = ScreenshotController();
  final ScreenshotController _fullScreenController = ScreenshotController();

  List<Map<String, dynamic>> _mtaStations = [];
  bool _isLoadingStations = true;

  bool _isPositionInitialized = false; // 👈 NEW: Tracks the first frame

  @override
  void initState() {
    super.initState();

    _bgIsLight = [true, false, true, true, false, true, false];

    _squishController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    
    _squishAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _squishController, curve: Curves.easeInOut),
    );

    // 🛑 REMOVED: The post-frame callback that caused the Hero snap glitch
    _fetchMtaStations(); 
  }

  // 🪄 FIX 2: This fires BEFORE the first frame paints, giving the Hero a perfect landing pad
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isPositionInitialized) {
      final size = MediaQuery.of(context).size;
      _cardPosition = Offset(size.width / 2, size.height / 2);
      _cardScale = 0.85; // Standard resting scale
      _isPositionInitialized = true;
    }
  }

  void _updateDefaultCardPosition() {
    final size = MediaQuery.of(context).size;
    setState(() {
      if (_currentBgIndex == 4) {
        double targetY = size.height / 2; // Default vertical center
        
        // 🛑 BUG 2 FIX: If there are 1 or 3 MTA stations, they layout at the 
        // top of the screen. We shift the passport card down to 65% of the 
        // screen height so it doesn't cover them and trigger the opacity fade!
        if (_mtaStations.length == 1 || _mtaStations.length == 3) {
          targetY = size.height * 0.65; 
        }

        _cardPosition = Offset(size.width / 2, targetY);
        _cardScale = 1.0; 
        _cardRotation = 0.0; // 👈 Forces the tilt to snap perfectly upright
      }
    });
  }

  Future<void> _saveToCameraRoll() async {
    try {
      Uint8List? imageBytes;

      if (_currentBgIndex == 5) {
        imageBytes = await _cardOnlyController.capture(pixelRatio: 3.0);
      } else {
        imageBytes = await _fullScreenController.capture(pixelRatio: 3.0);
      }

      if (imageBytes == null) return;

      final bool hasAccess = await Gal.hasAccess();
      if (!hasAccess) await Gal.requestAccess();

      final directory = await getTemporaryDirectory();
      final imagePath = '${directory.path}/nyceats_passport_${DateTime.now().millisecondsSinceEpoch}.png';
      final imageFile = File(imagePath);
      await imageFile.writeAsBytes(imageBytes);

      await Gal.putImage(imagePath);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Saved to Camera Roll! 📸"),
            backgroundColor: Color(0xFF1A237E),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint("Save error: $e");
    }
  }

  Future<void> _shareToStory() async {
    try {
      final Uint8List? imageBytes = await _fullScreenController.capture(pixelRatio: 3.0);
      if (imageBytes == null) return;

      final directory = await getTemporaryDirectory();
      final imagePath = '${directory.path}/nyceats_story_${DateTime.now().millisecondsSinceEpoch}.png';
      final imageFile = File(imagePath);
      await imageFile.writeAsBytes(imageBytes);

      final box = context.findRenderObject() as RenderBox?;
      final Rect? sharePosition = box != null 
          ? box.localToGlobal(Offset.zero) & box.size 
          : null;

      await Share.shareXFiles(
        [XFile(imagePath)],
        text: 'My NYC Eats Passport! 🌎🍽️',
        sharePositionOrigin: sharePosition, 
      );
      
    } catch (e) {
      debugPrint("🚨 CRITICAL SHARE ERROR: $e");
    }
  }

  Future<void> _fetchMtaStations() async {
    final List<String> stationIds = widget.stamps
        .map((stamp) => stamp['mta_station_id']?.toString())
        .where((id) => id != null && id.isNotEmpty)
        .cast<String>()
        .toSet()
        .toList();

    if (stationIds.isEmpty) {
      setState(() => _isLoadingStations = false);
      return;
    }

    try {
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('mta_stations')
          .select()
          .inFilter('id', stationIds); 

      // Inside your _fetchMtaStations() method, find the setState block and add this:
      if (mounted) {
        setState(() {
          _mtaStations = List<Map<String, dynamic>>.from(response);
          _isLoadingStations = false;
        });
        // 👇 NEW: Fire the positioner once the data actually loads
        _updateDefaultCardPosition(); 
      }
    } catch (e) {
      debugPrint("SUPABASE ERROR: $e");
    }
  }

  // 💧 THE LIQUID GLASS BUTTON (iOS 18 / iPhone 17 Control Center Style)
  Widget _buildGroovedButton({
    required IconData icon,
    required VoidCallback onTap,
    Color color = Colors.white,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          // A soft shadow to float the glass bead off the pill
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipOval(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25), // Independent glass distortion
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                // 🧊 The Liquid Volume: Bright highlight top-left, fading to transparent
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withOpacity(0.45), // Specular light catch on the top-left
                    Colors.white.withOpacity(0.10), // The milky center
                    Colors.white.withOpacity(0.0),  // Deep transparency on the bottom-right
                  ],
                  stops: const [0.0, 0.4, 1.0],
                ),
                // ✨ The Glowing Edge
                border: Border.all(
                  color: Colors.white.withOpacity(0.4), // Glossy rim
                  width: 1.2, // Slightly thicker for that curved glass feel
                ),
              ),
              child: Icon(icon, size: 26, color: color),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _squishController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {

    // 1. ADD THIS AT THE TOP OF THE BUILD METHOD
    final double cardWidth = (MediaQuery.of(context).size.width * 0.85).clamp(300.0, 400.0);
    final double cardHeight = cardWidth * (540 / 340);

    final List<Widget> bgDesigns = [
      Container(color: widget.backgroundColor), 
      CoordinateCollageBackground(stamps: widget.stamps), 
      LanguageCollageBackground(cuisine: widget.cuisine, currentFont: _fonts[_fontIndex]), 
      PostageStampBackground(cuisine: widget.cuisine), 
      // ... inside your bgDesigns array ...
      MtaBackground(
        stations: _mtaStations, 
        isDarkMode: _isMtaNightMode, 
        passportPosition: _cardPosition,
        passportScale: _cardScale,
        isDragging: _isDragging, // 👈 NEW: Pass the state down!
      ),
      // ...
      const CheckeredBackground(), 
      // 🎨 NEW: THE WARHOL POP-ART BACKGROUND
      WarholBackground(cuisine: widget.cuisine),
    ];

    bool isLightBg = _bgIsLight[_currentBgIndex];

    final overlayStyle = isLightBg 
        ? SystemUiOverlayStyle.dark.copyWith(statusBarColor: Colors.transparent)
        : SystemUiOverlayStyle.light.copyWith(statusBarColor: Colors.transparent);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlayStyle,
      child: Scaffold(
        backgroundColor: Colors.white, 
        body: Stack(
          fit: StackFit.expand,
          children: [
            // 🖼️ THE CAPTURABLE ART
            Screenshot(
              controller: _fullScreenController,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // 🟩 LAYER 1: THE BACKGROUND 
                  Positioned(
                    // 🪄 THE FIX: Remove the 100px overflow ONLY for the MTA screen
                    top: _currentBgIndex == 4 ? 0 : -100,
                    bottom: _currentBgIndex == 4 ? 0 : -100,
                    left: _currentBgIndex == 4 ? 0 : -100,
                    right: _currentBgIndex == 4 ? 0 : -100,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapDown: (_) => _squishController.forward(),
                      onTapCancel: () => _squishController.reverse(),
                      onTapUp: (_) {
                        _squishController.reverse();
                        setState(() {
                          _currentBgIndex = (_currentBgIndex + 1) % bgDesigns.length;
                        });
                        // 👇 THE FIX: Re-calculate and snap the card to its ideal spot for the new background
                        _updateDefaultCardPosition();
                      },
                      child: ScaleTransition(
                        scale: _squishAnimation,
                        child: bgDesigns[_currentBgIndex], 
                      ),
                    ),
                  ),

                  // 🪪 LAYER 2: THE CARD
                  AnimatedPositioned(
                    duration: _isDragging ? Duration.zero : const Duration(milliseconds: 600),
                    curve: Curves.easeOutExpo,
                    // Dynamic center math (fixing the hardcoded 170/270)
                    left: _cardPosition.dx - (cardWidth / 2), 
                    top: _cardPosition.dy - (cardHeight / 2),
                    width: cardWidth,   // 👈 Explicit width for proper centering
                    height: cardHeight, // 👈 Explicit height for proper centering
                    child: GestureDetector(
                      onTapDown: (_) {},
                      onTapUp: (_) {},
                      onTapCancel: () {},
                      onTap: () {},
                      onScaleStart: (details) {
                        setState(() => _isDragging = true); 
                        _baseCardPosition = _cardPosition;
                        _startFocalPoint = details.focalPoint;
                        _baseScale = _cardScale;
                        _baseRotation = _cardRotation;
                      },
                      onScaleUpdate: (details) {
                        setState(() {
                          final Offset delta = details.focalPoint - _startFocalPoint;
                          _cardPosition = _baseCardPosition + delta;
                          _cardScale = (_baseScale * details.scale).clamp(0.4, 2.0);
                          _cardRotation = _baseRotation + details.rotation;
                        });
                      },
                      onScaleEnd: (details) {
                        setState(() {
                           _isDragging = false; 
                           // 🪄 THE SPRING-BACK: Re-added for the MTA background!
                           if (_currentBgIndex == 4) {
                              _updateDefaultCardPosition(); 
                           }
                        });
                      },
                      // 🪄 FIX 1: Replaced Transform with AnimatedContainer
                      child: AnimatedContainer(
                        duration: _isDragging ? Duration.zero : const Duration(milliseconds: 600),
                        curve: Curves.easeOutExpo,
                        alignment: Alignment.center,
                        transformAlignment: Alignment.center, // 👈 CRITICAL: Rotates purely from the center
                        transform: Matrix4.identity()
                          ..scale(_cardScale)
                          ..rotateZ(_cardRotation),
                        child: Screenshot( 
                          controller: _cardOnlyController,
                          child: Hero(
                            tag: widget.heroTag,
                            child: widget.cardWidget,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // 🔙 LAYER 3: THE BACK BUTTON
            Positioned(
              top: MediaQuery.of(context).padding.top + 10,
              left: 16,
              child: GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(30),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.4), 
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
                      ),
                      child: const Icon(
                        Icons.arrow_back_ios_new, 
                        color: Colors.white, 
                        size: 22,
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // 📝 LAYER 4: THE HINT TEXT
            Positioned(
              bottom: 100,
              left: 0,
              right: 0,
              child: Center(
                child: Text(
                  "Pinch to resize · Twist to rotate",
                  style: TextStyle(
                      color: isLightBg ? Colors.grey[600] : Colors.grey[400], 
                      fontStyle: FontStyle.italic),
                ),
              ),
            ),
            // 📸 LAYER 5: THE UNIFIED DYNAMIC CONTROL PILL
            Positioned(
              bottom: 40 + MediaQuery.of(context).padding.bottom,
              left: 0,
              right: 0,
              child: Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(40),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30), 
                    child: AnimatedSize(
                      duration: const Duration(milliseconds: 350),
                      curve: Curves.easeOutCubic, 
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          // A much softer, faint tray to let the liquid buttons pop
                          color: Colors.black.withOpacity(0.15), 
                          borderRadius: BorderRadius.circular(40),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.15), // Very faint rim
                            width: 0.5,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // ⬇️ ALWAYS VISIBLE: Download (Now on the Left)
                            _buildGroovedButton(
                              icon: CupertinoIcons.arrow_down,
                              onTap: _saveToCameraRoll,
                            ),
                            
                            // ↗️ CONDITIONAL: Share (Now Middle-Left)
                            if (_currentBgIndex != 5) 
                              _buildGroovedButton(
                                icon: CupertinoIcons.share,
                                onTap: _shareToStory,
                              ),

                            // 🔤 CONDITIONAL: Font Toggle (Now on the Right)
                            if (_currentBgIndex == 2)
                              _buildGroovedButton(
                                icon: CupertinoIcons.textformat,
                                onTap: () {
                                  setState(() {
                                    _fontIndex = (_fontIndex + 1) % _fonts.length;
                                  });
                                },
                              ),

                            // 🌗 CONDITIONAL: Day/Night Toggle (Now on the Right)
                            if (_currentBgIndex == 4)
                              _buildGroovedButton(
                                icon: _isMtaNightMode ? CupertinoIcons.moon_stars_fill : CupertinoIcons.sun_max_fill,
                                color: _isMtaNightMode ? Colors.indigo[300]! : Colors.amber,
                                onTap: () {
                                  setState(() {
                                    _isMtaNightMode = !_isMtaNightMode;
                                    _bgIsLight[4] = !_isMtaNightMode; 
                                  });
                                },
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}