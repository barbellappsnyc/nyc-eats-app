import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../widgets/coordinate_collage_background.dart';
import '../widgets/postage_stamp_background.dart';
import '../widgets/language_collage_background.dart';
import 'package:screenshot/screenshot.dart';
import '../widgets/checkered_background.dart'; // 👈 Your new widget!

import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:gal/gal.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:ui'; // 👈 Required for the ImageFilter.blur
import 'package:flutter/cupertino.dart';

// 🗺️ FAST & FREE BOROUGH CALCULATOR
String getBorough(double lat, double lng) {
  // Rough bounding boxes for NYC Boroughs
  if (lat > 40.70 && lat < 40.88 && lng > -74.02 && lng < -73.91) return "MANHATTAN";
  if (lat > 40.57 && lat < 40.74 && lng > -74.04 && lng < -73.85) return "BROOKLYN";
  if (lat > 40.69 && lat < 40.80 && lng > -73.96 && lng < -73.70) return "QUEENS";
  if (lat > 40.80 && lat < 40.92 && lng > -73.93 && lng < -73.78) return "BRONX";
  if (lat > 40.50 && lat < 40.65 && lng > -74.26 && lng < -74.05) return "STATEN ISLAND";
  return "NEW YORK"; // Fallback
}

class PassportDetailScreen extends StatefulWidget {
  final String heroTag; 
  final Widget cardWidget;
  final Color backgroundColor;

  // 👇 NEW: The Brains!
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
  
  // 1. Change the variable type at the top of the State class:
  int _currentBgIndex = 0;
  
  // 👇 NEW: The Font Engine variables hoisted to the main screen!
  int _fontIndex = 0;
  final List<String> _fonts = [
    'Georgia', 'Helvetica', 'Courier', 'Times New Roman', 'Trebuchet MS'
  ];

  late List<Widget> _bgDesigns; // 👈 CHANGED to Widget
  late List<bool> _bgIsLight;   // 👈 NEW: To track status bar color manually
  final ScreenshotController _cardOnlyController = ScreenshotController();
  final ScreenshotController _fullScreenController = ScreenshotController();

  @override
  void initState() {
    super.initState();

    // 👇 Added one more 'true' at the end for the light grey checkered background
    _bgIsLight = [true, false, true, true, true];
    
    // ... rest of initState

    _squishController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    // 👈 CHANGED: Now animates from 0.0 (normal) to 1.0 (pressed/darkened)
    // Replace this chunk inside initState:
    _squishAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _squishController, curve: Curves.easeInOut),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() {
        _cardPosition = Offset(MediaQuery.of(context).size.width / 2,
            MediaQuery.of(context).size.height / 2);
      });
    });
  }

  // 💾 SAVE TO CAMERA ROLL
  Future<void> _saveToCameraRoll() async {
    try {
      Uint8List? imageBytes;

      // 🧠 The Smart Check: Are we on the Checkered BG?
      if (_currentBgIndex == 4) {
        // Grab ONLY the card (transparent PNG style)
        imageBytes = await _cardOnlyController.capture(pixelRatio: 3.0);
      } else {
        // Grab the Card + The Generative Background
        imageBytes = await _fullScreenController.capture(pixelRatio: 3.0);
      }

      if (imageBytes == null) return;

      // Request permission & save using `gal`
      final bool hasAccess = await Gal.hasAccess();
      if (!hasAccess) await Gal.requestAccess();

      // Write to temporary file, then save to gallery
      final directory = await getTemporaryDirectory();
      final imagePath = '${directory.path}/nyceats_passport_${DateTime.now().millisecondsSinceEpoch}.png';
      final imageFile = File(imagePath);
      await imageFile.writeAsBytes(imageBytes);

      await Gal.putImage(imagePath);

      // Show a success message
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

  // 📲 SHARE TO INSTAGRAM STORY
  Future<void> _shareToStory() async {
    print("🚀 1. Share button tapped!");
    try {
      // 1. Capture the image
      final Uint8List? imageBytes = await _fullScreenController.capture(pixelRatio: 3.0);
      print("📸 2. Image captured! Size: ${imageBytes?.length} bytes");
      
      if (imageBytes == null) {
        print("❌ ERROR: Captured image is null!");
        return;
      }

      // 2. Get temp directory
      final directory = await getTemporaryDirectory();
      print("📂 3. Temp directory found: ${directory.path}");
      
      // 3. Save to file
      final imagePath = '${directory.path}/nyceats_story_${DateTime.now().millisecondsSinceEpoch}.png';
      final imageFile = File(imagePath);
      await imageFile.writeAsBytes(imageBytes);
      print("💾 4. File successfully written to: $imagePath");

      // 4. Get the screen coordinates for the iPad/Simulator popover
      final box = context.findRenderObject() as RenderBox?;
      final Rect? sharePosition = box != null 
          ? box.localToGlobal(Offset.zero) & box.size 
          : null;

      // 5. Trigger Share Sheet with the required anchor
      print("📤 5. Triggering native share sheet...");
      await Share.shareXFiles(
        [XFile(imagePath)],
        text: 'My NYC Eats Passport! 🌎🍽️',
        sharePositionOrigin: sharePosition, // 👈 THE FIX
      );
      print("✅ 6. Share sheet called successfully.");
      
    } catch (e) {
      print("🚨 CRITICAL SHARE ERROR: $e");
    }
  }

  @override
  void dispose() {
    _squishController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 👇 NEW: Builds fresh every time, catching the latest font!
    final List<Widget> bgDesigns = [
      Container(color: widget.backgroundColor), 
      CoordinateCollageBackground(stamps: widget.stamps), 
      LanguageCollageBackground(cuisine: widget.cuisine, currentFont: _fonts[_fontIndex]), 
      PostageStampBackground(cuisine: widget.cuisine), 
      const CheckeredBackground(), // 👈 NEW: The PNG export mode (Index 4)
    ];

    bool isLightBg = _bgIsLight[_currentBgIndex];

    // Bulletproof System UI overlay for both iOS and Android
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
            // 🖼️ THE CAPTURABLE ART (Background + Card)
            Screenshot(
              controller: _fullScreenController,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // 🟩 LAYER 1: THE BACKGROUND 
                  Positioned(
                    top: -100,
                    bottom: -100,
                    left: -100,
                    right: -100,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapDown: (_) => _squishController.forward(),
                      onTapCancel: () => _squishController.reverse(),
                      onTapUp: (_) {
                        _squishController.reverse();
                        setState(() {
                          _currentBgIndex = (_currentBgIndex + 1) % bgDesigns.length;
                        });
                      },
                      // 👈 CHANGED: Removed the ColorFiltered and AnimatedBuilder.
                      // Now it just directly scales the background widget without any dimming!
                      child: ScaleTransition(
                        scale: _squishAnimation,
                        child: bgDesigns[_currentBgIndex], // Renders the actual Widget directly
                      ),
                    ),
                  ),

                  // 🪪 LAYER 2: THE CARD
                  Positioned(
                    left: _cardPosition.dx - 170, 
                    top: _cardPosition.dy - 270,  
                    child: GestureDetector(
                      // Swallow taps so touching the card doesn't trigger the background
                      onTapDown: (_) {},
                      onTapUp: (_) {},
                      onTapCancel: () {},
                      onTap: () {},
                      onScaleStart: (details) {
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
                      child: Transform(
                        alignment: Alignment.center,
                        transform: Matrix4.identity()
                          ..scale(_cardScale)
                          ..rotateZ(_cardRotation),
                        child: Screenshot( // 👈 The Card-Only Capture Controller is safely inside!
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
            
            // ❌ LAYER 3: THE CLOSE BUTTON (Isolated & Smart Color)
            Positioned(
              top: MediaQuery.of(context).padding.top + 10,
              left: 10,
              child: IconButton(
                icon: Icon(
                  Icons.close, 
                  color: isLightBg ? Colors.black : Colors.white,
                  size: 30,
                ),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),

            // 📝 LAYER 4: THE HINT TEXT (Isolated & Smart Color)
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

            // 🔤 LAYER 5: THE FONT TOGGLE BUTTON (Completely Isolated!)
            // Only renders if we are currently looking at the Language background (Index 2)
            if (_currentBgIndex == 2)
              Positioned(
                bottom: 40 + MediaQuery.of(context).padding.bottom, 
                right: 24, // Same horizontal plane as the Hint Text, but on the right edge
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _fontIndex = (_fontIndex + 1) % _fonts.length;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5))
                      ],
                      border: Border.all(color: Colors.white24, width: 1),
                    ),
                    child: const Icon(
                      CupertinoIcons.textformat, 
                      color: Colors.white,
                      size: 26,
                    ),
                  ),
                ),
              ),
            // 📸 LAYER 6: EXPORT & SHARE BUTTONS (Frosted Glass Pill)
            Positioned(
              bottom: 40 + MediaQuery.of(context).padding.bottom,
              left: 0,
              right: 0,
              child: Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(40),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20), // Heavy Apple-style blur
                    child: AnimatedSize(
                      duration: const Duration(milliseconds: 350),
                      curve: Curves.easeOutCubic, // Smooth, spring-like curve
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.grey.withOpacity(0.15), // Very subtle grey tint
                          borderRadius: BorderRadius.circular(40),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.3), // Highlight rim
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // 📥 SAVE BUTTON 
                            IconButton(
                              onPressed: _saveToCameraRoll, 
                              icon: const Icon(CupertinoIcons.arrow_down, size: 30, color: Colors.black), // Clean downward arrow
                              color: Colors.grey[800], // Understated dark grey
                              iconSize: 28,
                              padding: const EdgeInsets.all(12),
                            ),
                            
                            // 📤 SHARE BUTTON (Disappears on Checkered BG)
                            if (_currentBgIndex != 4)
                              IconButton(
                                onPressed: _shareToStory, 
                                icon: const Icon(CupertinoIcons.share, size: 30, color: Colors.black),
                                color: Colors.grey[800], // Matched dark grey
                                iconSize: 28,
                                padding: const EdgeInsets.all(12),
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