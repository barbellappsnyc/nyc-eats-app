import 'package:flutter/material.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../services/purchase_service.dart';
import 'auth_screen.dart'; 
import '../screens/map_screen.dart';
import 'package:shared_preferences/shared_preferences.dart'; 
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/passport_service.dart';
import 'passport_collection_screen.dart';
import '../models/restaurant.dart'; // 👈 NEW IMPORT


class PaywallScreen extends StatefulWidget {

  final Restaurant? incomingRestaurant; // 👈 NEW: Catching the baton
  
  const PaywallScreen({super.key, this.incomingRestaurant});

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  List<Package> _packages = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadOfferings();
  }

  Future<void> _loadOfferings() async {
    try {
      // 1. Fetch the "Menu" (Offerings)
      final packages = await PurchaseService().fetchOffers();
      
      if (mounted) {
        setState(() {
          _packages = packages;
          _isLoading = false; // 🛑 Stop the spinner!
        });
      }
    } catch (e) {
      print("Error loading offers: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }
  
  Future<void> _buy(Package package) async {
    setState(() => _isLoading = true);

    // 1. Attempt purchase (Talks to Apple/Google)
    bool success = await PurchaseService().purchasePackage(package);

    if (mounted) setState(() => _isLoading = false);

    if (success) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Purchase Successful!')),
        );
        
        // 2. CHECK: Are we already logged in?
        final user = Supabase.instance.client.auth.currentUser;
        final String sku = package.storeProduct.identifier;

        if (user != null) {
          // 🟢 LOGGED IN: Create the book immediately
          await PassportService.createBook(userId: user.id, sku: sku);
          await PassportService.prewarmCache(); // Refresh data

          if (mounted) {
            // Go to Collection to see the new book AND pass the baton!
            Navigator.of(context).pushReplacement(
               MaterialPageRoute(
                 builder: (_) => PassportCollectionScreen(
                   initialBookId: 'newly_created_book',
                   incomingRestaurant: widget.incomingRestaurant, // 👈 PASS THE BATON!
                 ),
               ),
            );
          }
        } else {
          // 🔴 GUEST: Go to Auth to "Claim" the purchase AND pass the baton!
          Navigator.of(context).push(
             MaterialPageRoute(
               builder: (_) => AuthScreen(
                 purchasedSku: sku,
                 incomingRestaurant: widget.incomingRestaurant, // 👈 PASS THE BATON!
               ),
             ),
          );
        }
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // Dark/Premium feel
      appBar: AppBar(
        title: const Text("Get Your Passport", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
        ? const Center(child: CircularProgressIndicator(color: Colors.amber))
        : Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                const Text(
                  "Choose your access level to sync across devices.",
                  style: TextStyle(color: Colors.white70, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                
                // --- PRODUCT LIST ---
                Expanded(
                  child: ListView.separated(
                    itemCount: _packages.length,
                    separatorBuilder: (ctx, i) => const SizedBox(height: 16),
                    itemBuilder: (ctx, index) {
                      final pkg = _packages[index];
                      final product = pkg.storeProduct;
                      
                      // 🎨 STYLING LOGIC
                      // Checks if ID contains 'diplomat' (e.g. 'nyceats_diplomat')
                      Color cardColor = Colors.grey[900]!;
                      Color textColor = Colors.white;
                      
                      if (product.identifier.contains('diplomat')) {
                        cardColor = const Color(0xFF1E3A8A); // Deep Blue
                        textColor = const Color(0xFFFFD700); // Gold
                      } else if (product.identifier.contains('standard')) {
                        cardColor = Colors.grey[800]!;
                      } else if (product.identifier.contains('single')) {
                        cardColor = Colors.grey[850]!;
                      }

                      return Card(
                        color: cardColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: textColor.withOpacity(0.3)),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(16),
                          title: Text(
                            product.title, 
                            style: TextStyle(
                              color: textColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                          subtitle: Text(
                            product.description,
                            style: TextStyle(color: textColor.withOpacity(0.7)),
                          ),
                          trailing: Text(
                            product.priceString, 
                            style: TextStyle(
                              color: textColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          onTap: () => _buy(pkg),
                        ),
                      );
                    },
                  ),
                ),

                // --- GUEST BUTTON ---
                TextButton(
                  onPressed: () async {
                    // 1. SAVE THE FLAG
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setBool('has_passed_paywall', true);

                    // 2. Navigate to Map
                    if (context.mounted) {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(builder: (_) => const MapScreen()), 
                      );
                    }
                  },
                  child: const Text("Continue as Guest", style: TextStyle(color: Colors.white54)),
                ),
                const SizedBox(height: 32), 
              ],
            ),
          ),
    );
  }
}