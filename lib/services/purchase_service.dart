import 'dart:io';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart'; // 🌟 ADDED DOTENV

class PurchaseService {
  // Singleton pattern
  static final PurchaseService _instance = PurchaseService._internal();
  factory PurchaseService() => _instance;
  PurchaseService._internal();

  bool _isInitialized = false;

  /// 1. Initialize (Real RevenueCat)
  Future<void> init() async {
    if (_isInitialized) return;

    if (kDebugMode) {
      await Purchases.setLogLevel(LogLevel.debug);
    }

    PurchasesConfiguration? configuration;

    // 🌟 THE FIX: Pulling your keys securely from the .env file
    if (Platform.isAndroid) {
      configuration = PurchasesConfiguration(
        dotenv.env['RC_ANDROID_KEY'] ?? '',
      );
    } else if (Platform.isIOS) {
      configuration = PurchasesConfiguration(dotenv.env['RC_IOS_KEY'] ?? '');
    }

    if (configuration != null) {
      await Purchases.configure(configuration);
      _isInitialized = true;
      if (kDebugMode) debugPrint("✅ REAL PURCHASE SERVICE: Initialized");
    }
  }

  /// 2. Fetch "Menu" (Real Offerings from Cloud)
  Future<List<Package>> fetchOffers() async {
    try {
      final offerings = await Purchases.getOfferings();
      if (offerings.current != null &&
          offerings.current!.availablePackages.isNotEmpty) {
        return offerings.current!.availablePackages;
      } else {
        if (kDebugMode)
          debugPrint(
            "⚠️ No offerings found. Check RevenueCat Dashboard setup.",
          );
        return [];
      }
    } on PlatformException catch (e) {
      if (kDebugMode) debugPrint("❌ Error fetching offers: $e");
      return [];
    }
  }

  /// 3. Buy an Item (Real Transaction)
  Future<bool> purchasePackage(Package package) async {
    try {
      await Purchases.purchasePackage(package);
      if (kDebugMode)
        debugPrint("✅ PURCHASE SUCCESS: ${package.storeProduct.identifier}");
      return true;
    } on PlatformException catch (e) {
      final errorCode = PurchasesErrorHelper.getErrorCode(e);
      if (errorCode == PurchasesErrorCode.purchaseCancelledError) {
        if (kDebugMode) debugPrint("User cancelled purchase");
      } else {
        if (kDebugMode) debugPrint("❌ Purchase Error: $e");
      }
      return false;
    }
  }

  /// 🌟 4. THE APPLE REQUIREMENT: Restore Purchases
  Future<bool> restorePurchases() async {
    try {
      await Purchases.restorePurchases();
      if (kDebugMode) debugPrint("✅ RESTORE SUCCESS");
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint("❌ Restore Error: $e");
      return false;
    }
  }
}
