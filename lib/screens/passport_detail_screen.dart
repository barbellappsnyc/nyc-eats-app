import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../widgets/coordinate_collage_background.dart';
import '../widgets/postage_stamp_background.dart';
import '../widgets/language_collage_background.dart';


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

  @override
  void initState() {
    super.initState();

    // 👇 Change index 2 to `true` so the status bar icons turn black over our pastel backgrounds!
    _bgIsLight = [true, false, true, true];
    
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
            // 🟩 LAYER 1: THE BACKGROUND (Oversized to hide edges while bouncing)
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

            // 🪪 LAYER 2: THE CARD (Completely isolated)
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
                  child: Hero(
                    tag: widget.heroTag,
                    child: widget.cardWidget,
                  ),
                ),
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
              bottom: 40,
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
                      Icons.text_format_rounded, 
                      color: Colors.white,
                      size: 26,
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