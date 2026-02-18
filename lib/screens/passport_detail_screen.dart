import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PassportDetailScreen extends StatefulWidget {
  final String heroTag; 
  final Widget cardWidget;
  final Color backgroundColor;

  const PassportDetailScreen({
    super.key,
    required this.heroTag,
    required this.cardWidget,
    required this.backgroundColor,
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
  late List<Color> _bgDesigns;

  @override
  void initState() {
    super.initState();
    
    _bgDesigns = [
      widget.backgroundColor,
      const Color(0xFF1E1E1E), 
      const Color(0xFFEFEBE5), 
      const Color(0xFF1B263B), 
      const Color(0xFFFAF0E6), 
      const Color(0xFF0D1B2A)  
    ];

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
    Color currentBgColor = _bgDesigns[_currentBgIndex];
    bool isLightBg = currentBgColor.computeLuminance() > 0.5;

    // 👈 CHANGED: Bulletproof System UI overlay for both iOS and Android
    final overlayStyle = isLightBg 
        ? SystemUiOverlayStyle.dark.copyWith(statusBarColor: Colors.transparent)
        : SystemUiOverlayStyle.light.copyWith(statusBarColor: Colors.transparent);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlayStyle,
      child: Scaffold(
        backgroundColor: Colors.black, 
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
                    _currentBgIndex = (_currentBgIndex + 1) % _bgDesigns.length;
                  });
                },
                child: ScaleTransition(
                  scale: _squishAnimation,
                  child: Container(color: currentBgColor),
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
            )
          ],
        ),
      ),
    );
  }
}