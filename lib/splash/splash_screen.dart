import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:nyc_eats/screens/map_screen.dart';
import 'package:flutter/services.dart'; // 👈 Required for system sounds and haptics

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  // 🌍 1. The Global Passport Phrases
  final List<Map<String, String>> _phrases = [
    {'phrase': 'Itadakimasu.', 'translation': 'I humbly receive.'},
    {'phrase': 'Bon Appétit.', 'translation': 'Enjoy your meal.'},
    {'phrase': 'Buen Provecho.', 'translation': 'Good benefit.'},
    {'phrase': '¡Salud!', 'translation': 'To your health.'},
    {'phrase': 'Mangia bene.', 'translation': 'Eat well.'},
    {'phrase': 'Skål!', 'translation': 'Good health.'},
    {'phrase': 'L\'chaim!', 'translation': 'To life.'},
  ];

  late String _selectedPhrase;
  late String _selectedTranslation;

  // ⏱️ 2. Animation Trackers
  int _typewriterIndex = 0;
  bool _showCursor = true;
  bool _typingComplete = false;
  bool _showLogo = false;

  late Timer _typewriterTimer;
  late Timer _cursorTimer;

  @override
  void initState() {
    super.initState();
    
    // Pick a random phrase on boot
    final random = Random();
    final item = _phrases[random.nextInt(_phrases.length)];
    _selectedPhrase = item['phrase']!;
    _selectedTranslation = item['translation']!;

    // Start the blinking cursor immediately
    _cursorTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (mounted) setState(() => _showCursor = !_showCursor);
    });

    // Kick off the sequence
    _startSequence();
  }

  Future<void> _startSequence() async {
    // 1. Brief pause on the dark map before typing starts
    await Future.delayed(const Duration(milliseconds: 600));

    // 2. Type out phrase character by character
    final fullLength = _selectedPhrase.length;
    _typewriterTimer = Timer.periodic(const Duration(milliseconds: 110), (timer) {
      if (_typewriterIndex < fullLength) {
        setState(() => _typewriterIndex++);
        
        // 🔊 The Apple Tap Sound & Haptic
        SystemSound.play(SystemSoundType.click);
        HapticFeedback.selectionClick(); 
        
      } else {
        timer.cancel();
        _finishPhaseOne();
      }
    });
  }

  Future<void> _finishPhaseOne() async {
    setState(() => _typingComplete = true);

    // 3. Pause to let the user read the phrase and translation
    await Future.delayed(const Duration(milliseconds: 1800));

    // 4. Fade out the phrase and fade in the NYC Eats Logo
    if (mounted) {
      setState(() => _showLogo = true);
    }

    // 5. Hold the logo on screen for a moment
    await Future.delayed(const Duration(milliseconds: 2000));

    // 6. 🟢 Seamlessly push to your Auth Screen!
    if (mounted) {
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation1, animation2) => const MapScreen(),
          transitionDuration: const Duration(milliseconds: 1000),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      );
    }
  }

  @override
  void dispose() {
    if (_typewriterTimer.isActive) _typewriterTimer.cancel();
    if (_cursorTimer.isActive) _cursorTimer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, 
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 🚕 LAYER 1: The Cinematic Moving Bokeh (Pure Code!)
          const CinematicBokehBackground(),

          // 🔮 LAYER 2: The Foggy Window Glass
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 4.0, sigmaY: 4.0), // Dropped to 4 for much clearer glass
            child: Container(
              color: Colors.black.withOpacity(0.20), // Dropped to 20% so it's less dark
            ),
          ),

          // 📝 LAYER 3: The Animation Engine
          Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 1000),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              child: _showLogo 
                  ? _buildLogoPhase() 
                  : _buildTypingPhase(),
            ),
          ),
        ],
      ),
    );
  }

  // ----------------------------------------------------------------
  // ⌨️ PHASE 1: THE OVERLAY TYPING ANIMATION (APPLE GARAMOND)
  // ----------------------------------------------------------------
  Widget _buildTypingPhase() {
    String typedText = _selectedPhrase.substring(0, _typewriterIndex);
    String untypedText = _selectedPhrase.substring(_typewriterIndex);

    // We hide the cursor after the logo fade triggers so it doesn't look messy
    bool renderCursor = _showCursor && !_showLogo; 

    return Column(
      mainAxisSize: MainAxisSize.min,
      key: const ValueKey("TypingPhase"), 
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            // 🌚 BOTTOM LAYER: The Dark Gray base text + an invisible cursor
            RichText(
              text: TextSpan(
                // 👇 Changed to AppleGaramond and bumped size to 42 for legibility
                style: const TextStyle(fontFamily: 'AppleGaramond', fontSize: 42, color: Colors.white24, letterSpacing: 1.2),
                children: [
                  TextSpan(text: _selectedPhrase),
                  const TextSpan(text: '|', style: TextStyle(color: Colors.transparent)), 
                ],
              ),
            ),
            
            // 💡 TOP LAYER: The bright white typing text overlay
            RichText(
              text: TextSpan(
                // 👇 Changed to AppleGaramond
                style: const TextStyle(fontFamily: 'AppleGaramond', fontSize: 42, letterSpacing: 1.2),
                children: [
                  TextSpan(text: typedText, style: const TextStyle(color: Colors.white)),
                  // The Blinking Cursor
                  TextSpan(
                    text: '|', 
                    style: TextStyle(color: renderCursor ? Colors.white : Colors.transparent, fontWeight: FontWeight.w300)
                  ),
                  // The untyped text (Invisible, but holds the layout perfectly still!)
                  TextSpan(text: untypedText, style: const TextStyle(color: Colors.transparent)),
                ],
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 16),
        
        // 🇺🇳 THE TRANSLATION FADE-IN
        AnimatedOpacity(
          opacity: _typingComplete ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 800),
          child: Text(
            _selectedTranslation.toUpperCase(),
            style: const TextStyle(
              fontFamily: 'Courier', // Keeping the translation in Courier to tie into your logo!
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 4.0,
              color: Colors.white54,
            ),
          ),
        ),
      ],
    );
  }

  // ----------------------------------------------------------------
  // 🛡️ PHASE 2: THE BRANDING REVEAL
  // ----------------------------------------------------------------
  Widget _buildLogoPhase() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      key: const ValueKey("LogoPhase"), 
      children: [
        // 👇 Changed to AppleGaramond!
        const Text(
          "NYC EATS",
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'AppleGaramond', // 👈 THE FIX
            fontSize: 48,
            fontWeight: FontWeight.w900,
            letterSpacing: 6.0,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          "GOURMET PASSPORTS",
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Courier', // Keeps the official stamp aesthetic
            fontSize: 14,
            fontWeight: FontWeight.bold,
            letterSpacing: 8.0,
            color: Colors.white.withOpacity(0.6),
          ),
        ),
      ],
    );
  }
}

// ----------------------------------------------------------------
// 🚕 THE RAINY CAB RIDE (PURE CODE BOKEH ANIMATION)
// ----------------------------------------------------------------
class CinematicBokehBackground extends StatefulWidget {
  const CinematicBokehBackground({super.key});

  @override
  State<CinematicBokehBackground> createState() => _CinematicBokehBackgroundState();
}

class _CinematicBokehBackgroundState extends State<CinematicBokehBackground> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<BokehLight> _lights = [];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 15))..repeat();

    // Generate 25 random city lights (Red taillights, Amber streetlights, White headlights)
    final random = Random();
    final colors = [
      const Color(0x88FF3B30), // Apple Red
      const Color(0x66FFCC00), // Warm Amber
      const Color(0x33FFFFFF), // Headlight White
      const Color(0x44007AFF), // Distant Neon Blue
    ];

    for (int i = 0; i < 25; i++) {
      _lights.add(BokehLight(
        xOffset: random.nextDouble(),
        yOffset: random.nextDouble(),
        radius: random.nextDouble() * 60 + 20, // Random sizes between 20 and 80
        speed: random.nextDouble() * 0.5 + 0.1, // Drift speed
        color: colors[random.nextInt(colors.length)],
      ));
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          painter: BokehPainter(_lights, _controller.value),
          size: Size.infinite,
        );
      },
    );
  }
}

class BokehLight {
  final double xOffset;
  final double yOffset;
  final double radius;
  final double speed;
  final Color color;
  BokehLight({required this.xOffset, required this.yOffset, required this.radius, required this.speed, required this.color});
}

class BokehPainter extends CustomPainter {
  final List<BokehLight> lights;
  final double progress;
  BokehPainter(this.lights, this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    // Fill the background with pitch black first
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), Paint()..color = const Color(0xFF050505));

    for (var light in lights) {
      // Calculate drifting movement
      double x = (light.xOffset * size.width) - (progress * size.width * light.speed);
      double y = (light.yOffset * size.height) + (sin(progress * pi * 2 + light.speed) * 30); // Slight vertical bobbing

      // Wrap around the screen to loop infinitely
      x = x % size.width;
      if (x < 0) x += size.width;

      final paint = Paint()
        ..color = light.color
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 15.0); // Sharper, distinct light orbs

      canvas.drawCircle(Offset(x, y), light.radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true; // Constantly updates the animation
}