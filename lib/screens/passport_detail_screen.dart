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

  late List<bool> _bgIsLight;   
  final ScreenshotController _cardOnlyController = ScreenshotController();
  final ScreenshotController _fullScreenController = ScreenshotController();

  List<Map<String, dynamic>> _mtaStations = [];
  bool _isLoadingStations = true;

  @override
  void initState() {
    super.initState();

    _bgIsLight = [true, false, true, true, false, true];    

    _squishController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    
    _squishAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _squishController, curve: Curves.easeInOut),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() {
        _cardPosition = Offset(MediaQuery.of(context).size.width / 2,
            MediaQuery.of(context).size.height / 2);
      });
    });

    _fetchMtaStations(); 
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

      if (mounted) {
        setState(() {
          _mtaStations = List<Map<String, dynamic>>.from(response);
          _isLoadingStations = false;
        });
      }
    } catch (e) {
      debugPrint("SUPABASE ERROR: $e");
    }
  }

  @override
  void dispose() {
    _squishController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> bgDesigns = [
      Container(color: widget.backgroundColor), 
      CoordinateCollageBackground(stamps: widget.stamps), 
      LanguageCollageBackground(cuisine: widget.cuisine, currentFont: _fonts[_fontIndex]), 
      PostageStampBackground(cuisine: widget.cuisine), 
      MtaBackground(
        stations: _mtaStations, 
        isDarkMode: _isMtaNightMode, 
      ),
      const CheckeredBackground(), 
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
                      child: ScaleTransition(
                        scale: _squishAnimation,
                        child: bgDesigns[_currentBgIndex], 
                      ),
                    ),
                  ),

                  // 🪪 LAYER 2: THE CARD
                  Positioned(
                    left: _cardPosition.dx - 170, 
                    top: _cardPosition.dy - 270,  
                    child: GestureDetector(
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

            // 🔤 LAYER 5A: THE FONT TOGGLE BUTTON (Index 2)
            if (_currentBgIndex == 2)
              Positioned(
                bottom: 40 + MediaQuery.of(context).padding.bottom, 
                right: 24, 
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
                    child: const Icon(CupertinoIcons.textformat, color: Colors.white, size: 26),
                  ),
                ),
              ),

            // 🌗 LAYER 5B: THE DAY/NIGHT TOGGLE BUTTON (Index 4)
            if (_currentBgIndex == 4)
              Positioned(
                bottom: 40 + MediaQuery.of(context).padding.bottom, 
                right: 24, 
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _isMtaNightMode = !_isMtaNightMode;
                      _bgIsLight[4] = !_isMtaNightMode; 
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
                    child: Icon(
                      _isMtaNightMode ? CupertinoIcons.moon_stars_fill : CupertinoIcons.sun_max_fill, 
                      color: _isMtaNightMode ? Colors.indigo[300] : Colors.amber,
                      size: 26,
                    ),
                  ),
                ),
              ),

            // 📸 LAYER 6: EXPORT & SHARE BUTTONS
            Positioned(
              bottom: 40 + MediaQuery.of(context).padding.bottom,
              left: 0,
              right: 0,
              child: Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(40),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20), 
                    child: AnimatedSize(
                      duration: const Duration(milliseconds: 350),
                      curve: Curves.easeOutCubic, 
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.grey.withOpacity(0.15), 
                          borderRadius: BorderRadius.circular(40),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.3), 
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              onPressed: _saveToCameraRoll, 
                              icon: const Icon(CupertinoIcons.arrow_down, size: 30, color: Colors.black), 
                              color: Colors.grey[800], 
                              iconSize: 28,
                              padding: const EdgeInsets.all(12),
                            ),
                            
                              if (_currentBgIndex != 5) 
                              IconButton(
                                onPressed: _shareToStory, 
                                icon: const Icon(CupertinoIcons.share, size: 30, color: Colors.black),
                                color: Colors.grey[800], 
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