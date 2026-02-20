import 'dart:ui';
import 'package:flutter/material.dart';
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

class PaywallScreen extends StatefulWidget {
  final Restaurant? incomingRestaurant;
  
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 🌌 Transparent so the AnimatedBackground handles the visuals
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
          // 🌊 LAYER 1: The Dark, High-Contrast Paywall Gradient
          const AnimatedBackground(sku: 'paywall'),
          
          // 🛒 LAYER 2: Package Selection Section
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // ✨ NEW: The Animated Fact Card
                  const _NycFactCard(),
                  
                  // 📦 Packages
                  _isLoading
                      ? const Center(child: CupertinoActivityIndicator(color: Colors.white, radius: 16))
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          children: _packages.map((pkg) => _buildPackageButton(pkg)).toList(),
                        ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NycFactCard extends StatefulWidget {
  const _NycFactCard();

  @override
  State<_NycFactCard> createState() => _NycFactCardState();
}

class _NycFactCardState extends State<_NycFactCard> {
  final List<String> _facts = [
    "NYC has over 25,000 restaurants. If you ate at a new one every day, it would take 68 years to visit them all!",
    "The first pizzeria in America, Lombardi's, opened in NYC in 1905.",
    "The cronut was invented in NYC by Dominique Ansel in 2013.",
    "Eggs Benedict was invented at the Waldorf Astoria in NYC in 1894 as a hangover cure.",
    "NYC is home to the world's most expensive burger, costing \$295 at Serendipity 3.",
    "The classic black-and-white cookie became an NYC staple at Glaser's Bake Shop in 1902.",
    "Katz’s Delicatessen sells over 15,000 pounds of pastrami every single week.",
    "The New York style hot dog was popularized by Charles Feltman at Coney Island in 1867.",
    "NYC consumes more coffee than any other US city—almost 7 times the national average!",
    "The first American restaurant to use tablecloths was Delmonico's in NYC.",
    "General Tso’s Chicken was perfected and popularized in NYC, not China.",
    "English muffins were invented in NYC by Samuel Bath Thomas in 1880.",
    "The Bloody Mary was allegedly invented at the King Cole Bar in NYC's St. Regis Hotel in 1934.",
    "There are more than 4,000 street food vendors operating in NYC today.",
    "The modern pasta primavera was invented at Le Cirque in NYC in the 1970s.",
    "Manhattan clam chowder uses a tomato base and was heavily influenced by Italian immigrants.",
    "A single NYC bagel is famously boiled before baking to give it that distinct chewy crust.",
    "NYC tap water is the secret ingredient to its legendary bagels and pizza dough due to its unique mineral profile.",
    "The concept of the 'brunch' was popularized in NYC in the late 19th century.",
    "The hot dog eating contest at Nathan's Famous on Coney Island has been held since 1916.",
    "Baked Alaska was created at Delmonico's in NYC in 1867 to celebrate the US purchase of Alaska.",
    "The first restaurant to offer a tasting menu in the US is widely considered to be an NYC establishment.",
    "Chicken and waffles gained nationwide fame during the Harlem Renaissance at Wells Supper Club in NYC.",
    "The Reuben sandwich was allegedly created at Reuben's Restaurant in NYC in 1914.",
    "NYC has the largest Chinatown in the Western Hemisphere, boasting over 300 restaurants.",
    "The famous 'rainbow bagel' was created at The Bagel Store in Brooklyn.",
    "NYC is currently home to over 70 Michelin-starred restaurants.",
    "The first automats (vending machine restaurants) in the US were popularized by Horn & Hardart in NYC.",
    "Pastrami was introduced to NYC by Romanian Jewish immigrants in the late 19th century.",
    "The Waldorf Salad was created in 1896 at the Waldorf-Astoria Hotel by the maitre d', Oscar Tschirky.",
    "Ray's Pizza has dozens of unrelated locations in NYC, sparking a long-running debate over the 'Original' Ray's.",
    "New York Cheesecake relies heavily on cream cheese rather than ricotta for its dense texture.",
    "The first iced tea was reportedly popularized in NYC before making its way to the St. Louis World's Fair.",
    "Spaghetti and meatballs is an Italian-American invention that originated in NYC's Little Italy.",
    "NYC is the birthplace of the Manhattan cocktail, created at the Manhattan Club in the 1870s.",
    "Shake Shack started as a humble hot dog cart in Madison Square Park in 2001."
  ];

  late Timer _timer;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _facts.shuffle(); // Randomize sequence
    _timer = Timer.periodic(const Duration(seconds: 6), (timer) {
      if (mounted) {
        setState(() {
          _currentIndex = (_currentIndex + 1) % _facts.length;
        });
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Container(
            width: double.infinity,
            
            // 📐 1. STRICT HEIGHT: Replaced 'constraints' with a hardcoded 'height'. 
            // Fuck around with this number (try 280, 320, etc.) to get your perfect tall box.
            height: 280, 
            
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08), 
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withOpacity(0.25), 
                width: 1.5,
              ),
            ),
            child: Column(
              // 📐 2. THE LOCK: 'start' pins the header to the top. The facts will flow down.
              mainAxisAlignment: MainAxisAlignment.start, 
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // 📌 THE HEADER (Now permanently locked in place)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center, 
                  children: [
                    const Icon(Icons.auto_awesome, color: Colors.white70, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      "NYC FOOD FACTS",
                      style: TextStyle(
                        fontFamily: 'Courier',
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: Colors.white.withOpacity(0.8),
                        letterSpacing: 2.5,
                      ),
                    ),
                  ],
                ),
                
                // ↕️ 3. TWEAK SPACING: This is the gap between the locked header and the facts.
                const SizedBox(height: 32), 
                
                // 📝 THE FACTS (Fills the space below without shifting the header)
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 400),
                  transitionBuilder: (Widget child, Animation<double> animation) {
                    return FadeTransition(opacity: animation, child: child);
                  },
                  child: Text(
                    _facts[_currentIndex],
                    key: ValueKey<int>(_currentIndex),
                    textAlign: TextAlign.center, 
                    style: const TextStyle(
                      fontFamily: 'Courier',
                      fontSize: 16, 
                      color: Colors.white,
                      height: 1.6, 
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}