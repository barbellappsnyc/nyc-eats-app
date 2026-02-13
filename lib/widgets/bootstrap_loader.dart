import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart'; // 👈 NEW IMPORT
import '../services/tile_provider.dart'; // Ensure this matches your file structure
import '../screens/map_screen.dart';     // Ensure this matches your file structure

class BootstrapLoader extends StatefulWidget {
  const BootstrapLoader({super.key});

  @override
  State<BootstrapLoader> createState() => _BootstrapLoaderState();
}

class _BootstrapLoaderState extends State<BootstrapLoader> with TickerProviderStateMixin {
  double _progress = 0.0;
  String _loadingText = "Firing up the oven..."; // 🍕 Themed Text

  @override
  void initState() {
    super.initState();
    _startFakeLoading();
    _startRealPreCaching();
  }

  void _startFakeLoading() async {
    // 0% -> 60% (Fast)
    for (int i = 0; i <= 60; i += 5) {
      if (!mounted) return;
      setState(() => _progress = i / 100);
      await Future.delayed(const Duration(milliseconds: 20)); 
    }
    setState(() => _loadingText = "Melting cheese...");

    // 60% -> 90% (Slower)
    for (int i = 60; i <= 90; i += 2) {
      if (!mounted) return;
      setState(() => _progress = i / 100);
      await Future.delayed(const Duration(milliseconds: 50));
    }
    
    // Stall
    setState(() => _progress = 0.95);
  }

  void _startRealPreCaching() async {
    // 1. Pre-warm the LIGHT MAP (NYC Coordinates)
    // using the consolidated MapHeater from tile_provider.dart
    await MapHeater.preCacheTiles(40.735, -73.99, false); 
    
    await Future.delayed(const Duration(milliseconds: 500));

    if (mounted) {
      setState(() {
        _progress = 1.0;
        _loadingText = "Order Up!";
      });
      
      await Future.delayed(const Duration(milliseconds: 500)); // Let them see the 100%
      
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MapScreen()), 
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8E1), // 🎨 Warm "Dough" White Background
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 🍕 THE ANIMATED PIZZA
            // Lottie handles the "Floating" and "Dripping" automatically from the file
            SizedBox(
              height: 250, 
              child: Lottie.asset(
                'assets/animations/pizza_loader.json',
                fit: BoxFit.contain,
              ),
            ),
            
            const SizedBox(height: 40),
            
            // PROGRESS BAR
            SizedBox(
              width: 200,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: _progress,
                  backgroundColor: Colors.orange.withOpacity(0.2),
                  color: Colors.deepOrange, // 🎨 Tomato Sauce Red
                  minHeight: 6,
                ),
              ),
            ),
            const SizedBox(height: 20),
            
            // TEXT
            Text(
              "$_loadingText ${( _progress * 100).toInt()}%",
              style: const TextStyle(
                fontFamily: 'Courier', 
                fontWeight: FontWeight.bold,
                color: Colors.brown,
                letterSpacing: 1.2
              ),
            )
          ],
        ),
      ),
    );
  }
}