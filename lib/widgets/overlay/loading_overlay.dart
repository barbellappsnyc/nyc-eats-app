import 'package:flutter/material.dart';
import 'dart:ui';

class LoadingOverlay extends StatelessWidget {
  final bool isLoading;
  final Widget child;
  final String? message;

  const LoadingOverlay({
    super.key,
    required this.isLoading,
    required this.child,
    this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 1. The Actual Screen
        child,

        // 2. The Blocker
        if (isLoading)
          Positioned.fill(
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 200),
              builder: (context, value, _) {
                return Opacity(
                  opacity: value,
                  child: Stack(
                    children: [
                      // Blur Effect (The Ghostbuster Shield)
                      BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 5 * value, sigmaY: 5 * value),
                        child: Container(
                          color: Colors.black.withOpacity(0.3 * value),
                        ),
                      ),
                      
                      // The Spinner & Message
                      Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 3,
                            ),
                            if (message != null) ...[
                              const SizedBox(height: 20),
                              Text(
                                message!,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  letterSpacing: 1.2,
                                  fontFamily: 'Courier', 
                                  decoration: TextDecoration.none, // Fixes yellow underline
                                ),
                              ),
                            ]
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}