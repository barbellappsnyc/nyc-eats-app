import 'package:flutter/material.dart';
import 'package:nyc_eats/splash/splash_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:purchases_flutter/purchases_flutter.dart'; 
import 'services/purchase_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/revenuecat_service.dart'; 
import 'package:flutter/services.dart'; 
import 'package:flutter_dotenv/flutter_dotenv.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Load the secrets
  await dotenv.load(fileName: ".env");
  
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );
  
  final prefs = await SharedPreferences.getInstance();
  final bool hasPassedPaywall = prefs.getBool('has_passed_paywall') ?? false;

  await PurchaseService().init();

  Purchases.addCustomerInfoUpdateListener((customerInfo) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      await RevenueCatService.catchZombiePurchases(user.id);
    }
  });

  runApp(const NycEatsApp());
}

class NycEatsApp extends StatelessWidget {
  const NycEatsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NYC Eats',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.light, 
        scaffoldBackgroundColor: Colors.black,
        useMaterial3: true,
        // 👇 Set the default fallback font for the entire app
        fontFamily: 'SFPro', // (Or omit if you want the native iOS system font)
      ),
      // 👇 2. SET THE HOME SCREEN TO YOUR NEW SPLASH SCREEN
      home: const SplashScreen(), 
    );
  }
}