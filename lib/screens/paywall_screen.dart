import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:nyc_eats/screens/passport_stack_screen.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../services/purchase_service.dart';
import 'auth_screen.dart'; 
import '../services/passport_service.dart';
import 'passport_collection_screen.dart';
import '../models/restaurant.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/animated_background.dart'; // Ensure this path matches your folder structure!
import 'dart:async'; // 👈 Don't forget to add this to the very top of your file!
import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart'; // 👈 For the tap recognizers
import 'package:url_launcher/url_launcher.dart'; // 👈 To open the browser

class PaywallScreen extends StatefulWidget {
  final Restaurant? incomingRestaurant;
  
  const PaywallScreen({super.key, this.incomingRestaurant});

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  List<Package> _packages = [];
  bool _isLoading = true;

  int _currentShopIndex = 0;
  final PageController _pageController = PageController();
  
  final List<Map<String, String>> _shopTiers = [
    {'sku': 'single_page', 'label': '1', 'title': 'SINGLE ENTRY'},
    {'sku': 'standard_book', 'label': 'S', 'title': 'STANDARD PASSPORT'},
    {'sku': 'diplomat_book', 'label': 'D', 'title': 'DIPLOMAT BOOK'},
  ];

  late TapGestureRecognizer _tosRecognizer;
  late TapGestureRecognizer _privacyRecognizer;

  @override
  void initState() {
    super.initState();
    _loadOfferings();
    
    // 👇 Initialize the tap listeners
    _tosRecognizer = TapGestureRecognizer()..onTap = _launchToS;
    _privacyRecognizer = TapGestureRecognizer()..onTap = _launchPrivacy;
  }

  @override
  void dispose() {
    _pageController.dispose();
    _tosRecognizer.dispose(); // 👈 Prevent memory leaks
    _privacyRecognizer.dispose(); // 👈 Prevent memory leaks
    super.dispose();
  }
  Future<void> _loadOfferings() async {
    try {
      final packages = await PurchaseService().fetchOffers();
      if (mounted) {
        setState(() {
          _packages = packages;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading offers: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }
  
  Future<void> _buy(Package package) async {
    setState(() => _isLoading = true);
    bool success = await PurchaseService().purchasePackage(package);

    if (success && mounted) {
      final user = Supabase.instance.client.auth.currentUser;
      final String sku = package.storeProduct.identifier;

      if (user != null) {
        // 🛑 NEW: Grab the receipt ID directly from RevenueCat immediately after purchase!
        String? transactionId;
        try {
          final customerInfo = await Purchases.getCustomerInfo();
          // Find all transactions for this specific SKU
          final txs = customerInfo.nonSubscriptionTransactions
              .where((t) => t.productIdentifier == sku)
              .toList();
              
          if (txs.isNotEmpty) {
             // Sort by newest first to grab the one that just happened
             txs.sort((a, b) => b.purchaseDate.compareTo(a.purchaseDate)); 
             transactionId = txs.first.transactionIdentifier;
          }
        } catch (e) {
          debugPrint("Could not fetch transaction ID: $e");
        }

        // 👈 Now we pass the transactionId, so the Zombie Catcher ignores it later!
        await PassportService.createBook(
          userId: user.id, 
          sku: sku,
          transactionId: transactionId, 
        );
        
        await PassportService.prewarmCache();
        if (mounted) {
          setState(() => _isLoading = false);
          Navigator.of(context).pushReplacement(
             MaterialPageRoute(
               builder: (_) => PassportCollectionScreen(
                 initialBookId: 'newly_created_book',
                 incomingRestaurant: widget.incomingRestaurant,
               ),
             ),
          );
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
        Navigator.of(context).push(
           MaterialPageRoute(
             builder: (_) => AuthScreen(
               purchasedSku: sku,
               incomingRestaurant: widget.incomingRestaurant,
             ),
           ),
        );
      }
    } else {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildPackageButton(Package pkg) {
    final product = pkg.storeProduct;
    final bool isDiplomat = product.identifier.contains('diplomat');

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Container(
            decoration: BoxDecoration(
              // 🌫️ Increased opacity for thicker frosted glass
              color: Colors.white.withOpacity(isDiplomat ? 0.25 : 0.15),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDiplomat 
                    ? const Color(0xFFFFD700).withOpacity(0.9) 
                    : Colors.white.withOpacity(0.45), 
                width: 1.5,
              ),
            ),
            child: ListTile(
              // 👇 Slashed vertical padding to make it much shorter
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              title: Text(
                product.title.toUpperCase(),
                style: TextStyle(
                  color: isDiplomat ? const Color(0xFFFFD700) : Colors.white,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'Courier',
                  letterSpacing: 1.2,
                  fontSize: 14, // Scaled down from 16
                ),
              ),
              subtitle: Text(
                product.description,
                style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 11), // Scaled down
              ),
              trailing: Text(
                product.priceString,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16, // Scaled down from 18
                  fontFamily: 'Courier',
                ),
              ),
              onTap: () => _buy(pkg),
            ),
          ),
        ),
      ),
    );
  }

  Package? _getActivePackage() {
    if (_packages.isEmpty) return null;
    final String activeSku = _shopTiers[_currentShopIndex]['sku']!;
    try {
      // Matches the dummy book SKU ('standard_book') to the RevenueCat identifier
      return _packages.firstWhere((pkg) => pkg.storeProduct.identifier.contains(activeSku));
    } catch (e) {
      return null;
    }
  }

  void _showAuthDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_outline, size: 48, color: Colors.white54),
              const SizedBox(height: 20),
              const Text(
                "AUTHENTICATION REQUIRED",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Courier', 
                  fontSize: 18, 
                  fontWeight: FontWeight.w900, 
                  color: Colors.white, 
                  letterSpacing: 1.0
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                "You need to create an account or log in to purchase the passport and save your stamps.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.white70, height: 1.5),
              ),
              const SizedBox(height: 28),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.grey, 
                        padding: const EdgeInsets.symmetric(vertical: 16)
                      ),
                      child: const Text("CANCEL", style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context); 
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => AuthScreen(
                              purchasedSku: _shopTiers[_currentShopIndex]['sku'],
                              incomingRestaurant: widget.incomingRestaurant,
                            ),
                          )
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text("LOGIN", style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBuyButton() {
    final Package? activePackage = _getActivePackage();
    final bool isLoggedIn = Supabase.instance.client.auth.currentUser != null;
    
    String buttonText = "LOADING...";
    if (!_isLoading) {
      if (!isLoggedIn) {
        buttonText = "LOGIN TO PURCHASE";
      } else if (activePackage != null) {
        buttonText = "ACQUIRE PASSPORT - ${activePackage.storeProduct.priceString}";
      } else {
        buttonText = "UNAVAILABLE"; 
      }
    }

    final bool isClickable = !_isLoading && (!isLoggedIn || activePackage != null);

    // 👇 CHANGED: Removed Positioned wrapper. Used SizedBox to force full width.
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: (isLoggedIn && isClickable) ? Colors.white : Colors.grey[850],
          foregroundColor: (isLoggedIn && isClickable) ? Colors.black : Colors.grey[400],
          padding: const EdgeInsets.symmetric(vertical: 20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: (isLoggedIn && isClickable) ? 10 : 0,
          side: isLoggedIn ? BorderSide.none : BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
        onPressed: isClickable
            ? () {
                if (!isLoggedIn) {
                  _showAuthDialog();
                } else if (activePackage != null) {
                  _buy(activePackage); 
                }
              }
            : null,
        child: _isLoading 
          ? const CupertinoActivityIndicator(color: Colors.white) 
          : Text(
              buttonText,
              style: const TextStyle(
                fontFamily: 'Courier',
                fontWeight: FontWeight.w900,
                fontSize: 15,
                letterSpacing: 1.2,
              ),
            ),
      ),
    );
  }
  
  Widget _buildLegalFooter() {
    return Text.rich(
      TextSpan(
        text: "By purchasing, you agree to our ",
        style: const TextStyle(color: Colors.black, fontSize: 11, height: 1.4),
        children: [
          TextSpan(
            text: "Terms of Service",
            style: const TextStyle(
              decoration: TextDecoration.underline, 
              color: Colors.black,
              fontWeight: FontWeight.bold,
            ),
            recognizer: _tosRecognizer, // 👈 ADDED THIS
          ),
          const TextSpan(text: " and "),
          TextSpan(
            text: "Privacy Policy",
            style: const TextStyle(
              decoration: TextDecoration.underline, 
              color: Colors.black,
              fontWeight: FontWeight.bold,
            ),
            recognizer: _privacyRecognizer, // 👈 ADDED THIS
          ),
          const TextSpan(
            text: ".\nPassports are one-time consumable purchases."
          ),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }

  Future<void> _launchToS() async {
    // Replace with your actual Terms of Service URL later
    final Uri url = Uri.parse('https://yourwebsite.com/terms'); 
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      debugPrint('Could not launch $url');
    }
  }

  Future<void> _launchPrivacy() async {
    // Replace with your actual Privacy Policy URL later
    final Uri url = Uri.parse('https://yourwebsite.com/privacy'); 
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      debugPrint('Could not launch $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    // 👇 Reverted to original layout math to preserve the perfect aspect ratio
    final double cardWidth = (MediaQuery.of(context).size.width * 0.85).clamp(300.0, 400.0);
    final double cardHeight = cardWidth * (540 / 340);

    return Scaffold(
      backgroundColor: Colors.transparent, 
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16.0),
          child: IconButton(
            icon: const Icon(Icons.close, color: Colors.white, size: 28),
            onPressed: () => Navigator.pop(context),
          ),
        ),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          const AnimatedBackground(sku: 'free_tier'),
          
          PageView.builder(
            controller: _pageController,
            scrollDirection: Axis.vertical,
            onPageChanged: (index) {
              setState(() => _currentShopIndex = index);
            },
            itemCount: _shopTiers.length,
            itemBuilder: (context, index) {
              final tier = _shopTiers[index];
              
              return Center(
                // 👇 NEW: Shrinks the entire widget uniformly without altering the layout math
                child: Transform.scale(
                  scale: 0.85, // Tweak this number (0.8, 0.9) to get the perfect size
                  child: SizedBox(
                    width: cardWidth,
                    height: cardHeight + 100, 
                    child: PassportStackScreen(
                      isDemo: true, 
                      skuType: tier['sku'],
                    ),
                  ),
                ),
              );
            },
          ),
          
          // 📍 LAYER 3: SIDE INDICATORS
          _buildSideIndicators(),

          // 💳 & ⚖️ LAYERS 4 & 5: DYNAMIC BOTTOM CONTROLS
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  // Dynamic padding based on percentage of screen size
                  horizontal: MediaQuery.of(context).size.width * 0.06, 
                  vertical: MediaQuery.of(context).size.height * 0.02,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min, // Hugs the elements tightly
                  children: [
                    _buildBuyButton(),
                    SizedBox(height: MediaQuery.of(context).size.height * 0.015), // Scalable gap
                    _buildLegalFooter(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSideIndicators() {
    const double itemHeight = 35.0; // Hitbox height per item
    const int itemCount = 3;
    const double totalHeight = itemHeight * itemCount;

    return Positioned(
      right: 12, // Snug against the right edge
      top: 0,
      bottom: 0,
      child: Center(
        child: GestureDetector(
          // 👇 The Scrubbing Mechanism
          onVerticalDragUpdate: (details) {
            double y = details.localPosition.dy;
            int index = (y / itemHeight).floor();
            index = index.clamp(0, itemCount - 1);
            
            if (_currentShopIndex != index) {
              _pageController.animateToPage(
                index,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
              );
            }
          },
          // Transparent container to catch the drag gestures
          child: Container(
            color: Colors.transparent, 
            height: totalHeight,
            width: 40,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: _shopTiers.asMap().entries.map((entry) {
                final index = entry.key;
                final label = entry.value['label']!;
                final isActive = index == _currentShopIndex;

                return Text(
                  label,
                  style: TextStyle(
                    color: isActive ? Colors.white : Colors.white38,
                    fontSize: isActive ? 15 : 13,
                    fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }

}