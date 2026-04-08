import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:flutter/foundation.dart';
import 'passport_service.dart';

class RevenueCatService {
  // 🛑 THE BOUNCER: Prevents the function from running twice at the exact same time
  static bool _isCatchingZombies = false;

  static Future<void> catchZombiePurchases(String userId) async {
    // If it's already running from another file, block this duplicate attempt!
    if (_isCatchingZombies) {
      debugPrint(
        "🛡️ Zombie Catcher already running. Blocking duplicate call.",
      );
      return;
    }

    _isCatchingZombies = true; // Lock the door

    try {
      // 1. We still log in to RevenueCat to ensure the device is synced with Apple
      await Purchases.logIn(userId);

      // 2. We no longer manually compare transaction IDs or insert data!
      // The Supabase Edge Function handles all database insertions now.

      debugPrint(
        "📡 Syncing with server... Webhook should have handled purchases.",
      );

      // 3. Just force a refresh of the user's library from Supabase
      // so the UI instantly shows the new book the server just created.
      await PassportService.fetchUserLibrary(forceRefresh: true);
      await PassportService.prewarmCache();
    } catch (e) {
      debugPrint("Error syncing purchases: $e");
    } finally {
      // 🟢 ALWAYS UNLOCK THE DOOR WHEN FINISHED
      _isCatchingZombies = false;
    }
  }
}
