import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nyc_eats/widgets/backgrounds/baggage_tag_background.dart';
import 'package:nyc_eats/widgets/backgrounds/tablecloth_background.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import '../widgets/backgrounds/coordinate_collage_background.dart';
import '../widgets/backgrounds/postage_stamp_background.dart';
import 'package:screenshot/screenshot.dart';
import '../widgets/backgrounds/checkered_background.dart'; 

import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:gal/gal.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:ui'; 
import 'package:flutter/cupertino.dart';
import '../widgets/backgrounds/mta_background.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/backgrounds/warhol_background.dart';
import 'paywall_screen.dart'; 
import '../widgets/backgrounds/photobooth_background.dart';
import 'package:image_picker/image_picker.dart';

// 🗺️ FAST & FREE BOROUGH CALCULATOR
String getBorough(double lat, double lng) {
  if (lat > 40.70 && lat < 40.88 && lng > -74.02 && lng < -73.91) return "MANHATTAN";
  if (lat > 40.57 && lat < 40.74 && lng > -74.04 && lng < -73.85) return "BROOKLYN";
  if (lat > 40.69 && lat < 40.80 && lng > -73.96 && lng < -73.70) return "QUEENS";
  if (lat > 40.80 && lat < 40.92 && lng > -73.93 && lng < -73.78) return "BRONX";
  if (lat > 40.50 && lat < 40.65 && lng > -74.26 && lng < -74.05) return "STATEN ISLAND";
  return "NEW YORK"; 
}

class PassportDetailScreen extends StatefulWidget {
  final String heroTag; 
  final Widget cardWidget;
  final Color backgroundColor;
  final String cuisine;
  final List<Map<String, String>> stamps;

  const PassportDetailScreen({
    super.key,
    required this.heroTag,
    required this.cardWidget,
    required this.backgroundColor,
    required this.cuisine,
    required this.stamps,
  });

  @override
  State<PassportDetailScreen> createState() => _PassportDetailScreenState();
}

class _PassportDetailScreenState extends State<PassportDetailScreen> with SingleTickerProviderStateMixin {
  Offset _cardPosition = Offset.zero;
  double _cardScale = 0.85;
  double _cardRotation = 0.0;

  Offset _stripPosition = Offset.zero;
  Offset _baseStripPosition = Offset.zero;

  Offset _baseCardPosition = Offset.zero;
  double _baseScale = 0.85;
  double _baseRotation = 0.0;
  Offset _startFocalPoint = Offset.zero;

  late AnimationController _squishController;
  late Animation<double> _squishAnimation;
  
  int _currentBgIndex = 0;
  bool _isMtaNightMode = true; 
  bool _isDragging = false;
  bool _isPassportOnTop = true; 
  bool _isSavingToCameraRoll = false; // 👈 NEW: Tracks the download state

  late List<bool> _bgIsLight;   
  final ScreenshotController _cardOnlyController = ScreenshotController();
  final ScreenshotController _fullScreenController = ScreenshotController();

  List<Map<String, dynamic>> _mtaStations = [];
  bool _isLoadingStations = true;

  // 📸 PHOTOBOOTH MEMORY VARIABLES
  List<String?> _savedPhotoPaths = [null, null, null, null]; 
  List<int> _photoRotations = [0, 0, 0, 0]; 
  String _savedDateText = "";
  
  // 💌 POSTAGE STAMP MEMORY VARIABLES
  List<String> _stampPhotoPaths = []; // Holds the user's custom stamp photos
  bool _isShowingPhotoStamps = false; // (You added this in Step 1)
  bool _showMiniGallery = false;      // 🌟 NEW: Tracks if the mini-gallery overlay is open
  
  bool _isPassportInTopSlot = true; // 👈 Replaced _isPassportOnLeft

  bool _isPositionInitialized = false; 

  final GlobalKey _cardKey = GlobalKey();
  final GlobalKey _actionsKey = GlobalKey();
  int? _loadingSlotIndex; // Tracks which slot is opening the gallery
  
  @override
  void initState() {
    super.initState();

    _bgIsLight = [true, true, true, false, true, false, true, false, false]; 

    _squishController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    
    _squishAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _squishController, curve: Curves.easeInOut),
    );

    _fetchMtaStations(); 
    _loadPhotoboothMemories(); // 👈 ADD THIS
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndShowTutorial();
    });
  }

  // 🧠 SILENTLY LOAD SAVED PHOTOS FROM DEVICE CACHE
  Future<void> _loadPhotoboothMemories() async {
    final prefs = await SharedPreferences.getInstance();
    final directory = await getApplicationDocumentsDirectory();
    final String basePath = directory.path;
    
    final String memoryKey = "photobooth_${widget.heroTag}"; 

    // 🛡️ Helper to dynamically reconstruct the path and prevent grey box crashes
    String? getValidPath(String? storedValue) {
      if (storedValue == null || storedValue.isEmpty) return null;
      
      // If an old absolute path is lingering in memory, we extract just the file name
      final String fileName = storedValue.split('/').last;
      final String fullPath = '$basePath/$fileName';
      
      // Only return the path if the image actually survived the cache clear
      if (File(fullPath).existsSync()) {
        return fullPath;
      }
      return null; 
    }

    setState(() {
      _savedPhotoPaths[0] = getValidPath(prefs.getString('${memoryKey}_slot0'));
      _savedPhotoPaths[1] = getValidPath(prefs.getString('${memoryKey}_slot1'));
      _savedPhotoPaths[2] = getValidPath(prefs.getString('${memoryKey}_slot2'));
      // Load photo slots... existing code
      _savedPhotoPaths[3] = getValidPath(prefs.getString('${memoryKey}_slot3')); 
      
      // 👇 NEW: Load Rotations (0-3)
      _photoRotations[0] = prefs.getInt('${memoryKey}_rot0') ?? 0;
      _photoRotations[1] = prefs.getInt('${memoryKey}_rot1') ?? 0;
      _photoRotations[2] = prefs.getInt('${memoryKey}_rot2') ?? 0;
      _photoRotations[3] = prefs.getInt('${memoryKey}_rot3') ?? 0;
      
      _savedDateText = prefs.getString('${memoryKey}_date') ?? 
          "${_getShortMonth(DateTime.now().month)} ${DateTime.now().day}, ${DateTime.now().year}";
    });

    // --- LOAD POSTAGE STAMP MEMORIES ---
    final String stampMemoryKey = "custom_stamps_${widget.heroTag}";
    final List<String> cachedStampNames = prefs.getStringList(stampMemoryKey) ?? [];
    
    List<String> validStampPaths = [];
    for (String fileName in cachedStampNames) {
      final String fullPath = '$basePath/$fileName';
      if (File(fullPath).existsSync()) {
        validStampPaths.add(fullPath);
      }
    }

    setState(() {
      _stampPhotoPaths = validStampPaths;
      // Only default to showing photos if they actually have enough valid photos saved
      _isShowingPhotoStamps = _stampPhotoPaths.length >= 3; 
    });
  }

  String _getShortMonth(int month) {
    const months = ["JAN", "FEB", "MAR", "APR", "MAY", "JUN", "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"];
    return months[month - 1];
  }

  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage(int slotIndex) async {
    setState(() => _loadingSlotIndex = slotIndex); // ⏳ Start loading
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image == null) {
        setState(() => _loadingSlotIndex = null); // 🛑 User cancelled
        return; 
      }

      final directory = await getApplicationDocumentsDirectory();
      final String fileName = '${widget.heroTag}_slot$slotIndex\_${DateTime.now().millisecondsSinceEpoch}.png';
      final String permanentPath = '${directory.path}/$fileName';
      
      await File(image.path).copy(permanentPath);

      final prefs = await SharedPreferences.getInstance();
      final String memoryKey = "photobooth_${widget.heroTag}";
      
      setState(() {
        // We still use the absolute path for the immediate UI state so it displays instantly
        _savedPhotoPaths[slotIndex] = permanentPath;
      });
      
      // 🚨 FIX: We ONLY save the file name to the database!
      await prefs.setString('${memoryKey}_slot$slotIndex', fileName);
    } catch (e) {
      debugPrint("Image Picker Error: $e");
    } finally {
      setState(() => _loadingSlotIndex = null); // ✅ Finish loading
    }
  }

  // 💌 MULTI-IMAGE PICKER FOR CUSTOM STAMPS (APPEND-AWARE)
  Future<void> _pickStampPhotos() async {
    try {
      final List<XFile> images = await _picker.pickMultiImage();

      // 1. If they cancel, do nothing.
      if (images.isEmpty) return;

      // 2. Calculate available slots (Max 5 total)
      int availableSlots = 5 - _stampPhotoPaths.length;
      if (availableSlots <= 0) return; // Failsafe

      // 3. Slice the incoming images so they don't exceed the 5 total limit
      final List<XFile> validImages = images.length > availableSlots 
          ? images.sublist(0, availableSlots) 
          : images;

      // 4. Check the PROJECTED total against the Minimum 3 rule
      int projectedTotal = _stampPhotoPaths.length + validImages.length;
      
      if (projectedTotal < 3) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("You need at least 3 photos total! 📸"),
              backgroundColor: Color(0xFFD32F2F),
              behavior: SnackBarBehavior.floating,
              duration: Duration(seconds: 3),
            ),
          );
        }
        return;
      }

      final directory = await getApplicationDocumentsDirectory();
      final prefs = await SharedPreferences.getInstance();
      final String memoryKey = "custom_stamps_${widget.heroTag}";

      // 🌟 THE FIX: Create a brand new list starting with the existing photos
      // This forces the background to recognize the state change!
      List<String> newFullPaths = List.from(_stampPhotoPaths);

      // 5. Save the new images and append them to the list
      for (int i = 0; i < validImages.length; i++) {
        // Use epoch to guarantee unique filenames when appending
        final String fileName = '${widget.heroTag}_stamp_${DateTime.now().millisecondsSinceEpoch}_$i.png';
        final String permanentPath = '${directory.path}/$fileName';

        await File(validImages[i].path).copy(permanentPath);
        newFullPaths.add(permanentPath); 
      }

      // 6. Update State and trigger the background rebuild!
      setState(() {
        _stampPhotoPaths = newFullPaths;
        _isShowingPhotoStamps = true; 
      });

      // 7. Save the updated combined list to device memory
      List<String> updatedFileNames = _stampPhotoPaths.map((path) => path.split('/').last).toList();
      await prefs.setStringList(memoryKey, updatedFileNames);

    } catch (e) {
      debugPrint("🚨 Stamp Multi-Picker Error: $e");
    }
  }

  // 🗑️ DELETE CUSTOM STAMP & THE "UNDER 3" NUKE
  Future<void> _deleteStampPhoto(int index) async {
    setState(() {
      // 🌟 THE FIX: We create a brand new list in memory so the background detects the change!
      List<String> updatedList = List.from(_stampPhotoPaths);
      updatedList.removeAt(index);
      _stampPhotoPaths = updatedList;

      // 2. THE NUKE: If they drop below 3, force the background back to emojis!
      if (_stampPhotoPaths.length < 3 && _isShowingPhotoStamps) {
        _isShowingPhotoStamps = false; // 🌟 Flips the main switch
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Not enough photos! Switched back to standard stamps. 📮"),
            backgroundColor: Color(0xFFD32F2F),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 3),
          ),
        );
      }
    });

    // ... (Keep the rest of the SharedPreferences saving logic exactly as it is)

    // 3. Update device memory so the deleted photo stays gone
    try {
      final prefs = await SharedPreferences.getInstance();
      final String memoryKey = "custom_stamps_${widget.heroTag}";
      
      // We only save the file names to SharedPreferences to prevent path corruption
      List<String> updatedFileNames = _stampPhotoPaths.map((path) => path.split('/').last).toList();
      await prefs.setStringList(memoryKey, updatedFileNames);
      
    } catch (e) {
      debugPrint("🚨 Error updating stamp memory: $e");
    }
  }

  // 🔄 ROTATE PHOTO 90 DEGREES CLOCKWISE
  Future<void> _rotatePhoto(int index) async {
    // Cycles from 0 -> 1 -> 2 -> 3 -> 0
    int newRotation = (_photoRotations[index] + 1) % 4; 
    
    final prefs = await SharedPreferences.getInstance();
    final String memoryKey = "photobooth_${widget.heroTag}";
    
    setState(() {
      _photoRotations[index] = newRotation;
    });
    
    // Save the rotation state locally
    await prefs.setInt('${memoryKey}_rot$index', newRotation);
  }

  // 📅 OPEN NATIVE DATE PICKER & SAVE
  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        // A custom dark theme to match your cinematic app aesthetic
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Colors.white,
              onPrimary: Colors.black,
              surface: Color(0xFF0A192F), // Matches your photo strip blue!
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      final formattedDate = "${_getShortMonth(picked.month)} ${picked.day}, ${picked.year}";
      
      final prefs = await SharedPreferences.getInstance();
      final String memoryKey = "photobooth_${widget.heroTag}";
      
      setState(() {
        _savedDateText = formattedDate;
      });
      
      await prefs.setString('${memoryKey}_date', formattedDate);
    }
  }
  
  Future<void> _checkAndShowTutorial() async {
    final prefs = await SharedPreferences.getInstance();
    final String? stage = prefs.getString('tutorial_stage');
    
    if (stage == 'detail_screen') {
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted) _showDetailTutorial();
      });
    }
  }

  void _showDetailTutorial() {
    final size = MediaQuery.of(context).size; 

    TutorialCoachMark(
      targets: [
        TargetFocus(
          identify: "card_target",
          keyTarget: _cardKey,
          shape: ShapeLightFocus.RRect,
          radius: 20,
          contents: [
            TargetContent(
              align: ContentAlign.custom, 
              customPosition: CustomTargetContentPosition(top: size.height * 0.15),
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
                    const Text("THE SOUVENIR", style: TextStyle(fontFamily: 'AppleGaramond', fontWeight: FontWeight.bold, color: Colors.white, fontSize: 26, letterSpacing: 1.5)),
                    const SizedBox(height: 12),
                    const Text("Tap the background to change the artwork. Pinch and twist the passport to adjust its placement.", style: TextStyle(color: Colors.white70, fontSize: 16, height: 1.4, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () => controller.next(),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999))),
                      child: const Text("NEXT", style: TextStyle(fontFamily: 'Courier', fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        
        TargetFocus(
          identify: "actions_target",
          keyTarget: _actionsKey,
          shape: ShapeLightFocus.RRect,
          radius: 30,
          contents: [
            TargetContent(
              align: ContentAlign.top, 
              builder: (context, controller) => Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Text("THE MEMORY", style: TextStyle(fontFamily: 'AppleGaramond', fontWeight: FontWeight.bold, color: Colors.white, fontSize: 26, letterSpacing: 1.5)),
                  const SizedBox(height: 12),
                  const Text("Save it to your camera roll or share it to your story.\n\nNow, let's visit the Shop.", textAlign: TextAlign.center, style: TextStyle(color: Colors.white70, fontSize: 16, height: 1.4, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => controller.next(), 
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999))),
                    child: const Text("NEXT", style: TextStyle(fontFamily: 'Courier', fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                  ),
                ],
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
          prefs.setString('tutorial_stage', 'shop_screen');
        });
        
        Navigator.pop(context); 
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PaywallScreen()));
      },
    ).show(context: context);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isPositionInitialized) {
      final size = MediaQuery.of(context).size;
      _cardPosition = Offset(size.width / 2, size.height / 2);
      _cardScale = 0.85; 
      // 👇 FIX: Start the strip completely off-screen on boot
      _stripPosition = Offset(size.width * 1.5, size.height / 2);
      _isPositionInitialized = true;
    }
  }

  void _updateDefaultCardPosition(int previousIndex) {
    final size = MediaQuery.of(context).size;
    setState(() {
      if (_currentBgIndex != 8) {
        _stripPosition = Offset(size.width * 1.5, size.height / 2);
      }
      
      // 1. ENTERING MTA (Index 5)
      if (_currentBgIndex == 5) { 
        bool hasBottomBlobs = _mtaStations.length == 2 || _mtaStations.length >= 4;

        double screenW = size.width;
        double screenH = size.height;
        
        double baseCardW = (screenW * 0.85).clamp(300.0, 400.0);
        double baseCardH = baseCardW * (540 / 340);
        
        // Exact architectural margins from the background
        double notchMargin = 80.0;
        double pillMargin = 110.0;
        double targetBH = screenH * 0.13;
        double safePadding = 40.0; // 🌟 20px guaranteed gap on top and bottom
        
        if (hasBottomBlobs) {
           double topBlobBottom = notchMargin + targetBH;
           double bottomBlobTop = (screenH - pillMargin) - targetBH;
           double availableH = bottomBlobTop - topBlobBottom;
           
           double maxCardH = availableH - safePadding;
           double idealScale = maxCardH / baseCardH;
           
           // 🌟 Let it grow massively on iPads, but protect it from over-shrinking on SEs
           _cardScale = idealScale.clamp(0.65, 0.95); 
           _cardPosition = Offset(screenW / 2, topBlobBottom + (availableH / 2));
        } else {
           double topBlobBottom = notchMargin + targetBH;
           double availableH = (screenH - pillMargin) - topBlobBottom;
           
           double maxCardH = availableH - safePadding;
           double idealScale = maxCardH / baseCardH;
           
           // 🌟 Let it hit full 1.0 scale on larger screens
           _cardScale = idealScale.clamp(0.75, 1.0); 
           // Nudge slightly below center for visual balance
           _cardPosition = Offset(screenW / 2, topBlobBottom + (availableH * 0.52));
        }
        _cardRotation = 0.0; 
      }
      // ... (keep your existing Photobooth and Exit logic below)
      // 2. ENTERING PHOTOBOOTH TABLETHROW (Index 8)
      else if (_currentBgIndex == 8) {
        _cardRotation = 1.570796; // 👈 90 degrees
        
        double screenW = size.width;
        double screenH = size.height;
        
        double cardW = (screenW * 0.85).clamp(300.0, 400.0);
        double cardH = cardW * (540 / 340);
        
        _cardScale = (screenW * 0.88) / cardH; 
        
        // Calculate the actual visual height of the rotated passport
        double visualCardH = cardW * _cardScale;
        
        // Exact Padding Metrics
        double topPadding = MediaQuery.of(context).padding.top + 20; 
        double bottomPadding = 120.0; // Room for the action pill
        double gap = 20.0; // The space between the passport and strip
        
        // Calculate remaining vertical space for the strip to fill
        double availableH = screenH - topPadding - bottomPadding;
        double visualStripH = availableH - visualCardH - gap;
        
        double centerX = size.width / 2;
        
        // 👇 FIX: Dynamically calculate centers based on which item's height is on top
        if (_isPassportInTopSlot) {
          // Passport on top, Strip on bottom
          _cardPosition = Offset(centerX, topPadding + (visualCardH / 2));
          _stripPosition = Offset(centerX, topPadding + visualCardH + gap + (visualStripH / 2));
        } else {
          // Strip on top, Passport on bottom
          _stripPosition = Offset(centerX, topPadding + (visualStripH / 2));
          _cardPosition = Offset(centerX, topPadding + visualStripH + gap + (visualCardH / 2));
        }
      }
      
      // 3. EXITING SPECIAL BACKGROUNDS
      else if (previousIndex == 5 || previousIndex == 8) {
        _cardPosition = Offset(size.width / 2, size.height / 2);
        _cardScale = 0.85; 
        _cardRotation = 0.0; // 👈 Animates beautifully back to straight!
      }
    });
  }

  Future<void> _saveToCameraRoll() async {
    // 🛡️ Prevent double-taps while it's already saving
    if (_isSavingToCameraRoll) return;

    setState(() => _isSavingToCameraRoll = true); // 🎬 START LOADING

    try {
      Uint8List? imageBytes;

      if (_currentBgIndex == 6) { 
        imageBytes = await _cardOnlyController.capture(pixelRatio: 3.0);
      } else {
        imageBytes = await _fullScreenController.capture(pixelRatio: 3.0);
      }

      if (imageBytes == null) return;

      final bool hasAccess = await Gal.hasAccess();
      // The spinner will keep rotating while this OS sheet is on screen!
      if (!hasAccess) await Gal.requestAccess();

      final directory = await getTemporaryDirectory();
      final imagePath = '${directory.path}/nyceats_passport_${DateTime.now().millisecondsSinceEpoch}.png';
      final imageFile = File(imagePath);
      await imageFile.writeAsBytes(imageBytes);

      await Gal.putImage(imagePath);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Saved to Camera Roll! 📸"),
            backgroundColor: Color(0xFF1A237E),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint("Save error: $e");
    } finally {
      // 🛑 STOP LOADING (Guaranteed to run, even on error or permission denial)
      if (mounted) {
        setState(() => _isSavingToCameraRoll = false);
      }
    }
  }

  Future<void> _shareToStory() async {
    try {
      final Uint8List? imageBytes = await _fullScreenController.capture(pixelRatio: 3.0);
      if (imageBytes == null) return;

      final directory = await getTemporaryDirectory();
      final imagePath = '${directory.path}/nyceats_story_${DateTime.now().millisecondsSinceEpoch}.png';
      final imageFile = File(imagePath);
      await imageFile.writeAsBytes(imageBytes);

      final box = context.findRenderObject() as RenderBox?;
      final Rect? sharePosition = box != null 
          ? box.localToGlobal(Offset.zero) & box.size 
          : null;

      await Share.shareXFiles(
        [XFile(imagePath)],
        text: 'My NYC Eats Passport! 🌎🍽️',
        sharePositionOrigin: sharePosition, 
      );
      
    } catch (e) {
      debugPrint("🚨 CRITICAL SHARE ERROR: $e");
    }
  }

  Future<void> _fetchMtaStations() async {
    final List<String> stationIds = widget.stamps
        .map((stamp) => stamp['mta_station_id']?.toString())
        .where((id) => id != null && id.isNotEmpty)
        .cast<String>()
        .toSet()
        .toList();

    if (stationIds.isEmpty) {
      setState(() => _isLoadingStations = false);
      return;
    }

    try {
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('mta_stations')
          .select()
          .inFilter('id', stationIds)
          .timeout(const Duration(seconds: 3)); // ⏱️ THE 3-SECOND SAFETY VALVE

      if (mounted) {
        setState(() {
          _mtaStations = List<Map<String, dynamic>>.from(response);
          _isLoadingStations = false;
        });
        
        _updateDefaultCardPosition(-1); 
      }
    } catch (e) {
      debugPrint("SUPABASE ERROR (Likely Offline): $e");
      
      // 🌟 GRACEFUL FALLBACK & TOAST
      if (mounted) {
        setState(() => _isLoadingStations = false);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: const [
                Icon(CupertinoIcons.wifi_exclamationmark, color: Colors.white, size: 20),
                SizedBox(width: 12),
                Expanded(child: Text("Offline. Displaying fallback transit data.", style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'SFPro'))),
              ],
            ),
            backgroundColor: Colors.amber[800],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            margin: const EdgeInsets.only(bottom: 20, left: 20, right: 20),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Widget _buildGroovedButton({
    required IconData icon,
    required VoidCallback onTap,
    Color color = Colors.white,
    bool isLoading = false, // 👈 NEW PARAMETER
  }) {
    return GestureDetector(
      onTap: isLoading ? null : onTap, // Prevent tapping while loading
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipOval(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25), 
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withOpacity(0.45), 
                    Colors.white.withOpacity(0.10), 
                    Colors.white.withOpacity(0.0),  
                  ],
                  stops: const [0.0, 0.4, 1.0],
                ),
                border: Border.all(
                  color: Colors.white.withOpacity(0.4), 
                  width: 1.2, 
                ),
              ),
              // 👇 THE FIX: Swap to activity indicator when loading
              child: isLoading 
                  ? CupertinoActivityIndicator(color: color, radius: 13) 
                  : Icon(icon, size: 26, color: color),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _squishController.dispose();
    super.dispose();
  }

  // 🖼️ THE MINI-GALLERY OVERLAY
  Widget _buildMiniGallery() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.45),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.15), width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 1. Draw the existing photos with the JIGGLE
              ..._stampPhotoPaths.asMap().entries.map((entry) {
                int idx = entry.key;
                String path = entry.value;
                return JigglingThumbnail(
                  imagePath: path,
                  onDelete: () {
                    HapticFeedback.lightImpact();
                    _deleteStampPhoto(idx);
                    if (_stampPhotoPaths.isEmpty) {
                      setState(() => _showMiniGallery = false);
                    }
                  },
                );
              }),

              // 2. The "Add More" Button (Only shows if under 5 photos)
              if (_stampPhotoPaths.length < 5)
                GestureDetector(
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    _pickStampPhotos();
                  },
                  child: Container(
                    width: 56, 
                    height: 56,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white30, style: BorderStyle.solid, width: 1),
                    ),
                    child: const Icon(CupertinoIcons.add, color: Colors.white, size: 24),
                  ),
                )
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {

    final double cardWidth = (MediaQuery.of(context).size.width * 0.85).clamp(300.0, 400.0);
    final double cardHeight = cardWidth * (540 / 340);
    
    // 🧮 EXACT FIT VERTICAL MATH
    final double screenW = MediaQuery.of(context).size.width;
    final double screenH = MediaQuery.of(context).size.height;
    final double currentScale = (screenW * 0.88) / cardHeight;
    final double visualCardH = cardWidth * currentScale;
    
    final double topPadding = MediaQuery.of(context).padding.top + 20;
    final double bottomPadding = 120.0;
    final double gap = 20.0;
    final double availableH = screenH - topPadding - bottomPadding;
    final double visualStripH = availableH - visualCardH - gap;
    
    // 👇 FIX 1: Restore original portrait dimensions so the label has room to breathe
    final double stripWidth = visualStripH / currentScale; // Short side
    final double stripHeight = cardHeight; // Long side

    final List<Widget> bgDesigns = [
       // ...
      Container(color: widget.backgroundColor), 
      BaggageTagBackground(cuisine: widget.cuisine, stamps: widget.stamps), 
      // ...
      const PizzeriaTableclothBackground(), 
      CoordinateCollageBackground(stamps: widget.stamps), 
      
      // 🌟 INJECTED: Passing the photos and the switch state into the background!
      RepaintBoundary(
        child: PostageStampBackground(
          cuisine: widget.cuisine,
          userPhotoPaths: _stampPhotoPaths,
          showPhotos: _isShowingPhotoStamps,
        ), 
      ), 
      
      MtaBackground( 
      // ...
        stations: _mtaStations, 
        isDarkMode: _isMtaNightMode, 
        passportPosition: _cardPosition,
        passportScale: _cardScale,
        isDragging: _isDragging, 
      ),
      const CheckeredBackground(), 
      WarholBackground(cuisine: widget.cuisine), 
      const PhotoboothBackground(), 
    ];

    bool isLightBg = _bgIsLight[_currentBgIndex];

    final overlayStyle = isLightBg 
        ? SystemUiOverlayStyle.dark.copyWith(statusBarColor: Colors.transparent)
        : SystemUiOverlayStyle.light.copyWith(statusBarColor: Colors.transparent);

    
    // 🧱 CALCULATE INTERACTION BOUNDARIES (SCALABLE)
    double clampTopPadding = MediaQuery.of(context).padding.top + 20;
    double clampBottomPadding = 120.0;
    double clampGap = 20.0;
    double derivedVisualCardH = cardWidth * ((MediaQuery.of(context).size.width * 0.88) / cardHeight);

    double safeTopY = clampTopPadding;
    double safeBottomY = MediaQuery.of(context).size.height - clampBottomPadding;
    
    // 👇 FIX: Give the card and strip their own exact center-point buffers
    double cardHalfHeight = derivedVisualCardH / 2;
    double stripHalfHeight = visualStripH / 2;

    // We add buffer so the center coordinate can't push visual elements off-screen
    double topClampBuffer = derivedVisualCardH / 2;
    double bottomClampBuffer = stripWidth / 2; // (Since strip is rotated, stripWidth is visual height)

    // 📦 PACKING THE PHOTO STRIP
    final Widget photoStripLayer = AnimatedPositioned(
      duration: _isDragging ? Duration.zero : const Duration(milliseconds: 450),
      curve: _isDragging ? Curves.linear : Curves.easeInOutCubic,
      left: _stripPosition.dx - (stripWidth / 2),
      top: _stripPosition.dy - (stripHeight / 2), 
      width: stripWidth,
      height: stripHeight, 
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 300),
        opacity: _currentBgIndex == 8 ? 1.0 : 0.0,
        child: IgnorePointer(
          ignoring: _currentBgIndex != 8,
          child: AnimatedContainer(
            duration: _isDragging ? Duration.zero : const Duration(milliseconds: 450),  
            curve: _isDragging ? Curves.linear : Curves.easeInOutCubic,
            alignment: Alignment.center,
            transformAlignment: Alignment.center,
            // 👇 FIX 2: Restore the 90-degree right tilt!
            transform: Matrix4.identity()
              ..scale(_currentBgIndex == 8 ? _cardScale : 0.85)
              ..rotateZ(_currentBgIndex == 8 ? 1.570796 : 0.0), 
            child: GestureDetector(
              behavior: HitTestBehavior.opaque, // 🛡️ FORCES the layer to be "solid"
              onTap: () {}, // 🛑 CONSUMES the tap so it doesn't hit the background
              onScaleStart: (details) {
                // ... your existing code
                setState(() {
                  _isDragging = true;
                  _startFocalPoint = details.focalPoint;
                  _baseStripPosition = _stripPosition;
                  _isPassportOnTop = false; // 👈 PULLS STRIP TO FRONT
                });
              },
              onScaleUpdate: (details) {
                setState(() {
                  final Offset delta = details.focalPoint - _startFocalPoint;
                  // Lock X-axis, Drag smoothly on Y-axis
                  double rawY = _baseStripPosition.dy + delta.dy;
                  
                  // 🛡️ APPLY DRAG CONSTRAINTS FOR STRIP (Using the fixes from last time)
                  double constrainedY = rawY.clamp(
                      safeTopY + stripHalfHeight, 
                      safeBottomY - stripHalfHeight
                  );
                  
                  _stripPosition = Offset(_baseStripPosition.dx, constrainedY);
                });
              },
              onScaleEnd: (details) {
                setState(() {
                  _isDragging = false;
                  final size = MediaQuery.of(context).size;
                  // 👇 VERTICAL SWAP LOGIC
                  if (_stripPosition.dy < size.height / 2) {
                    _isPassportInTopSlot = false; 
                  } else {
                    _isPassportInTopSlot = true; 
                  }
                  _updateDefaultCardPosition(-1);
                });
              },
              child: PhotoStripCard(
                borough: "MANHATTAN", 
                dateText: _savedDateText.isEmpty ? "SELECT DATE" : _savedDateText,
                photoPaths: _savedPhotoPaths,
                photoRotations: _photoRotations,
                onDateTapped: _pickDate, 
                onPhotoTapped: (index) => _pickImage(index),
                onRotatePhoto: (index) => _rotatePhoto(index), 
                loadingSlotIndex: _loadingSlotIndex, // 👈 4. PASS THE STATE VARIABLE HERE
              ),
            ),
          ),
        )
      )
    );

    // 📦 PACKING THE PASSPORT
    final Widget passportLayer = AnimatedPositioned(
      key: _cardKey,
      // Change this in both layers (AnimatedPositioned AND AnimatedContainer)
      duration: _isDragging ? Duration.zero : const Duration(milliseconds: 450),
      curve: _isDragging ? Curves.linear : Curves.easeInOutCubic,
      left: _cardPosition.dx - (cardWidth / 2), 
      top: _cardPosition.dy - (cardHeight / 2),
      width: cardWidth,   
      height: cardHeight, 
      child: GestureDetector(
        behavior: HitTestBehavior.opaque, // 🛡️ Intercepts the touch on iPad
        onTap: () {}, // 🛑 Stops the "fall-through" to the background
        onScaleStart: (details) {
          // ... your existing code
          setState(() {
            _isDragging = true; 
            _baseCardPosition = _cardPosition;
            _startFocalPoint = details.focalPoint;
            _baseScale = _cardScale;
            _baseRotation = _cardRotation;
            _isPassportOnTop = true; // 👈 PULLS PASSPORT TO FRONT
          });
        },
        onScaleUpdate: (details) {
          setState(() {
            final Offset delta = details.focalPoint - _startFocalPoint;
            if (_currentBgIndex == 8) {
              // Lock X-axis, Drag smoothly on Y-axis
              double rawY = _baseCardPosition.dy + delta.dy;
              
              // 🛡️ APPLY DRAG CONSTRAINTS FOR PASSPORT
              double constrainedY = rawY.clamp(
                   safeTopY + cardHalfHeight, // Uses card's own height
                   safeBottomY - cardHalfHeight
              );
              
              _cardPosition = Offset(_baseCardPosition.dx, constrainedY);
            } else {
              _cardPosition = _baseCardPosition + delta;
              _cardScale = (_baseScale * details.scale).clamp(0.4, 2.0);
              _cardRotation = _baseRotation + details.rotation;
            }
          });
        },
        // Inside passportLayer's GestureDetector:
        onScaleEnd: (details) {
          setState(() {
             _isDragging = false; 
             final size = MediaQuery.of(context).size;
             if (_currentBgIndex == 5) {
                _updateDefaultCardPosition(-1); 
             } else if (_currentBgIndex == 8) {
                // 👇 VERTICAL SWAP LOGIC
                if (_cardPosition.dy > size.height / 2) {
                  _isPassportInTopSlot = false; // Passport dragged to bottom
                } else {
                  _isPassportInTopSlot = true;  
                }
                _updateDefaultCardPosition(-1); 
             }
          });
        },
        child: AnimatedContainer(
          // Change this in both layers (AnimatedPositioned AND AnimatedContainer)
          duration: _isDragging ? Duration.zero : const Duration(milliseconds: 450),
          curve: _isDragging ? Curves.linear : Curves.easeInOutCubic,
          alignment: Alignment.center,
          transformAlignment: Alignment.center, 
          transform: Matrix4.identity()
            ..scale(_cardScale)
            ..rotateZ(_cardRotation),
          child: Screenshot( 
            controller: _cardOnlyController,
            child: Hero(tag: widget.heroTag, child: widget.cardWidget),
          ),
        ),
      ),
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlayStyle,
      child: Scaffold(
        backgroundColor: Colors.white, 
        body: Stack(
          fit: StackFit.expand,
          children: [
            Screenshot(
              controller: _fullScreenController,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Positioned(
                    top: _currentBgIndex == 5 ? 0 : -100,
                    bottom: _currentBgIndex == 5 ? 0 : -100,
                    left: _currentBgIndex == 5 ? 0 : -100,
                    right: _currentBgIndex == 5 ? 0 : -100,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapDown: (_) => _squishController.forward(),
                      onTapCancel: () => _squishController.reverse(),
                      onTapUp: (_) {
                        _squishController.reverse();
                        
                        int prevIndex = _currentBgIndex; 
                        
                        setState(() {
                          _currentBgIndex = (_currentBgIndex + 1) % bgDesigns.length;
                        });
                        
                        _updateDefaultCardPosition(prevIndex);
                      },
                      child: ScaleTransition(
                        scale: _squishAnimation,
                        child: bgDesigns[_currentBgIndex], 
                      ),
                    ),
                  ),

                  // 🔀 THE DYNAMIC Z-INDEX LAYERS
                  _isPassportOnTop ? photoStripLayer : passportLayer,
                  _isPassportOnTop ? passportLayer : photoStripLayer,
                ],
              ),
            ),
            
            Positioned(
              top: MediaQuery.of(context).padding.top + 10,
              left: 16,
              child: GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(30),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.4), 
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
                      ),
                      child: const Icon(
                        Icons.arrow_back_ios_new, 
                        color: Colors.white, 
                        size: 22,
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // ℹ️ THE INFO BUTTON (TOP RIGHT)
            Positioned(
              top: MediaQuery.of(context).padding.top + 10,
              right: 16,
              child: GestureDetector(
                onTap: _showArtworkInfoModal,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(30),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.4), 
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
                      ),
                      child: const Icon(
                        CupertinoIcons.info, 
                        color: Colors.white, 
                        size: 22,
                      ),
                    ),
                  ),
                ),
              ),
            ),

            Positioned(
              bottom: 40 + MediaQuery.of(context).padding.bottom,
              left: 0,
              right: 0,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_currentBgIndex != 5) ...[
                    Text(
                      "Pinch to resize · Twist to rotate",
                      style: TextStyle(
                        color: isLightBg ? Colors.grey[600] : Colors.grey[400], 
                        fontStyle: FontStyle.italic,
                        letterSpacing: 0.5, 
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // 🌟 INJECTED: The Mini-Gallery Overlay drops in right above the pill
                  if (_currentBgIndex == 4 && _showMiniGallery && _stampPhotoPaths.isNotEmpty) ...[
                    _buildMiniGallery(),
                    const SizedBox(height: 12),
                  ],
                  
                  ClipRRect(
                    borderRadius: BorderRadius.circular(40),
                    child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30), 
                    child: AnimatedSize(
                      key: _actionsKey,
                      duration: const Duration(milliseconds: 350),
                        curve: Curves.easeOutCubic, 
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.15), 
                            borderRadius: BorderRadius.circular(40),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.15), 
                              width: 0.5,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _buildGroovedButton(
                                icon: CupertinoIcons.arrow_down,
                                isLoading: _isSavingToCameraRoll, // 👈 PASS THE STATE HERE
                                onTap: _saveToCameraRoll,
                              ),
                              
                              if (_currentBgIndex != 6) 
                                _buildGroovedButton(
                                  icon: CupertinoIcons.share,
                                  onTap: _shareToStory,
                                ),

                              // 🌟 INJECTED: The dual-purpose Camera / Stamp Toggle
                              if (_currentBgIndex == 4)
                                _buildGroovedButton(
                                  // Looks like a camera if emojis, looks like a ticket/stamp if photos
                                  icon: _isShowingPhotoStamps ? CupertinoIcons.ticket_fill : CupertinoIcons.camera_fill,
                                  color: _isShowingPhotoStamps ? Colors.amber : Colors.white,
                                  onTap: () {
                                    HapticFeedback.selectionClick();
                                    if (_isShowingPhotoStamps) {
                                      setState(() => _isShowingPhotoStamps = false); // Snap to Emojis
                                    } else {
                                      // If they already have 3+ photos saved, just toggle the view instantly
                                      if (_stampPhotoPaths.length >= 3) {
                                        setState(() => _isShowingPhotoStamps = true); 
                                      } else {
                                        // Otherwise, open the gallery
                                        _pickStampPhotos();
                                      }
                                    }
                                  },
                                ),

                              // 🌟 INJECTED: The Gallery Viewer Button (Only appears if photos exist in memory)
                              if (_currentBgIndex == 4 && _stampPhotoPaths.isNotEmpty)
                                _buildGroovedButton(
                                  icon: CupertinoIcons.photo_on_rectangle,
                                  color: _showMiniGallery ? Colors.amber : Colors.white,
                                  onTap: () {
                                    HapticFeedback.lightImpact();
                                    setState(() => _showMiniGallery = !_showMiniGallery);
                                  },
                                ),

                              if (_currentBgIndex == 5)
                                // ... (Keep your MTA Night Mode button exactly as is)
                                _buildGroovedButton(
                                  icon: _isMtaNightMode ? CupertinoIcons.moon_stars_fill : CupertinoIcons.sun_max_fill,
                                  color: _isMtaNightMode ? Colors.indigo[300]! : Colors.amber,
                                  onTap: () {
                                    setState(() {
                                      _isMtaNightMode = !_isMtaNightMode;
                                      _bgIsLight[5] = !_isMtaNightMode; 
                                    });
                                  },
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 📚 THE CONTEXTUAL DATA DICTIONARY
  Map<String, dynamic> _getBackgroundInfo(int index) {
    switch (index) {
      case 0: return {"title": "The Monolith", "desc": "A clean slate perfectly matched to your passport's primary color code.", "icon": CupertinoIcons.square_fill};
      case 1: return {"title": "Baggage Claim", "desc": "Global airport baggage tags routing you directly from JFK to the world.", "icon": CupertinoIcons.ticket_fill};
      case 2: return {"title": "The Pizzeria", "desc": "The classic red-and-white gingham tablecloth. Perfect for a slice.", "icon": Icons.local_pizza_outlined};
      case 3: return {"title": "The Coordinates", "desc": "A pastel collage of the exact GPS locations from your culinary journey.", "icon": CupertinoIcons.compass};
      case 4: return {"title": "Postage Stamps", "desc": "Custom stamps featuring native emojis.\n\nTap the camera icon to load your own memories.", "icon": CupertinoIcons.mail_solid};
      case 5: return {"title": "The Commuter", "desc": "Live subway routings.\n\nTap the sun/moon icon to switch between day and night mode.", "icon": CupertinoIcons.train_style_one};
      case 6: return {"title": "Transparent", "desc": "A completely clear background. Perfect for downloading your passport card exactly as it is.", "icon": Icons.grid_4x4};      case 7: return {"title": "Pop Art", "desc": "A tribute to the legendary New York artist Andy Warhol. A six-panel Marilyn Diptych style print featuring your cuisine's native emoji.", "icon": CupertinoIcons.paintbrush_fill};
      case 8: return {"title": "The Photobooth", "desc": "A late-night photobooth strip.\n\nDrag to tear it off, and tap the squares to load 4 of your favorite snaps.", "icon": CupertinoIcons.camera_fill};
      default: return {"title": "Artwork", "desc": "A unique visual memory of your travels.", "icon": CupertinoIcons.photo};
    }
  }

  // 🖼️ THE CONTEXTUAL GALLERY PLAQUE
  void _showArtworkInfoModal() {
    HapticFeedback.lightImpact();
    
    // Pull the data for the exact background currently on screen
    final info = _getBackgroundInfo(_currentBgIndex);

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "Dismiss",
      barrierColor: Colors.black.withOpacity(0.5), 
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) {
        return Center(
          child: Material(
            color: Colors.transparent,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(32),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                child: Container(
                  width: MediaQuery.of(context).size.width * 0.85,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFF111111).withOpacity(0.65), 
                    border: Border.all(color: Colors.white.withOpacity(0.15), width: 1),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // 1. DISMISS BUTTON
                      Align(
                        alignment: Alignment.topRight,
                        child: GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1), 
                              shape: BoxShape.circle
                            ),
                            child: const Icon(Icons.close, color: Colors.white70, size: 18),
                          ),
                        ),
                      ),
                      
                      // 2. THEMATIC ICON
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(info['icon'], size: 42, color: Colors.amber),
                      ),
                      const SizedBox(height: 24),
                      
                      // 3. TITLE
                      Text(
                        info['title'].toUpperCase(), 
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: 'AppleGaramond', 
                          color: Colors.white, 
                          fontSize: 28, 
                          fontWeight: FontWeight.bold, 
                          letterSpacing: 2.0
                        )
                      ),
                      const SizedBox(height: 16),
                      
                      // 4. DESCRIPTION
                      Text(
                        info['desc'], 
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white70, 
                          fontSize: 15, 
                          height: 1.5,
                          fontWeight: FontWeight.w500
                        )
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
      // SLICK POP-IN ANIMATION
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.95, end: 1.0).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutBack)),
            child: child,
          ),
        );
      },
    );
  }
}

// 📳 THE iOS JIGGLE ANIMATION WIDGET
class JigglingThumbnail extends StatefulWidget {
  final String imagePath;
  final VoidCallback onDelete;

  const JigglingThumbnail({super.key, required this.imagePath, required this.onDelete});

  @override
  State<JigglingThumbnail> createState() => _JigglingThumbnailState();
}

class _JigglingThumbnailState extends State<JigglingThumbnail> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120), // Fast, tight shake
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        // Rotates back and forth by a tiny microscopic angle
        final double angle = (_controller.value * 0.05) - 0.025;
        return Transform.rotate(
          angle: angle,
          child: child,
        );
      },
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            margin: const EdgeInsets.only(right: 12),
            width: 56, 
            height: 56,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              image: DecorationImage(
                image: FileImage(File(widget.imagePath)),
                fit: BoxFit.cover, 
              ),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 4, offset: const Offset(0, 2))
              ]
            ),
          ),
          Positioned(
            top: -6, 
            right: 4,
            child: GestureDetector(
              onTap: widget.onDelete,
              child: Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5), // 🌟 THE FIX: Sleek translucent grey
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withOpacity(0.8), width: 1.5),
                ),
                child: const Icon(Icons.close, size: 10, color: Colors.white, weight: 900),
              )
            )
          )
        ]
      ),
    );
  }
}