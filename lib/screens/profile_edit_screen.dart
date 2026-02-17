import 'dart:io';
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
  File? _imageFile;

  String? _displayedPhotoUrl;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  String _selectedGender = 'X'; 
  
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
          _selectedGender = profile['gender'];
          _initialGender = profile['gender']; // 👈 Lock it in
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
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
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
    final picker = ImagePicker();
    // 🗜️ SHRINK: Force max dimensions to 400x400 and quality to 70
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery, 
      maxWidth: 400, 
      maxHeight: 400, 
      imageQuality: 70
    );
    if (pickedFile != null) setState(() => _imageFile = File(pickedFile.path));
  }

  Future<void> _saveProfile() async {
    setState(() => _isLoading = true);
    
    final String name = _nameController.text.toUpperCase();
    final int age = int.tryParse(_ageController.text) ?? 18;
    final String gender = _selectedGender;
    
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
    return _nameController.text != _initialName ||
           _ageController.text != _initialAge ||
           _selectedGender != _initialGender ||
           _imageFile != null; // 👈 Activates button if a new photo is picked
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
    if (_isLoading) {
      return const Center(
        child: SizedBox(
          width: 24, height: 24,
          child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.indigo),
        ),
      );
    }

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
                                    DropdownButtonFormField<String>(
                                      value: _selectedGender,
                                      style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 14, fontFamily: 'Roboto'),
                                      dropdownColor: Colors.white,
                                      decoration: InputDecoration(
                                        filled: true, fillColor: Colors.white,
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                                      ),
                                      items: const [
                                        DropdownMenuItem(value: 'M', child: Text("MALE", style: TextStyle(color: Colors.black))),
                                        DropdownMenuItem(value: 'F', child: Text("FEMALE", style: TextStyle(color: Colors.black))),
                                        DropdownMenuItem(value: 'X', child: Text("NEUTRAL", style: TextStyle(color: Colors.black))),
                                      ],
                                      onChanged: (val) => setState(() => _selectedGender = val!),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 30),
                          
                          SizedBox(
                            width: double.infinity, height: 45,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                // 👇 Dynamically change color
                                backgroundColor: _hasChanges ? Colors.indigo : Colors.grey[400], 
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))
                              ),
                              // 👇 Disable button if no changes or loading
                              onPressed: (!_hasChanges || _isLoading) ? null : _saveProfile,
                              child: _isLoading 
                                ? const CircularProgressIndicator(color: Colors.white) 
                                : const Text("SAVE RECORDS", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 40),

                    // --- REAL PASSPORTS LIST ---
                    const Text(
                      "EXISTING PASSPORTS",
                      style: TextStyle(color: Colors.white54, fontFamily: 'Courier', fontWeight: FontWeight.bold, letterSpacing: 1.5),
                    ),
                    const SizedBox(height: 16),
                    
                    if (_myPassports.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(20.0),
                        child: Center(child: Text("No passports found.", style: TextStyle(color: Colors.white30))),
                      )
                    else
                      ..._myPassports.map((book) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12.0),
                          child: _buildPassportTile(book),
                        );
                      }), 

                    const SizedBox(height: 40),

                    // --- LOG IN / LOG OUT ---
                    SizedBox(
                      width: double.infinity, 
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _handleAuthAction, 
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isGuest ? const Color(0xFF2E7D32) : const Color(0xFFD32F2F), 
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(isGuest ? Icons.login : Icons.logout, color: Colors.white, size: 20),
                            const SizedBox(width: 10),
                            Text(
                              isGuest ? "LOG IN / CREATE ACCOUNT" : "LOG OUT OF ACCOUNT", 
                              style: const TextStyle(
                                color: Colors.white, 
                                fontWeight: FontWeight.bold, 
                                letterSpacing: 1.2
                              )
                            ),
                          ],
                        ),
                      ),
                    ),

                    // 🗑️ APPLE COMPLIANCE: DELETE ACCOUNT
                    // Only visible if logged in.
                    if (!isGuest) ...[
                      const SizedBox(height: 20),
                      Center(
                        child: TextButton(
                          onPressed: _deleteAccount,
                          child: const Text(
                            "Delete Account", 
                            style: TextStyle(
                              color: Colors.white30, 
                              fontSize: 12, 
                              fontWeight: FontWeight.bold
                            )
                          ),
                        ),
                      ),
                    ],

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