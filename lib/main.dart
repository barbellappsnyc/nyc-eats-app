import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:purchases_flutter/purchases_flutter.dart'; // 👈 NEW: RevenueCat import
import 'services/purchase_service.dart';
import 'screens/map_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/revenuecat_service.dart'; // 👈 NEW: Import your new Zombie Catcher
import 'package:flutter/services.dart'; // 👈 1. Import services

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Supabase.initialize(
    url: 'https://frihlhztdsxieoszfyuh.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZyaWhsaHp0ZHN4aWVvc3pmeXVoIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjgyNDAwNjksImV4cCI6MjA4MzgxNjA2OX0.kQBxoROE934PHvwxwz02iHRjZerl9A1CGcy86CrJBEk',
  );
  
  // We can leave this here or remove it, it doesn't matter anymore
  final prefs = await SharedPreferences.getInstance();
  final bool hasPassedPaywall = prefs.getBool('has_passed_paywall') ?? false;

  await PurchaseService().init();

  // 👇 NEW: THE GLOBAL ZOMBIE WATCHDOG (Strike 3)
  Purchases.addCustomerInfoUpdateListener((customerInfo) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      // If RevenueCat detects a crashed or delayed receipt in the background, run the catcher!
      await RevenueCatService.catchZombiePurchases(user.id);
    }
  });

  runApp(const NycEatsApp());
}

class NycEatsApp extends StatelessWidget {
  const NycEatsApp({super.key});

  @override
  Widget build(BuildContext context) {
    // ✂️ LOGIC REMOVED: No more checking session or paywall variables.

    return MaterialApp(
      title: 'NYC Eats',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.light, 
        scaffoldBackgroundColor: Colors.black,
        useMaterial3: true,
      ),
      home: const MapScreen(), // 👈 ALWAYS GO HERE
    );
  }
}