import 'package:flutter/material.dart';
import 'dart:math' as math;

class AnimatedBackground extends StatefulWidget {
  final String sku; // 'free_tier', 'diplomat_book', 'standard_book', 'store'
  final Widget? child;

  const AnimatedBackground({
    super.key,
    required this.sku,
    this.child,
  });

  @override
  State<AnimatedBackground> createState() => _AnimatedBackgroundState();
}

class _AnimatedBackgroundState extends State<AnimatedBackground> with TickerProviderStateMixin {
  late AnimationController _motionController;
  late AnimationController _transitionController;
  
  // COLOR STATE
  late List<Color> _targetColors;
  late List<Color> _previousColors;

  @override
  void initState() {
    super.initState();

    // 1. MOTION ENGINE (Continuous Liquid Flow)
    // We use a shorter duration so you can actually SEE it moving
    _motionController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 7), 
    )..repeat(reverse: true); 

    // 2. SETUP COLORS
    _targetColors = _getThemeColors(widget.sku);
    _previousColors = _targetColors;

    // 3. TRANSITION ENGINE
    _transitionController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
  }

  @override
  void didUpdateWidget(covariant AnimatedBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sku != widget.sku) {
      _previousColors = _targetColors;
      _targetColors = _getThemeColors(widget.sku);
      _transitionController.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _motionController.dispose();
    _transitionController.dispose();
    super.dispose();
  }

  // 🎨 RICH PALETTES (4 Colors for complexity)
  List<Color> _getThemeColors(String sku) {
    switch (sku) {
      case 'profile': 
        // 👤 PROFILE: Deep Space (Midnight, Dark Purple, Obsidian)
        // This provides high contrast for the white Official Data card.
        return [
          const Color(0xFF0F2027), 
          const Color(0xFF203A43), 
          const Color(0xFF2C5364), 
          const Color(0xFF0F2027),
        ];
      case 'diplomat_book':
        // ✅ FIX: Platinum Navy (Deep Blue + Silver Light). No more creeping black shadow.
        return [
          const Color(0xFF141E30), // Midnight Blue (Anchor)
          const Color(0xFF243B55), // Royal Navy
          const Color(0xFF4C669F), // Lighter Blue
          const Color(0xFFBDC3C7), // Platinum/Silver (The "Shine")
        ]; 
      case 'standard_book':
        // STANDARD: Navy, Teal, Deep Blue, Cyan
        return [
          const Color(0xFF000046),
          const Color(0xFF1CB5E0),
          const Color(0xFF000046),
          const Color(0xFF1A2980),
        ];
      case 'store':
      case 'shop':
        // STORE: Violet, Orange, Magenta, Deep Purple
        return [
          const Color(0xFF2E3192),
          const Color(0xFF1BFFFF),
          const Color(0xFFD4145A),
          const Color(0xFF662D8C),
        ];
      case 'free_tier':
      default:
        // WILDCARD: White, Sky Blue, Pale Pink, Cyan
        return [
          const Color(0xFFE0EAFC),
          const Color(0xFFCFDEF3),
          const Color(0xFFE2EBF5), // Very light hint
          const Color(0xFFB2EBF2),
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_motionController, _transitionController]),
      builder: (context, child) {
        
        // 🌊 LIQUID MOTION LOGIC
        // Instead of rotating, we move the start/end points in independent sine waves.
        // This causes the gradient to "stretch" and "compress" like liquid.
        final double t = _motionController.value;
        
        // Point A wanders top-left to top-center
        final Alignment beginAlign = Alignment(
          -1.0 + (0.5 * math.sin(t * math.pi)), // X: -1 to -0.5
          -1.0 + (0.3 * math.cos(t * math.pi)), // Y: -1 to -0.7
        );

        // Point B wanders bottom-right to bottom-center
        final Alignment endAlign = Alignment(
          1.0 - (0.5 * math.cos(t * math.pi)), // X: 1 to 0.5
          1.0 - (0.3 * math.sin(t * math.pi)), // Y: 1 to 0.7
        );

        // 🎨 COLOR BLENDING
        List<Color> gradientColors = [];
        for (int i = 0; i < 4; i++) {
          Color start = _previousColors.length > i ? _previousColors[i] : Colors.black;
          Color end = _targetColors.length > i ? _targetColors[i] : Colors.black;
          gradientColors.add(Color.lerp(start, end, _transitionController.value) ?? end);
        }

        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: gradientColors,
              begin: beginAlign,
              end: endAlign,
              // Stops create "harder" edges that make movement more visible
              stops: const [0.0, 0.3, 0.7, 1.0], 
            ),
          ),
          child: widget.child,
        );
      },
    );
  }
}