import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nyc_eats/widgets/backgrounds/baggage_tag_background.dart';
import 'package:nyc_eats/widgets/backgrounds/tablecloth_background.dart';
import '../widgets/backgrounds/coordinate_collage_background.dart';
import '../widgets/backgrounds/postage_stamp_background.dart';
import '../widgets/backgrounds/language_collage_background.dart';
import 'package:screenshot/screenshot.dart';
import '../widgets/backgrounds/checkered_background.dart'; 

import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:gal/gal.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:ui'; 
import 'package:flutter/cupertino.dart';
import '../widgets/backgrounds/mta_background.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/backgrounds/warhol_background.dart';

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

  bool _isDragging = false;
  
  late List<bool> _bgIsLight;   
  final ScreenshotController _cardOnlyController = ScreenshotController();
  final ScreenshotController _fullScreenController = ScreenshotController();

  List<Map<String, dynamic>> _mtaStations = [];
  bool _isLoadingStations = true;

  bool _isPositionInitialized = false; 

  @override
  void initState() {
    super.initState();

    // Updated array length to match the 9 backgrounds
    _bgIsLight = [true, true, true, false, true, true, false, true, false];

    _squishController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    
    _squishAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _squishController, curve: Curves.easeInOut),
    );

    _fetchMtaStations(); 
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isPositionInitialized) {
      final size = MediaQuery.of(context).size;
      _cardPosition = Offset(size.width / 2, size.height / 2);
      _cardScale = 0.85; 
      _isPositionInitialized = true;
    }
  }

  // 🪄 THE FIX: Now it needs to know where it came from
  void _updateDefaultCardPosition(int previousIndex) {
    final size = MediaQuery.of(context).size;
    setState(() {
      // 1. ENTERING MTA: Snap down out of the way
      if (_currentBgIndex == 6) { 
        double targetY = size.height / 2; 
        if (_mtaStations.length == 1 || _mtaStations.length == 3) {
          targetY = size.height * 0.65; 
        }
        _cardPosition = Offset(size.width / 2, targetY);
        _cardScale = 1.0; 
        _cardRotation = 0.0; 
      } 
      // 2. EXITING MTA: Smoothly reset to the center
      else if (previousIndex == 6) {
        _cardPosition = Offset(size.width / 2, size.height / 2);
        _cardScale = 0.85; 
        _cardRotation = 0.0; 
      }
      // 3. ANY OTHER CHANGE: Do absolutely nothing. Keep the user's custom layout!
    });
  }

  Future<void> _saveToCameraRoll() async {
    try {
      Uint8List? imageBytes;

      // 👈 REWIRED: Checkered Background is now at Index 7
      if (_currentBgIndex == 7) { 
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
        
        // 🪄 THE FIX: Pass -1 to satisfy the argument requirement without triggering the reset logic
        _updateDefaultCardPosition(-1); 
      }
    } catch (e) {
      debugPrint("SUPABASE ERROR: $e");
    }
  }

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
            filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25), 
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withOpacity(0.45), 
                    Colors.white.withOpacity(0.10), 
                    Colors.white.withOpacity(0.0),  
                  ],
                  stops: const [0.0, 0.4, 1.0],
                ),
                border: Border.all(
                  color: Colors.white.withOpacity(0.4), 
                  width: 1.2, 
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

    final double cardWidth = (MediaQuery.of(context).size.width * 0.85).clamp(300.0, 400.0);
    final double cardHeight = cardWidth * (540 / 340);

    final List<Widget> bgDesigns = [
      Container(color: widget.backgroundColor), // Index 0
      BaggageTagBackground(cuisine: widget.cuisine, stamps: widget.stamps), // Index 1
      const PizzeriaTableclothBackground(), // Index 2
      CoordinateCollageBackground(stamps: widget.stamps), // Index 3
      LanguageCollageBackground(cuisine: widget.cuisine, currentFont: _fonts[_fontIndex]), // Index 4
      
      // 🪄 THE FIX: RepaintBoundary completely eliminates the drag lag
      RepaintBoundary(
        child: PostageStampBackground(cuisine: widget.cuisine), 
      ), // Index 5
      
      MtaBackground( // Index 6
        stations: _mtaStations, 
        isDarkMode: _isMtaNightMode, 
        passportPosition: _cardPosition,
        passportScale: _cardScale,
        isDragging: _isDragging, 
      ),
      const CheckeredBackground(), // Index 7
      WarholBackground(cuisine: widget.cuisine), // Index 8
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
            Screenshot(
              controller: _fullScreenController,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Positioned(
                    // 👈 REWIRED: Remove overflow only for MTA at Index 6
                    top: _currentBgIndex == 6 ? 0 : -100,
                    bottom: _currentBgIndex == 6 ? 0 : -100,
                    left: _currentBgIndex == 6 ? 0 : -100,
                    right: _currentBgIndex == 6 ? 0 : -100,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapDown: (_) => _squishController.forward(),
                      onTapCancel: () => _squishController.reverse(),
                      onTapUp: (_) {
                        _squishController.reverse();
                        
                        // 🪄 THE FIX: Save the current state before flipping the page
                        int prevIndex = _currentBgIndex; 
                        
                        setState(() {
                          _currentBgIndex = (_currentBgIndex + 1) % bgDesigns.length;
                        });
                        
                        // Pass the history to the smart positioner
                        _updateDefaultCardPosition(prevIndex);
                      },
                      child: ScaleTransition(
                        scale: _squishAnimation,
                        child: bgDesigns[_currentBgIndex], 
                      ),
                    ),
                  ),

                  // 🪪 LAYER 2: THE CARD
                  AnimatedPositioned(
                    // 🪄 THE FIX: Snappier 450ms duration
                    duration: _isDragging ? const Duration(milliseconds: 1) : const Duration(milliseconds: 450),
                    curve: _isDragging ? Curves.linear : Curves.easeInOutCubic,
                    left: _cardPosition.dx - (cardWidth / 2), 
                    top: _cardPosition.dy - (cardHeight / 2),
                    width: cardWidth,   
                    height: cardHeight, 
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
                           // 🪄 THE FIX: Pass -1 as the previous index so it just triggers the "Entering MTA" logic to snap back
                           if (_currentBgIndex == 6) {
                              _updateDefaultCardPosition(-1); 
                           }
                        });
                      },
                      child: AnimatedContainer(
                        // 🪄 THE FIX: Match the snappier 450ms duration
                        duration: _isDragging ? const Duration(milliseconds: 1) : const Duration(milliseconds: 450),
                        curve: _isDragging ? Curves.linear : Curves.easeInOutCubic,
                        alignment: Alignment.center,
                        transformAlignment: Alignment.center, 
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
                          color: Colors.black.withOpacity(0.15), 
                          borderRadius: BorderRadius.circular(40),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.15), 
                            width: 0.5,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildGroovedButton(
                              icon: CupertinoIcons.arrow_down,
                              onTap: _saveToCameraRoll,
                            ),
                            
                            // 👈 REWIRED: Hidden for Checkered Background (Index 7)
                            if (_currentBgIndex != 7) 
                              _buildGroovedButton(
                                icon: CupertinoIcons.share,
                                onTap: _shareToStory,
                              ),

                            // 👈 REWIRED: Shows Font Toggle for Language Background (Index 4)
                            if (_currentBgIndex == 4)
                              _buildGroovedButton(
                                icon: CupertinoIcons.textformat,
                                onTap: () {
                                  setState(() {
                                    _fontIndex = (_fontIndex + 1) % _fonts.length;
                                  });
                                },
                              ),

                            // 👈 REWIRED: Shows Day/Night Toggle for MTA Background (Index 6)
                            if (_currentBgIndex == 6)
                              _buildGroovedButton(
                                icon: _isMtaNightMode ? CupertinoIcons.moon_stars_fill : CupertinoIcons.sun_max_fill,
                                color: _isMtaNightMode ? Colors.indigo[300]! : Colors.amber,
                                onTap: () {
                                  setState(() {
                                    _isMtaNightMode = !_isMtaNightMode;
                                    _bgIsLight[6] = !_isMtaNightMode; 
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