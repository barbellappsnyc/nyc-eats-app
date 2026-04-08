import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nyc_eats/screens/map_screen.dart';
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
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  // 👇 ADD THESE TWO KEYS
  final GlobalKey _booksKey = GlobalKey();
  final GlobalKey _controlsKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _loadOfferings();

    _tosRecognizer = TapGestureRecognizer()..onTap = _launchToS;
    _privacyRecognizer = TapGestureRecognizer()..onTap = _launchPrivacy;

    // 👇 ADD THIS POST-FRAME CALLBACK
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndShowTutorial();
    });
  }

  // 👇 ADD THESE TWO METHODS ANYWHERE IN THE STATE CLASS
  Future<void> _checkAndShowTutorial() async {
    final prefs = await SharedPreferences.getInstance();
    final String? stage = prefs.getString('tutorial_stage');

    if (stage == 'shop_screen') {
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted) _showShopTutorial();
      });
    }
  }

  void _showShopTutorial() {
    final size = MediaQuery.of(context).size; // 👈 Get screen dimensions

    TutorialCoachMark(
      targets: [
        // 🎯 TARGET 1: THE BOOKS
        TargetFocus(
          identify: "books_target",
          keyTarget: _booksKey,
          shape: ShapeLightFocus.RRect,
          radius: 20,
          contents: [
            TargetContent(
              align: ContentAlign.custom, // 👈 Bypass default alignment
              customPosition: CustomTargetContentPosition(
                top: size.height * 0.15, // Lock it 15% down from the top
              ),
              builder: (context, controller) => Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.85),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white24, width: 1),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "THE CONSUMABLES",
                      style: TextStyle(
                        fontFamily: 'AppleGaramond',
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontSize: 26,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      "Passports are physical, one-time consumables. Swipe up and down to 'feel' the different tiers before you buy.",
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                        height: 1.4,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () => controller
                          .next(), // 👈 Safe to use next() here, there is another slide!
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      child: const Text(
                        "NEXT",
                        style: TextStyle(
                          fontFamily: 'Courier',
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),

        // 🎯 TARGET 2: THE BOTTOM CONTROLS (THE PACT)
        TargetFocus(
          identify: "controls_target",
          keyTarget: _controlsKey,
          shape: ShapeLightFocus.RRect,
          radius: 24,
          contents: [
            TargetContent(
              align:
                  ContentAlign.custom, // 👈 Bypass default alignment here too!
              customPosition: CustomTargetContentPosition(
                top:
                    size.height *
                    0.15, // Keeps text in the exact same spot for a seamless transition
              ),
              builder: (context, controller) => Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.85),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white24, width: 1),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "THE PACT",
                      style: TextStyle(
                        fontFamily: 'AppleGaramond',
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontSize: 26,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      "No subscriptions. No recurring fees. You pay once, and the passport is yours forever.\n\nWelcome to Gourmet Passports.",
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                        height: 1.4,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () {
                        // 1. Pass the baton back to the map screen
                        SharedPreferences.getInstance().then((prefs) {
                          prefs.setString('tutorial_stage', 'final_map_screen');
                        });

                        // 2. Force the tutorial to close
                        controller.skip();

                        // 3. Jump to MapScreen and clear everything else
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(builder: (_) => const MapScreen()),
                          (route) => false,
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      child: const Text(
                        "NEXT",
                        style: TextStyle(
                          fontFamily: 'Courier',
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
      colorShadow: Colors.black,
      paddingFocus: 10,
      opacityShadow: 0.9,
      hideSkip: true,
      onFinish: () {
        // 🏁 DESTROY THE BATON: The tour is completely finished!
        SharedPreferences.getInstance().then((prefs) {
          prefs.setBool('has_seen_tutorial', true);
          prefs.remove('tutorial_stage');
        });
      },
    ).show(context: context);
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
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 4,
              ),
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
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 11,
                ), // Scaled down
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

    // 1. Get the internal UI name (e.g., 'standard_book')
    final String activeSku = _shopTiers[_currentShopIndex]['sku']!;

    // 2. Translate it to the exact RevenueCat identifier
    String revenueCatIdentifier = '';
    if (activeSku == 'single_page') {
      revenueCatIdentifier = 'nyceats_single';
    } else if (activeSku == 'standard_book') {
      revenueCatIdentifier = 'nyceats_standard';
    } else if (activeSku == 'diplomat_book') {
      revenueCatIdentifier = 'nyceats_diplomat';
    }

    // 3. Find the matching package
    try {
      return _packages.firstWhere(
        (pkg) => pkg.storeProduct.identifier == revenueCatIdentifier,
      );
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
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                "You need to create an account or log in to purchase the passport and save your stamps.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white70,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 28),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.grey,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text(
                        "CANCEL",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
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
                              purchasedSku:
                                  _shopTiers[_currentShopIndex]['sku'],
                              incomingRestaurant: widget.incomingRestaurant,
                            ),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        "LOGIN",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
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
        buttonText =
            "ACQUIRE PASSPORT - ${activePackage.storeProduct.priceString}";
      } else {
        buttonText = "UNAVAILABLE";
      }
    }

    final bool isClickable =
        !_isLoading && (!isLoggedIn || activePackage != null);

    // 👇 CHANGED: Removed Positioned wrapper. Used SizedBox to force full width.
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: (isLoggedIn && isClickable)
              ? Colors.white
              : Colors.grey[850],
          foregroundColor: (isLoggedIn && isClickable)
              ? Colors.black
              : Colors.grey[400],
          padding: const EdgeInsets.symmetric(vertical: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: (isLoggedIn && isClickable) ? 10 : 0,
          side: isLoggedIn
              ? BorderSide.none
              : BorderSide(color: Colors.white.withOpacity(0.1)),
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
            text: ".\nPassports are one-time consumable purchases.",
          ),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }

  Future<void> _launchToS() async {
    // Replace with your actual Terms of Service URL later
    final Uri url = Uri.parse('https://gourmetpassports.com/terms.html');
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      debugPrint('Could not launch $url');
    }
  }

  Future<void> _launchPrivacy() async {
    // Replace with your actual Privacy Policy URL later
    final Uri url = Uri.parse('https://gourmetpassports.com/privacy.html');
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      debugPrint('Could not launch $url');
    }
  }

  void _showPurchaseInfo(String sku, String title) {
    String description = "";
    String capacity = "";
    Color accentColor = Colors.white;

    if (sku == 'single_page') {
      description =
          "A single-entry travel document. Once a cuisine is assigned, this page is locked to that specific country forever.";
      capacity = "1 Visa Page • 4 Stamps Max";
      accentColor = Colors.blueAccent;
    } else if (sku == 'standard_book') {
      description =
          "The classic traveler's companion. Bound in Imperial Burgundy, it allows for multiple cuisines and border crossings.";
      capacity = "5 Visa Pages • 20 Stamps Max";
      accentColor = const Color(0xFF5C1026); // Burgundy
    } else if (sku == 'diplomat_book') {
      description =
          "For the culinary elite. An expansive, heavyweight book featuring the exclusive Navy & Gold Foil cover.";
      capacity = "20 Visa Pages • 80 Stamps Max";
      accentColor = const Color(0xFFFFD700); // Gold
    }

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.style, size: 40, color: accentColor),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'AppleGaramond',
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: accentColor.withOpacity(0.3)),
                ),
                child: Text(
                  capacity,
                  style: TextStyle(
                    fontFamily: 'SFPro',
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: accentColor,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                description,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.white70,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text(
                    "CLOSE",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double cardWidth = (MediaQuery.of(context).size.width * 0.85).clamp(
      300.0,
      400.0,
    );
    final double cardHeight = cardWidth * (540 / 340);

    // 👇 Task 3: Forces black status bar icons (battery, wifi, time)
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        // 👈 Task 1: AppBar completely removed!
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

                return Align(
                  // ❌ REMOVED KEY FROM HERE
                  alignment: const Alignment(0, -0.3),
                  child: Transform.scale(
                    scale: 0.85,
                    child: Stack(
                      alignment: Alignment.center,
                      clipBehavior: Clip.none,
                      children: [
                        // 1. THE 3D BOOK
                        SizedBox(
                          key: index == _currentShopIndex ? _booksKey : null,
                          width: cardWidth,
                          height: cardHeight + 100,
                          child: PassportStackScreen(
                            key: ValueKey(
                              tier['sku'],
                            ), // 👈 ADD THIS: Forces a clean State instance for each unique SKU
                            isDemo: true,
                            skuType: tier['sku'],
                          ),
                        ),

                        // 2. THE FLOATING INFO LABEL
                        Positioned(
                          top: 0,
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () =>
                                _showPurchaseInfo(tier['sku']!, tier['title']!),
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 24.0),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    tier['title']!,
                                    style: const TextStyle(
                                      fontFamily: 'SFPro',
                                      fontWeight: FontWeight.w800,
                                      fontSize: 15,
                                      color: Colors.black,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  const Icon(
                                    Icons.info_outline,
                                    color: Colors.black,
                                    size: 18,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
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
                key: _controlsKey, // 👈 ATTACH KEY HERE
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: MediaQuery.of(context).size.width * 0.06,
                    vertical: MediaQuery.of(context).size.height * 0.02,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 👇 Task 4: Pushed text higher away from the button & made it dark
                      const Padding(
                        padding: EdgeInsets.only(bottom: 22.0),
                        child: Text(
                          "No subscriptions. Pay once, own it forever.",
                          style: TextStyle(
                            color: Colors.black87,
                            fontSize: 18,
                            fontStyle: FontStyle.italic,
                            fontFamily: 'AppleGaramond',
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      _buildBuyButton(),
                      SizedBox(
                        height: MediaQuery.of(context).size.height * 0.015,
                      ),
                      _buildLegalFooter(),
                    ],
                  ),
                ),
              ),
            ),

            // ❌ LAYER 6: FROSTED GLASS CLOSE BUTTON (Task 2)
            Positioned(
              top: MediaQuery.of(context).padding.top + 16, // Safe area aware
              left: 16,
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(
                          0.3,
                        ), // Apple frosted glass base
                        border: Border.all(
                          color: Colors.white.withOpacity(0.4),
                          width: 1,
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close,
                        color: Colors.black,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
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
                    // 👇 Task 3: Switched to solid black and dark grey
                    color: isActive ? Colors.black : Colors.black38,
                    fontSize: isActive ? 15 : 13,
                    fontWeight: isActive ? FontWeight.w900 : FontWeight.w600,
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
