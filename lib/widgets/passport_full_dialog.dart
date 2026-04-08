import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../screens/paywall_screen.dart';
import '../screens/auth_screen.dart';

class PassportFullDialog extends StatelessWidget {
  const PassportFullDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFFFFFDF7),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 🛑 Icon
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red[50],
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.block, size: 40, color: Colors.red[900]),
            ),
            const SizedBox(height: 20),

            // 📢 Title
            Text(
              "PASSPORT FULL",
              style: TextStyle(
                fontFamily: 'Courier',
                fontWeight: FontWeight.w900,
                fontSize: 22,
                letterSpacing: -0.5,
                color: Colors.red[900],
              ),
            ),
            const SizedBox(height: 12),

            // 📝 Body
            const Text(
              "Your Tourist Visa has run out of space.\n\nUpgrade to a Diplomat Passport to unlock unlimited pages and continue your journey.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                height: 1.5,
                color: Colors.black54,
              ),
            ),
            const SizedBox(height: 24),

            // 🚀 Upgrade Button (THE FIXED LOGIC)
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A237E), // Navy Blue
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                onPressed: () async {
                  // 1. Close the Dialog first
                  Navigator.pop(context);

                  final user = Supabase.instance.client.auth.currentUser;

                  if (user != null) {
                    // 🟢 ALREADY LOGGED IN? Go to Shop.
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const PaywallScreen()),
                    );
                  } else {
                    // 🔴 GUEST? Force Login First.
                    // We use 'isRedirectingBack: true' so AuthScreen pops itself after success
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            const AuthScreen(isRedirectingBack: true),
                      ),
                    );

                    // 3. CHECK RESULT
                    // If they successfully logged in, 'user' will now be valid.
                    final freshUser = Supabase.instance.client.auth.currentUser;
                    if (freshUser != null && context.mounted) {
                      // NOW send them to the shop
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const PaywallScreen(),
                        ),
                      );
                    }
                  }
                },
                child: const Text(
                  "VIEW UPGRADES",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // ❌ Cancel Button
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                "NOT NOW",
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
