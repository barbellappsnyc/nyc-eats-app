import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/passport_service.dart';
import '../widgets/animated_background.dart'; 
import 'passport_collection_screen.dart'; 
import 'auth_screen.dart'; 
import 'package:path_provider/path_provider.dart'; 
import '../screens/map_screen.dart'; // Adjust path if needed
import 'dart:ui'; // 👈 Essential for BackdropFilter blur
import 'package:flutter/services.dart'; // Just in case, keeping it safe
// ... rest of your existing imports ...

Future<bool?> openProfileScreen(BuildContext context, {
  String? name, String? photoUrl, String? gender, int? age
}) async {
  return await Navigator.of(context).push<bool?>(
    MaterialPageRoute(
      builder: (_) => ProfileScreen(
        currentName: name,
        currentPhotoUrl: photoUrl,
        currentGender: gender,
        currentAge: age,
      ),
    ),
  );
}

class ProfileScreen extends StatefulWidget {
  final String? currentName;
  final String? currentPhotoUrl;
  final String? currentGender;
  final int? currentAge;

  const ProfileScreen({
    super.key,
    this.currentName,
    this.currentPhotoUrl,
    this.currentGender,
    this.currentAge,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  
  late ScrollController _scrollController;
  Color _headerColor = Colors.white; 

  bool _isLoading = false;
  bool _isLoadingPassports = true; // 👈 Starts true so we don't flash "No passports"
  bool _isPickingImage = false;
  File? _imageFile;

  String? _displayedPhotoUrl;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  String _selectedGender = 'X'; 
  final TextEditingController _customGenderController = TextEditingController();
  bool _isEditingCustomGender = false;

  List<Map<String, dynamic>> _myPassports = [];

  // 👇 NEW: Track initial state
  String _initialName = '';
  String _initialAge = '';
  String _initialGender = 'X';

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);

    _nameController.text = widget.currentName ?? '';
    _ageController.text = widget.currentAge?.toString() ?? '';

    _displayedPhotoUrl = widget.currentPhotoUrl;

    if (widget.currentGender != null && widget.currentGender!.isNotEmpty) {
      _selectedGender = widget.currentGender!;
    }
    _handleInitialPhoto();

    _fetchRealProfile(); 
    _loadMyPassports();

    // 👇 NEW: Listen to text changes
    _nameController.addListener(() => setState(() {}));
    _ageController.addListener(() => setState(() {}));
    _customGenderController.addListener(() {
      setState(() {}); // Triggers the save button if changes exist
      final text = _customGenderController.text.trim().toLowerCase();
      if (text == 'male') {
        setState(() { _selectedGender = 'M'; _isEditingCustomGender = false; _customGenderController.clear(); FocusManager.instance.primaryFocus?.unfocus(); });
      } else if (text == 'female') {
        setState(() { _selectedGender = 'F'; _isEditingCustomGender = false; _customGenderController.clear(); FocusManager.instance.primaryFocus?.unfocus(); });
      }
    });
  }

  Future<void> _fetchRealProfile() async {
    final profile = await PassportService.fetchUserProfile(forceRefresh: true);
    
    if (profile != null && mounted) {
      setState(() {
        if (profile['display_name'] != null) {
          _nameController.text = profile['display_name'];
          _initialName = profile['display_name']; // 👈 Lock it in
        }
        if (profile['age'] != null) {
          _ageController.text = profile['age'].toString();
          _initialAge = profile['age'].toString(); // 👈 Lock it in
        }
        if (profile['gender'] != null) {
          final g = profile['gender'];
          if (g == 'M' || g == 'F') {
            _selectedGender = g;
          } else {
            _selectedGender = 'CUSTOM';
            _customGenderController.text = g;
          }
          _initialGender = g; // Lock it in for the "has changes" check
        }
        _displayedPhotoUrl = profile['photo_url']; 
      });
    }
  }

  void _handleInitialPhoto() {
    if (widget.currentPhotoUrl != null && widget.currentPhotoUrl!.isNotEmpty) {
      if (!widget.currentPhotoUrl!.startsWith('http')) {
        final localFile = File(widget.currentPhotoUrl!);
        if (localFile.existsSync()) {
          _imageFile = localFile;
        }
      }
    }
  }

  Future<void> _loadMyPassports() async {
    final books = await PassportService.fetchUserLibrary(forceRefresh: true);
    if (mounted) {
      setState(() {
        _myPassports = books;
        _isLoadingPassports = false; // 🛑 Turn off passport spinner
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _customGenderController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.offset > 40) {
      if (_headerColor != Colors.black) setState(() => _headerColor = Colors.black);
    } else {
      if (_headerColor != Colors.white) setState(() => _headerColor = Colors.white);
    }
  }

  Future<void> _pickImage() async {
    setState(() => _isPickingImage = true); // 🟢 Start image spinner
    
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery, 
        maxWidth: 400, 
        maxHeight: 400, 
        imageQuality: 70
      );
      if (pickedFile != null) {
        _imageFile = File(pickedFile.path);
      }
    } finally {
      if (mounted) setState(() => _isPickingImage = false); // 🛑 Stop image spinner
    }
  }

  Future<void> _saveProfile() async {
    setState(() => _isLoading = true);
    
    final String name = _nameController.text.toUpperCase();
    final int age = int.tryParse(_ageController.text) ?? 18;
    final String gender = _selectedGender == 'CUSTOM' 
        ? (_customGenderController.text.trim().isNotEmpty ? _customGenderController.text.trim() : 'X') 
        : _selectedGender;
    
    try {
      final user = Supabase.instance.client.auth.currentUser;
      
      String? localPathToSave;
      if (_imageFile != null) {
        final appDir = await getApplicationDocumentsDirectory();
        final fileName = 'guest_profile_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final savedImage = await _imageFile!.copy('${appDir.path}/$fileName');
        localPathToSave = savedImage.path; 
      }

      if (user == null) {
        // GUEST MODE
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('guest_name', name);
        await prefs.setInt('guest_age', age);
        await prefs.setString('guest_gender', gender);
        
        if (localPathToSave != null) {
           await prefs.setString('guest_photo_local_path', localPathToSave);
        }

        await PassportService.updateLocalProfile({
          'display_name': name, 
          'age': age, 
          'gender': gender, 
          'photo_url': localPathToSave 
        });

        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Profile Saved (Guest Mode)")));
           Navigator.pop(context, true);
        }
      } else {
        // 🔴 LOGGED IN MODE

        String? finalPhotoUrl = _displayedPhotoUrl; // Start with existing URL

        // 1. Upload Photo if a new one was picked
        if (_imageFile != null) {
           
           // 🗑️ THE ASSASSIN: Delete the old photo before uploading the new one
           if (_displayedPhotoUrl != null && _displayedPhotoUrl!.contains('avatars')) {
             try {
                final uri = Uri.parse(_displayedPhotoUrl!);
                final oldFileName = uri.pathSegments.last; 
                await Supabase.instance.client.storage.from('avatars').remove([oldFileName]);
                debugPrint("🗑️ Old avatar successfully deleted from bucket.");
             } catch (e) {
                debugPrint("⚠️ Could not delete old photo: $e");
             }
           }

           // 🚀 THE UPLOAD
           final fileExt = _imageFile!.path.split('.').last;
           // We keep the timestamp so the app's UI doesn't accidentally show a cached older image
           final fileName = '${user.id}_${DateTime.now().millisecondsSinceEpoch}.$fileExt';

           // A. Perform Upload
           await Supabase.instance.client.storage.from('avatars').upload(
             fileName,
             _imageFile!,
             fileOptions: const FileOptions(cacheControl: '3600', upsert: true),
           );

           // B. Get the Public URL
           finalPhotoUrl = Supabase.instance.client.storage.from('avatars').getPublicUrl(fileName);
        }

        // 2. Update DB with the data AND the URL
        await Supabase.instance.client.from('user_profiles').upsert(
          {
            'user_id': user.id,
            'display_name': name,
            'age': age,
            'gender': gender,
            'photo_url': finalPhotoUrl,
            'updated_at': DateTime.now().toIso8601String(),
          },
          onConflict: 'user_id', 
        );
        
        // 🛠 FIX: Pass the new photo URL to the local cache so MapScreen sees it!
        await PassportService.updateLocalProfile({
          'display_name': name, 
          'age': age, 
          'gender': gender, 
          'photo_url': finalPhotoUrl, // 👈 SAFELY IN SCOPE
        });

        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Profile Updated")));
           Navigator.pop(context, true);
        }
      }
    } catch (e) {
      debugPrint("Profile Save Error: $e");
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 👇 NEW: Returns true ONLY if something actually changed
  bool get _hasChanges {
    final currentGender = _selectedGender == 'CUSTOM' ? _customGenderController.text.trim() : _selectedGender;
    return _nameController.text != _initialName ||
           _ageController.text != _initialAge ||
           currentGender != _initialGender ||
           _imageFile != null; 
  }

  // 🗑️ APPLE COMPLIANCE: DELETE ACCOUNT
  Future<void> _deleteAccount() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFFFFFDF7),
        title: const Text("Delete Account?", style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text(
          "This will permanently delete your account, passports, and all collected stamps.\n\nThis action cannot be undone.",
          style: TextStyle(fontSize: 14, color: Colors.black87),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("CANCEL", style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("DELETE PERMANENTLY", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);

    try {
      final user = Supabase.instance.client.auth.currentUser;
      
      if (user != null) {
        // --- STEP 1: DELETE ALL PHOTOS FROM BUCKET (The Sweeper) ---
        try {
           // 1. Search the bucket for ANY file containing this user's ID
           final files = await Supabase.instance.client.storage
               .from('avatars')
               .list(searchOptions: SearchOptions(search: user.id));
           
           // 2. Extract the filenames
           final filesToDelete = files.map((f) => f.name).toList();
              
           // 3. Nuke them all at once
           if (filesToDelete.isNotEmpty) {
              await Supabase.instance.client.storage.from('avatars').remove(filesToDelete);
              debugPrint("🧹 Sweeper successfully deleted ${filesToDelete.length} files.");
           }
        } catch (e) {
           debugPrint("⚠️ Sweeper could not delete photos: $e");
        }

        // --- STEP 2: DELETE ACCOUNT & DATA (The Nuclear Option) ---
        // We call the secure SQL function that wipes everything (Profile, Books, Stamps, Login).
        try {
           await Supabase.instance.client.rpc('delete_own_account');
        } catch (e) {
           debugPrint("🔴 Critical Delete Error: $e");
           if (mounted) {
             setState(() => _isLoading = false);
             ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: Could not delete data. $e")));
             return; // Stop here if we couldn't wipe the data
           }
        }
        
        // --- STEP 3: SIGN OUT CLIENT ---
        // The session is likely invalid now anyway, but we clear it locally.
        await Supabase.instance.client.auth.signOut();
      }

      // --- STEP 4: WIPE LOCAL PREFS ---
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      if (mounted) {
        setState(() => _isLoading = false);
        Navigator.pop(context); // Close profile screen
        
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Account permanently deleted."),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 4),
          )
        );

        // Force Restart / Go to Map Screen (NOT Auth Screen)
        // This prevents the black screen bug because MapScreen doesn't have an empty back button!
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const MapScreen()), 
          (route) => false
        );
      }

    } catch (e) {
      debugPrint("Delete Loop Error: $e");
      if (mounted) setState(() => _isLoading = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error deleting account: $e")));
    }
  }

  Future<void> _handleAuthAction() async {
    final user = Supabase.instance.client.auth.currentUser;
    
    if (user == null) {
      // 🟢 GUEST -> LOG IN
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const AuthScreen(isRedirectingBack: true)),
      );

      if (mounted) {
        setState(() => _isLoading = true);
        await _fetchRealProfile(); 
        await _loadMyPassports();  
        setState(() => _isLoading = false);
      }

    } else {
      // 🔴 LOGGED IN -> SIGN OUT
      setState(() => _isLoading = true);
      try {
        await Supabase.instance.client.auth.signOut();
        
        if (mounted) {
           final prefs = await SharedPreferences.getInstance();
           await prefs.clear(); // Wipe everything

           // Reset UI
           _imageFile = null; 
           _displayedPhotoUrl = null; 
           _nameController.clear();
           _ageController.clear();
           _selectedGender = 'X';
           _myPassports = [];

           setState(() => _isLoading = false);
           
           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Logged out successfully.")));
        }
      } catch (e) {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildProfileImageContent() {
    // 👇 Now checks both general loading AND the specific image picking state
    if (_isLoading || _isPickingImage) {
      return const Center(
        child: CupertinoActivityIndicator(color: Colors.indigo, radius: 12),
      );
    }
    // ... rest of the function stays exactly the same

    if (_imageFile != null) {
      return Image.file(_imageFile!, fit: BoxFit.cover, errorBuilder: (ctx, err, stack) => const Icon(Icons.person, color: Colors.grey, size: 40));
    }

    if (_displayedPhotoUrl != null && _displayedPhotoUrl!.isNotEmpty) {
      final path = _displayedPhotoUrl!;
      if (!path.startsWith('http')) {
        return Image.file(File(path), fit: BoxFit.cover, errorBuilder: (ctx, err, stack) => const Icon(Icons.person, color: Colors.grey, size: 40));
      }
      return Image.network(path, fit: BoxFit.cover, errorBuilder: (ctx, err, stack) => const Icon(Icons.person, color: Colors.grey, size: 40));
    }
    return const Icon(Icons.add_a_photo, color: Colors.grey, size: 30);
  }

  @override
  Widget build(BuildContext context) {
    final isGuest = Supabase.instance.client.auth.currentUser == null;

    return Scaffold(
      backgroundColor: Colors.transparent, 
      body: Stack(
        children: [
          const Positioned.fill(
            child: AnimatedBackground(sku: 'profile'),
          ),

          Positioned.fill(
            child: SafeArea(
              bottom: false,
              child: SingleChildScrollView(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 80), 
                    
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFDFBF7), 
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 30, offset: const Offset(0, 10))
                        ],
                      ),
                      child: Column(
                        children: [
                           const Text(
                            "OFFICIAL DATA", 
                            style: TextStyle(fontFamily: 'Courier', fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black)
                          ),
                          const SizedBox(height: 20),
                          
                          GestureDetector(
                            onTap: _pickImage,
                            child: Container(
                              width: 100, height: 130,
                              clipBehavior: Clip.antiAlias,
                              decoration: BoxDecoration(
                                color: Colors.grey[200],
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey[400]!),
                              ),
                              child: _buildProfileImageContent(),
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text("Tap to update ID Photo", style: TextStyle(fontSize: 10, color: Colors.grey)),
                          const SizedBox(height: 24),
                          
                          _buildTextField("FULL NAME", _nameController),
                          const SizedBox(height: 16),
                          
                          // 🛠 FIX: Clean Row without any duplicated columns or unbounded Expanded widgets!
                          Row(
                            children: [
                              Expanded(child: _buildTextField("AGE", _ageController, isNumber: true)),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text("GENDER", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.2, color: Color(0xFF9E9E9E))),
                                    const SizedBox(height: 8),
                                    _isEditingCustomGender
                                      ? TextField(
                                          autofocus: true,
                                          controller: _customGenderController,
                                          textCapitalization: TextCapitalization.words,
                                          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 14, fontFamily: 'Roboto'),
                                          decoration: InputDecoration(
                                            filled: true, fillColor: Colors.white,
                                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                                            suffixIcon: IconButton(
                                              icon: const Icon(Icons.close, size: 16),
                                              onPressed: () => setState(() {
                                                _selectedGender = 'M';
                                                _isEditingCustomGender = false;
                                              }),
                                            ),
                                          ),
                                          // 👇 Snaps back to resting state when they hit "Done/Enter"
                                          onSubmitted: (_) => setState(() => _isEditingCustomGender = false),
                                        )
                                      : DropdownButtonFormField<String>(
                                          value: ['M', 'F'].contains(_selectedGender) ? _selectedGender : 'CUSTOM',
                                          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 14, fontFamily: 'Roboto'),
                                          dropdownColor: Colors.white,
                                          decoration: InputDecoration(
                                            filled: true, fillColor: Colors.white,
                                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                                          ),
                                          items: [
                                            const DropdownMenuItem(value: 'M', child: Text("MALE", style: TextStyle(color: Colors.black))),
                                            const DropdownMenuItem(value: 'F', child: Text("FEMALE", style: TextStyle(color: Colors.black))),
                                            DropdownMenuItem(
                                              value: 'CUSTOM', 
                                              // 👇 Dynamically shows their saved custom gender in the dropdown list!
                                              child: Text(
                                                (_selectedGender == 'CUSTOM' && _customGenderController.text.isNotEmpty)
                                                    ? _customGenderController.text.toUpperCase()
                                                    : "OTHER...", 
                                                style: const TextStyle(color: Colors.black)
                                              )
                                            ),
                                          ],
                                          onChanged: (val) {
                                            if (val == 'CUSTOM') {
                                              setState(() {
                                                _selectedGender = 'CUSTOM';
                                                _isEditingCustomGender = true; // 👈 Activates the keyboard
                                              });
                                            } else {
                                              setState(() {
                                                _selectedGender = val!;
                                                _isEditingCustomGender = false;
                                              });
                                            }
                                          },
                                        ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 30),
                          
                          // 🛡️ THE LIQUID GLASS "SAVE RECORDS" PILL
                          ClipRRect(
                            borderRadius: BorderRadius.circular(999), // 👈 FIX: Proper clipping widget
                            child: BackdropFilter(
                              // 🔮 Frosted blur effect over Layer 1
                              filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                width: double.infinity,
                                height: 48, // Slightly taller pill
                                decoration: BoxDecoration(
                                  // 🧴 Liquid Glass styling with conditional colors
                                  color: (!_hasChanges || _isLoading)
                                      ? Colors.grey.withOpacity(0.08) // Faint glass if disabled
                                      : Colors.indigo.withOpacity(0.12), // Subtle indigo glass if active
                                  borderRadius: BorderRadius.circular(999), // Stadium pill shape
                                  // ✨ The Shining Edge (shimmering border)
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.2), 
                                    width: 1.5,
                                  ),
                                  boxShadow: [
                                    BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, 5))
                                  ],
                                ),
                                child: TextButton(
                                  onPressed: (!_hasChanges || _isLoading) ? null : _saveProfile,
                                  style: TextButton.styleFrom(
                                    padding: EdgeInsets.zero, 
                                    foregroundColor: Colors.indigo,
                                  ),
                                  child: _isLoading 
                                    ? const CupertinoActivityIndicator(color: Colors.indigo, radius: 10) 
                                    : Text(
                                        "SAVE RECORDS", 
                                        style: TextStyle(
                                          color: (!_hasChanges || _isLoading) ? Colors.grey[500] : Colors.indigo,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 1.0
                                        )
                                      ),
                                ),
                              ),
                            ),
                          ),
                        ], // End Column children for Official Data
                      ),
                    ), // 👈 FIX: This was the missing bracket that closes the "Official Data" Container!

                    const SizedBox(height: 40),

                    // --- REAL PASSPORTS LIST ---
                    const Text(
                      "EXISTING PASSPORTS",
                      style: TextStyle(color: Colors.white54, fontFamily: 'Courier', fontWeight: FontWeight.bold, letterSpacing: 1.5),
                    ),
                    const SizedBox(height: 16),
                    
                    if (_isLoadingPassports)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 40),
                        child: Center(
                          child: CupertinoActivityIndicator(color: Colors.white54, radius: 14),
                        ),
                      )
                    else if (_myPassports.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(20.0),
                        child: Center(
                          child: Text("No passports found.", style: TextStyle(color: Colors.white30)),
                        ),
                      )
                    else
                      ..._myPassports.map((book) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12.0),
                          child: _buildPassportTile(book),
                        );
                      }),
                    const SizedBox(height: 40),

                    // --- AUTH & ACCOUNT MANAGEMENT PILLS ---
                    // Conditioning the visibility of the delete button based on guest status
                    isGuest
                        ? // A. JUST A FULL-WIDTH "LOG IN" PILL IF GUEST
                          _buildAuthPill(isGuest: true)
                        : // B. ROW OF TWO PILLS IF LOGGED IN (Perfect 50/50 split)
                          Row(
                            children: [
                              Expanded(flex: 1, child: _buildAuthPill(isGuest: false)),
                              const SizedBox(width: 12), // Slightly tighter gap to give text more breathing room
                              Expanded(flex: 1, child: _buildDeletePill()),
                            ],
                          ),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),

          // Header
          Positioned(
            top: 0, left: 0, right: 0,
            child: SafeArea(
              bottom: false,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                color: Colors.transparent, 
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    AnimatedTheme(
                      data: ThemeData(iconTheme: IconThemeData(color: _headerColor)),
                      duration: const Duration(milliseconds: 200),
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                    
                    AnimatedDefaultTextStyle(
                      style: TextStyle(
                        fontFamily: 'Courier', 
                        fontWeight: FontWeight.bold, 
                        fontSize: 20, 
                        letterSpacing: 2.5,
                        color: _headerColor, 
                      ),
                      duration: const Duration(milliseconds: 200),
                      child: const Text("PROFILE"),
                    ),
                    
                    const SizedBox(width: 48),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------
  // 🛠️ HELPER: BUILD AUTHENTICATION PILL (Glassmorphism)
  // ---------------------------------------------------------
  Widget _buildAuthPill({required bool isGuest}) {
    final bgColor = isGuest ? const Color(0xFF2E7D32) : const Color(0xFFD32F2F);
    const textColor = Colors.white; // 👈 Forced to white for both Log In and Log Out

    return ClipRRect(
      borderRadius: BorderRadius.circular(999), 
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
        child: Container(
          height: 48,
          decoration: BoxDecoration(
            // 🧴 Increased opacity to 0.85 for a rich, solid glass look
            color: bgColor.withOpacity(0.85),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: Colors.white.withOpacity(0.3), 
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 20, offset: const Offset(0, 5))
            ],
          ),
          child: TextButton(
            onPressed: _handleAuthAction, 
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              foregroundColor: textColor, 
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(isGuest ? Icons.login : Icons.logout, color: textColor, size: 18),
                const SizedBox(width: 8),
                FittedBox( 
                  child: Text(
                    isGuest ? "LOG IN / SIGN UP" : "LOG OUT", 
                    style: const TextStyle(
                      color: textColor, 
                      fontWeight: FontWeight.bold, 
                      letterSpacing: 0.8,
                      fontSize: 12,
                    )
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------
  // 🗑️ HELPER: BUILD DELETE ACCOUNT PILL (Glassmorphism)
  // ---------------------------------------------------------
  Widget _buildDeletePill() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999), 
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
        child: Container(
          height: 48,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.85), 
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: Colors.white.withOpacity(0.9), 
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 20, offset: const Offset(0, 5))
            ],
          ),
          child: TextButton(
            onPressed: _deleteAccount,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12), // Added inner padding
              foregroundColor: const Color(0xFFD32F2F), 
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                 Icon(Icons.delete_forever_outlined, color: Color(0xFFD32F2F), size: 16), // Slightly smaller icon
                 SizedBox(width: 4),
                 Flexible( 
                   // 🛠️ FIX: Forces the text to scale down on tiny screens instead of overflowing
                   child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        "DELETE ACCOUNT", 
                        style: TextStyle(
                          color: Color(0xFFD32F2F), 
                          fontWeight: FontWeight.bold, 
                          letterSpacing: 0.5, // Tighter letter spacing to fit the long word
                          fontSize: 12,
                        )
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

  Widget _buildTextField(String label, TextEditingController controller, {bool isNumber = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.2, color: Color(0xFF9E9E9E))),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: isNumber ? TextInputType.number : TextInputType.name,
          textCapitalization: TextCapitalization.characters,
          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 14),
          decoration: InputDecoration(
            filled: true, fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
          ),
        ),
      ],
    );
  }

  Widget _buildPassportTile(Map<String, dynamic> book) {
    String sku = book['sku_type'] ?? 'free_tier';
    String status = (book['status'] ?? 'active').toString().toUpperCase();
    String bookId = book['id'];

    String title;
    Color color;

    if (sku == 'diplomat_book') {
      title = "DIPLOMAT PASSPORT";
      color = Colors.indigoAccent;
    } else if (sku == 'standard_book') {
      title = "STANDARD PASSPORT";
      color = const Color(0xFF1B4D3E); 
    } else if (sku == 'single_page') {
      title = "SINGLE VISA";
      color = Colors.orangeAccent;
    } else {
      title = "TOURIST VISA (FREE)";
      color = Colors.blueGrey;
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3), 
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: ListTile(
        leading: Container(
          width: 40, height: 40,
          decoration: BoxDecoration(color: color.withOpacity(0.2), shape: BoxShape.circle),
          child: Icon(Icons.book, color: color, size: 20),
        ),
        title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
        subtitle: Text(status, style: TextStyle(color: Colors.white60, fontSize: 10, letterSpacing: 1.0)),
        trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white30, size: 14),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => PassportCollectionScreen(initialBookId: bookId),
            ),
          );
        },
      ),
    );
  }
}