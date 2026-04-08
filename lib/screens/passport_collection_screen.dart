import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/passport_service.dart';
import 'passport_stack_screen.dart';
import '../models/restaurant.dart';
import '../widgets/animated_background.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // 👈 To check auth status
import 'paywall_screen.dart'; // 👈 To go to shop
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart'; // 👈 ADD THIS

class PassportCollectionScreen extends StatefulWidget {
  final String? initialBookId;
  final Restaurant? incomingRestaurant;

  const PassportCollectionScreen({
    super.key,
    this.initialBookId,
    this.incomingRestaurant,
  });

  @override
  State<PassportCollectionScreen> createState() =>
      _PassportCollectionScreenState();
}

class _PassportCollectionScreenState extends State<PassportCollectionScreen> {
  late PageController _pageController;
  List<Map<String, dynamic>> _library = [];
  bool _isLoading = true;
  String _currentSku = 'store';
  int _currentIndex = 0;
  bool _hideStatusPill = false;
  bool _triggerDetailOpen = false; // 👈 ADD THIS STATE VARIABLE
  // 📨 HANDOFF STATE
  Restaurant? _pendingStampRestaurant;
  Restaurant?
  _activeStampRestaurant; // 👈 NEW: A mutable copy of the payload we can destroy
  final GlobalKey _wildcardKey = GlobalKey(); // 👈 ADD THIS KEY

  @override
  void initState() {
    super.initState();
    debugPrint("🚀 INIT STATE STARTED");
    _activeStampRestaurant = widget.incomingRestaurant;
    _loadLibrary();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndShowTravelerNote();
      // ❌ DELETE _checkAndShowTutorial() FROM HERE entirely!
    });
  }

  Future<void> _checkAndShowTutorial() async {
    final prefs = await SharedPreferences.getInstance();
    final String? stage = prefs.getString('tutorial_stage');

    if (stage == 'collection_screen') {
      // ❌ No more blind timers here! Just execute immediately.
      if (mounted) _showCollectionTutorial();
    }
  }

  void _showCollectionTutorial() {
    final size = MediaQuery.of(context).size; // 👈 Get screen dimensions

    TutorialCoachMark(
      targets: [
        TargetFocus(
          identify: "wildcard_target",
          keyTarget: _wildcardKey,
          shape: ShapeLightFocus.RRect,
          radius: 20,
          contents: [
            TargetContent(
              align: ContentAlign.custom, // 👈 BYPASS DEFAULT ALIGNMENT
              customPosition: CustomTargetContentPosition(
                top:
                    size.height * 0.15, // 👈 Lock it 15% down from the top edge
              ),
              builder: (context, controller) => Container(
                // 👈 Add a dark backing so it's readable floating OVER the card
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
                      "THE WILDCARD",
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
                      "This is your default travel document. It can hold up to 4 stamps from any cuisine.\n\nTap NEXT, then tap the passport to open it.",
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                        height: 1.4,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () => controller.next(),
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
        SharedPreferences.getInstance().then((prefs) {
          prefs.setString('tutorial_stage', 'detail_screen');
          setState(() => _triggerDetailOpen = true);
        });
      },
    ).show(context: context);
  }

  // 🔄 Updated Signature: Accepts {preservePage}
  Future<void> _loadLibrary({bool preservePage = false}) async {
    try {
      // 🏥 STEP 1: Run the Health Check FIRST
      await PassportService.validateLibraryIntegrity();

      // 🔄 STEP 2: Fetch the data
      final library = await PassportService.fetchUserLibrary();

      if (mounted) {
        int targetIndex;

        // 🧠 LOGIC: If preserving page (e.g. after stamping), stay put.
        // Otherwise, jump to the active book.
        if (preservePage &&
            _currentIndex > 0 &&
            _currentIndex - 1 < library.length) {
          targetIndex = _currentIndex;
        } else {
          // Normal flow: jump to the active book
          targetIndex = library.isNotEmpty ? 1 : 0;
          final activeBookIndex = library.indexWhere(
            (book) => book['status'] == 'active',
          );

          if (activeBookIndex != -1) {
            targetIndex = activeBookIndex + 1;
          }

          if (widget.initialBookId != null) {
            final widgetTargetIndex = library.indexWhere(
              (b) => b['id'] == widget.initialBookId,
            );
            if (widgetTargetIndex != -1) targetIndex = widgetTargetIndex + 1;
          }
        }

        setState(() {
          _library = library;
          _currentIndex = targetIndex;

          if (targetIndex == 0) {
            _currentSku = 'store';
          } else {
            if (targetIndex - 1 < library.length) {
              _currentSku = library[targetIndex - 1]['sku_type'] ?? 'free_tier';
            }
          }
          // Only reset controller if we are NOT preserving the page (or it's the first load)
          if (!preservePage || _isLoading) {
            _pageController = PageController(
              initialPage: targetIndex,
              viewportFraction: 1.0,
            );
          }
        });
      }
    } catch (e) {
      debugPrint("Library Load Error: $e");
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
        // ❌ REMOVE the Future.delayed tutorial trigger from here completely!
      }
    }
  }

  void _onPageChanged(int index) {
    debugPrint("🔍 [PAGE CHANGE] New Index: $index");
    setState(() {
      _currentIndex = index;
      String newSku = 'free_tier'; // Default

      if (index == 0) {
        debugPrint("🔍 [SKU SWITCH] -> store");
        newSku = 'store';
      } else {
        if (index - 1 < _library.length) {
          // 🌟 REVERTED: Just use the raw SKU. Wildcard gets its Blue background back!
          newSku = _library[index - 1]['sku_type'] ?? 'free_tier';
          debugPrint("🔍 [SKU SWITCH] -> $newSku");
        }
      }
      _currentSku = newSku;
      _updateSystemUI(newSku);
    });
  }

  void _updateSystemUI(String sku) {
    bool isLightBg =
        (sku == 'free_tier' || sku == 'single_visa' || sku == 'one_time_pass');

    SystemChrome.setSystemUIOverlayStyle(
      isLightBg ? SystemUiOverlayStyle.dark : SystemUiOverlayStyle.light,
    );
  }

  Widget _buildStatusControl() {
    // 0. SHOP PAGE (Index 0)
    if (_currentIndex == 0) {
      return _buildMorphingPill(
        text: "PASSPORT SHOP",
        color: Colors.blueAccent,
        icon: Icons.shopping_bag,
      );
    }

    // 1. SAFETY CHECKS
    if (_library.isEmpty || _currentIndex - 1 >= _library.length) {
      return const SizedBox();
    }

    // 2. DATA EXTRACTION
    final book = _library[_currentIndex - 1];
    final String bookId = book['id'];
    final String sku = book['sku_type'] ?? 'free_tier';
    final String status = book['status'] ?? 'inactive';

    // Capacity Check
    final stamps = book['stamps'] as List? ?? [];
    final int maxPages = book['max_pages'] ?? 1;
    final bool isFull = stamps.length >= (maxPages * 4);

    // 3. 🧠 THE FIFO PILL LOGIC

    // A. ARCHIVED (Dead & Buried)
    if (isFull) {
      return _buildMorphingPill(
        text: "ARCHIVED",
        color: const Color(0xFF424242), // Graphite
        icon: Icons.inventory_2_outlined,
        textColor: Colors.white70,
      );
    }

    // B. WILDCARD EXCEPTION (The Mercenary)
    if (sku == 'free_tier') {
      if (status == 'active') {
        return _buildMorphingPill(
          text: "WILDCARD ACTIVE",
          color: Colors.white,
          icon: Icons.flash_on,
          textColor: Colors.black,
        );
      } else {
        return _buildMorphingPill(
          text: "USE WILDCARD",
          color: Colors.white,
          icon: Icons.handshake,
          textColor: Colors.black,
          onTap: () async {
            setState(() => _isLoading = true);
            await PassportService.activateBook(bookId);
            await _loadLibrary();
          },
        );
      }
    }

    // C. PRIMARY PASSPORT (The King)
    if (status == 'active') {
      return _buildMorphingPill(
        text: "PRIMARY PASSPORT",
        color: const Color(0xFF69F0AE), // Posh Green
        icon: Icons.check_circle,
        textColor: Colors.black87,
      );
    }

    // D. IN QUEUE (The Heir)
    return _buildMorphingPill(
      text: "UP NEXT",
      color: const Color(0xFFFFB74D), // Soft Orange
      icon: Icons.hourglass_empty,
      textColor: Colors.black87,
    );
  }

  // 🛠 THE UNIFIED MORPHING ENGINE (Glitch-Free Version)
  Widget _buildMorphingPill({
    required String text,
    required Color color,
    required IconData icon,
    Color textColor = Colors.white,
    VoidCallback? onTap,
  }) {
    final bool isInteractive = onTap != null;

    return Positioned(
      bottom: 50,
      left: 0,
      right: 0,
      child: Center(
        child: IgnorePointer(
          ignoring: _hideStatusPill,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: _hideStatusPill ? 0.0 : 1.0,
            child: GestureDetector(
              onTap: onTap,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: isInteractive
                          ? Colors.black.withOpacity(0.3)
                          : color.withOpacity(0.4),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                // 📏 1. ANIMATED SIZE: Forces the container width to stretch/shrink smoothly
                child: AnimatedSize(
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeOutBack,
                  alignment: Alignment.center,
                  // ✨ 2. ANIMATED SWITCHER: Handles the cross-fade of the text & icons
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    // 👇 THE MAGIC FIX: This stops the container from "jumping" to max width
                    layoutBuilder: (currentChild, previousChildren) {
                      return Stack(
                        alignment: Alignment.center,
                        children: [
                          // Forces old fading widgets to not affect the layout bounds
                          ...previousChildren.map(
                            (child) => Positioned(child: child),
                          ),
                          if (currentChild != null) currentChild,
                        ],
                      );
                    },
                    child: Row(
                      key: ValueKey(
                        text,
                      ), // 👈 Triggers the animation when text changes
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(icon, size: 18, color: textColor),
                        const SizedBox(width: 8),
                        Text(
                          text,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                            letterSpacing: 1.2,
                            color: textColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _switchToBook(String bookId, {Restaurant? stampPayload}) async {
    // 1. ⚡️ ACTIVATE THE TARGET BOOK LEGALLY
    // ✂️ REMOVED: setState(() => _isLoading = true); -> This caused the black screen glitch!
    await PassportService.activateBook(bookId);

    // 2. 🔄 REFRESH LIBRARY
    // Pass preservePage: true so the UI stays rock solid while data loads
    await _loadLibrary(preservePage: true);

    // 3. 🎬 FLIP THE PAGE
    final index = _library.indexWhere((b) => b['id'] == bookId);
    if (index != -1) {
      if (stampPayload != null) {
        _pendingStampRestaurant = stampPayload;
      }

      _pageController.animateToPage(
        index + 1,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOutQuart,
      );
    }
  }

  Future<void> _checkAndShowTravelerNote() async {
    final prefs = await SharedPreferences.getInstance();
    final String? stage = prefs.getString('tutorial_stage');

    // 🛑 SUPPRESS MANIFESTO DURING THE TOUR
    if (stage == 'collection_screen') return;
    // Default to true so it shows the first time
    final bool showNote = prefs.getBool('show_traveler_note') ?? true;

    if (!showNote) return;

    bool doNotShowAgain = true; // Default state is ON as requested

    if (!mounted) return;
    await showDialog(
      context: context,
      barrierDismissible: false, // Forces use of the 'X' button
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              backgroundColor: const Color(0xFF1A1A1A), // Very dark grey
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // ❌ TOP LEFT CROSS BUTTON
                      Align(
                        alignment: Alignment.topLeft,
                        child: IconButton(
                          icon: const Icon(
                            Icons.close,
                            color: Color(0xFFF5F5F5),
                            size: 24,
                          ),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),

                      Flexible(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Column(
                            children: [
                              const Text(
                                "A Note to the Travelers:",
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontFamily: 'AppleGaramond',
                                  // fontStyle: FontStyle.italic,
                                  fontSize: 26,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFF5F5F5), // Off-white
                                ),
                              ),
                              const SizedBox(height: 24),
                              const Text(
                                "        No subscriptions in this app. And no ads. I, too, am tired of apps charging \$4.99 a month until eternity to make the ads go away, or locking basic functionalities behind the infamous paywall. The core functionality of this app: exploring the 36,000+ restaurants across New York City will be free. I, personally, love New York City, and this is a service that I would like to do for the lovely people inhabiting it.\n\n"
                                "        Collecting the visas and the immigration stamps for the restaurants will also be free, but will be limited to a maximum of 4 in the Wild Card Visa page. If the Travelers wish, they can purchase a new Passport, and they will own it forever. No hidden charges, no other BS. Just how a real passport would work (excluding, of course, the boring formalities). The visas and the stamps, too, are yours forever; a memoir of your explorations.\n\n"
                                "        So, share your passport cards with the world and with us (tag us @nyceats.passports if you’d like!). Bon Appétit, and Happy Journey!\n\n"
                                "        - With love,\n"
                                "        Barbell Apps",
                                style: TextStyle(
                                  fontFamily: 'AppleGaramond',
                                  fontStyle: FontStyle.italic,
                                  fontSize: 24,
                                  color: Color(0xFFE0E0E0),
                                  height: 1.5,
                                ),
                              ),
                              const SizedBox(height: 28),

                              // ✅ "DO NOT SHOW AGAIN" CHECKBOX
                              GestureDetector(
                                onTap: () => setDialogState(
                                  () => doNotShowAgain = !doNotShowAgain,
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Checkbox(
                                      value: doNotShowAgain,
                                      activeColor: Colors.white,
                                      checkColor: Colors.black,
                                      side: const BorderSide(
                                        color: Colors.white54,
                                      ),
                                      onChanged: (val) => setDialogState(
                                        () => doNotShowAgain = val!,
                                      ),
                                    ),
                                    const Text(
                                      "Do not show again",
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 13,
                                        fontFamily:
                                            'SFPro', // Using the utility font for the control
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    // 💾 Save the preference: If they left it Checked (True), we set showNote to False.
    await prefs.setBool('show_traveler_note', !doNotShowAgain);
  }

  @override
  Widget build(BuildContext context) {
    debugPrint(
      "🔍 [BUILD] Rendering frame. Index: $_currentIndex, SKU: $_currentSku",
    );
    // 🛡️ SAFE SYSTEM UI UPDATE
    // We move this calculation to be 100% safe against nulls
    bool isLightBg =
        _currentSku == 'free_tier' ||
        _currentSku == 'single_visa' ||
        _currentSku == 'single_page';

    if (_currentSku == 'store') {
      isLightBg = false; // Store is Dark Mode (Dark Blue bg)
    }

    // Only update if mounted to prevent "element dirty" errors
    // (Ideally call this in onPageChanged, but this is a quick patch)
    // SystemChrome.setSystemUIOverlayStyle(isLightBg ? SystemUiOverlayStyle.dark : SystemUiOverlayStyle.light);
    Color textColor = isLightBg ? Colors.black : Colors.white;

    if (_isLoading) {
      // 🛡️ Use a color so you know it's loading, not crashed
      return const Scaffold(
        backgroundColor: Color(0xFF111111),
        body: Center(
          child: CupertinoActivityIndicator(color: Colors.white, radius: 16),
        ),
      );
    }
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: isLightBg ? SystemUiOverlayStyle.dark : SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            // 1. THE MOVING ATMOSPHERE
            Positioned.fill(
              // 🛡️ DEBUGGING: If this crashes, wrap it in a Container with color to check
              child: AnimatedBackground(sku: _currentSku),
            ),

            // 2. PageView
            Positioned.fill(
              child: PageView.builder(
                controller: _pageController,
                // 🛡️ PREVENT OVERFLOW: Use max(1, ...) so we always have at least the store
                itemCount: (_library.isEmpty) ? 1 : _library.length + 1,
                onPageChanged: _onPageChanged,
                itemBuilder: (context, index) {
                  // 1. PAGE 0: THE SHOP CARD
                  if (index == 0) {
                    return const _StoreCardPlaceholder();
                  }

                  // 2. SAFETY CHECK: Accessing library
                  final bookIndex = index - 1;
                  if (bookIndex < 0 || bookIndex >= _library.length)
                    return const SizedBox();

                  final book = _library[bookIndex];

                  // 1. CALCULATE HANDOFF
                  // We check if we have a pending stamp AND if this specific book instance
                  // matches the currently visible book (based on _currentIndex).
                  final bool isTargetBook =
                      _pendingStampRestaurant != null &&
                      (_currentIndex - 1 >= 0 &&
                          _currentIndex - 1 < _library.length) &&
                      book['id'] == _library[_currentIndex - 1]['id'];

                  return Padding(
                    // ❌ REMOVE the key from the Padding widget: key: bookIndex == (_currentIndex - 1) ? _wildcardKey : null,
                    padding: const EdgeInsets.only(top: 45),
                    child: PassportStackScreen(
                      key: ValueKey(book['id']),
                      bookId: book['id'],
                      skuType: book['sku_type'] ?? 'free_tier',
                      isReadOnly: book['status'] != 'active',
                      triggerOpenDetail: bookIndex == (_currentIndex - 1)
                          ? _triggerDetailOpen
                          : false,
                      onDetailOpened: () =>
                          setState(() => _triggerDetailOpen = false),
                      incomingRestaurant: (bookIndex == (_currentIndex - 1))
                          ? _activeStampRestaurant
                          : null,
                      autoTriggerRestaurant: isTargetBook
                          ? _pendingStampRestaurant
                          : null,
                      onAutoTriggerComplete: () {
                        _pendingStampRestaurant = null;
                      },
                      onStampComplete: () {
                        _activeStampRestaurant = null;
                        _loadLibrary(preservePage: true);
                      },
                      onButtonVisibilityChanged: (isVisible) {
                        if (_hideStatusPill != isVisible) {
                          setState(() => _hideStatusPill = isVisible);
                        }
                      },
                      onRequestBookSwitch: (targetId) {
                        _activeStampRestaurant = null;
                        _switchToBook(
                          targetId,
                          stampPayload: widget.incomingRestaurant,
                        );
                      },

                      // 👇 ADD THESE TWO NEW LINES 👇
                      tutorialKey: bookIndex == (_currentIndex - 1)
                          ? _wildcardKey
                          : null,
                      onReady: bookIndex == (_currentIndex - 1)
                          ? _checkAndShowTutorial
                          : null,
                    ),
                  );
                },
              ),
            ),

            // 3. THE LOCKED FLOATING HEADER
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8.0,
                    vertical: 8.0,
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(
                          Icons.arrow_back_ios_new,
                          size: 20,
                          color: textColor,
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                      Expanded(
                        child: Text(
                          "PASSPORT COLLECTION",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: textColor,
                            fontFamily: 'Courier',
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      const SizedBox(width: 48),
                    ],
                  ),
                ),
              ),
            ),
            // 4. STATUS CONTROL PANEL
            _buildStatusControl(),
          ],
        ),
      ),
    );
  }
}

class _StoreCardPlaceholder extends StatelessWidget {
  const _StoreCardPlaceholder();
  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: const Alignment(0, 0.2),
      child: Container(
        width: 340,
        height: 540,
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white24),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.add_circle_outline,
              color: Colors.white54,
              size: 60,
            ),
            const SizedBox(height: 20),
            const Text(
              "NEW PASSPORT",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 10),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                "Start a new chapter.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ),
            const SizedBox(height: 30),

            // 👇 GATEKEEPER BUTTON 👇
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
              ),
              onPressed: () {
                // 🟢 Let everyone into the shop so they can feel the books
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const PaywallScreen()),
                );
              },
              child: const Text("BROWSE SHOP"),
            ),
          ],
        ),
      ),
    );
  }
}
