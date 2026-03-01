import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:flutter/foundation.dart';
import 'passport_service.dart';

class RevenueCatService {
  // 🛑 THE BOUNCER: Prevents the function from running twice at the exact same time
  static bool _isCatchingZombies = false;

  static Future<void> catchZombiePurchases(String userId) async {
    // If it's already running from another file, block this duplicate attempt!
    if (_isCatchingZombies) {
      debugPrint("🛡️ Zombie Catcher already running. Blocking duplicate call.");
      return;
    }

    _isCatchingZombies = true; // Lock the door

    try {
      await Purchases.logIn(userId);
      final customerInfo = await Purchases.getCustomerInfo();
      final allTransactions = customerInfo.nonSubscriptionTransactions;

      if (allTransactions.isEmpty) return;

      // 1. Fetch what Supabase currently knows about
      final library = await PassportService.fetchUserLibrary(forceRefresh: true);
      
      // 2. Extract a list of all receipt numbers Supabase already saved
      final existingTransactionIds = library
          .map((book) => book['rc_transaction_id'] as String?)
          .where((id) => id != null)
          .toSet();

      bool zombiesFound = false;

      // 3. Loop through every receipt Apple/Google has EVER given this phone
      for (var transaction in allTransactions) {
        final txId = transaction.transactionIdentifier;
        final productId = transaction.productIdentifier; // e.g., 'nyceats_diplomat'

        // 4. If Supabase doesn't have this EXACT receipt saved... ZOMBIE!
        if (!existingTransactionIds.contains(txId)) {
          debugPrint("🧟‍♂️ ZOMBIE FOUND! Restoring missing purchase: $productId");

          await PassportService.createBook(
            userId: userId, 
            sku: productId,
            transactionId: txId, // 👈 Save the receipt number so we never duplicate it!
          );
          
          // Instantly add it to our local list so if the loop continues, we don't duplicate it!
          existingTransactionIds.add(txId); 
          zombiesFound = true;
        }
      }

      if (zombiesFound) {
        await PassportService.prewarmCache();
      }

    } catch (e) {
      debugPrint("Error catching zombie purchases: $e");
    } finally {
      // 🟢 ALWAYS UNLOCK THE DOOR WHEN FINISHED (Even if it crashes)
      _isCatchingZombies = false;
    }
  }
}