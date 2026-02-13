import 'dart:io';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

class PurchaseService {
  // Singleton pattern
  static final PurchaseService _instance = PurchaseService._internal();
  factory PurchaseService() => _instance;
  PurchaseService._internal();

  bool _isInitialized = false;

  // 🔑 YOUR KEYS GO HERE
  final String _iosApiKey = 'appl_qbylCvYsyXEXBKFceOKcbGyAnVD'; 
  final String _androidApiKey = 'goog_YOUR_ANDROID_KEY_HERE';

  /// 1. Initialize (Real RevenueCat)
  Future<void> init() async {
    // Prevent double initialization
    if (_isInitialized) return;

    // Enable debug logs (Great for seeing why a purchase failed in the console)
    await Purchases.setLogLevel(LogLevel.debug);

    PurchasesConfiguration? configuration;

    if (Platform.isAndroid) {
      configuration = PurchasesConfiguration(_androidApiKey);
    } else if (Platform.isIOS) {
      configuration = PurchasesConfiguration(_iosApiKey);
      // Note: On Simulator, this will only work if you have a .storekit file loaded in Xcode scheme
    }

    if (configuration != null) {
      await Purchases.configure(configuration);
      _isInitialized = true;
      print("✅ REAL PURCHASE SERVICE: Initialized");
    }
  }

  /// 2. Fetch "Menu" (Real Offerings from Cloud)
  Future<List<Package>> fetchOffers() async {
    try {
      final offerings = await Purchases.getOfferings();
      
      // We look for the 'current' offering you configured in the RevenueCat dashboard.
      if (offerings.current != null && offerings.current!.availablePackages.isNotEmpty) {
        return offerings.current!.availablePackages;
      } else {
        print("⚠️ No offerings found. Check RevenueCat Dashboard setup.");
        return [];
      }
    } on PlatformException catch (e) {
      print("❌ Error fetching offers: $e");
      return [];
    }
  }

  /// 3. Buy an Item (Real Transaction)
  Future<bool> purchasePackage(Package package) async {
    try {
      final CustomerInfo customerInfo = await Purchases.purchasePackage(package);
      
      // If code reaches here, the transaction was successful!
      print("✅ PURCHASE SUCCESS: ${package.storeProduct.identifier}");
      return true;
      
    } on PlatformException catch (e) {
      final errorCode = PurchasesErrorHelper.getErrorCode(e);
      if (errorCode == PurchasesErrorCode.purchaseCancelledError) {
        print("User cancelled purchase");
      } else {
        print("❌ Purchase Error: $e");
      }
      return false;
    }
  }
}