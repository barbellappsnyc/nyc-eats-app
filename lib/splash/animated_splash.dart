import 'package:flutter/material.dart';

class AnimatedSplash extends StatefulWidget {
  final Widget next;

  const AnimatedSplash({super.key, required this.next});

  @override
  State<AnimatedSplash> createState() => _AnimatedSplashState();
}

class _AnimatedSplashState extends State<AnimatedSplash>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  late final Animation<double> _spread;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _scale = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );

    _spread = Tween<double>(begin: 0, end: 20).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.4, 1.0, curve: Curves.easeOut),
      ),
    );

    _controller.forward();

    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => widget.next),
        );
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFFFAF7F2);

    return Scaffold(
      backgroundColor: bg,
      body: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (_, __) {
            return Stack(
              alignment: Alignment.center,
              children: [
                _dot(offset: Offset(-_spread.value, 0), scale: _scale.value),
                _dot(offset: Offset(_spread.value, 0), scale: _scale.value),
                _dot(offset: Offset(0, _spread.value), scale: _scale.value),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _dot({required Offset offset, required double scale}) {
    return Transform.translate(
      offset: offset,
      child: Transform.scale(
        scale: scale,
        child: Container(
          width: 10,
          height: 10,
          decoration: const BoxDecoration(
            color: Colors.black87,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}

// https://frihlhztdsxieoszfyuh.supabase.co
// eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZyaWhsaHp0ZHN4aWVvc3pmeXVoIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjgyNDAwNjksImV4cCI6MjA4MzgxNjA2OX0.kQBxoROE934PHvwxwz02iHRjZerl9A1CGcy86CrJBEk