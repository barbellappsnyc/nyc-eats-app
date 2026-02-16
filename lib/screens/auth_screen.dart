import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../screens/passport_collection_screen.dart';
import '../services/passport_service.dart';
import '../models/restaurant.dart'; // 👈 NEW IMPORT

class AuthScreen extends StatefulWidget {
  final String? purchasedSku;
  // 👇 Flag to determine navigation behavior
  final bool isRedirectingBack;
  final Restaurant? incomingRestaurant; // 👈 NEW: Holding the baton

  const AuthScreen({
    super.key,
    this.purchasedSku,
    this.isRedirectingBack = false, // Default to false (Old behavior)
    this.incomingRestaurant, // 👈 NEW: Holding the baton
  });

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  // 🆕 NEW CONTROLLERS FOR SIGN UP
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  String _selectedGender = 'X'; // Default

  bool _isLoading = false;
  bool _isLogin = true; // Toggle between Login and Sign Up

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  Future<void> _authenticate() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter email and password.')),
      );
      return;
    }

    // 🛑 VALIDATE SIGN UP FIELDS
    if (!_isLogin) {
      if (_nameController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter your name.')),
        );
        return;
      }
    }

    setState(() => _isLoading = true);

    try {
      AuthResponse response;

      if (_isLogin) {
        // 🔑 LOG IN
        response = await Supabase.instance.client.auth.signInWithPassword(
          email: email,
          password: password,
        );
      } else {
        // 📝 SIGN UP (With Data Payload)
        // We pass the meta_data so the SQL Trigger can grab it immediately
        final String name =
            _nameController.text.isNotEmpty
                ? _nameController.text.toUpperCase()
                : "TRAVELER";
        final int age = int.tryParse(_ageController.text) ?? 18;

        response = await Supabase.instance.client.auth.signUp(
          email: email,
          password: password,
          data: {
            'display_name': name,
            'age': age,
            'gender': _selectedGender,
            'full_name': name, // Redundant fallback for some triggers
          },
        );
      }

      if (response.user != null) {
        final userId = response.user!.id;

        // ---------------------------------------------------------
        // 🧹 FRESH START STRATEGY
        // ---------------------------------------------------------

        // 1. Wipe Local Guest Stamps
        // We delete the local stamps so the user starts fresh on their official account.
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('guest_stamps');

        // 2. Sync Profile Data (Guest -> Cloud)
        // If they were a Guest before, we try to sync that data over.
        // (Note: The SQL Trigger handles the *creation*, this handles *updates* from guest session)
        await _syncLocalDataToCloud(userId);

        // 3. Handle the Purchase (if any)
        if (widget.purchasedSku != null) {
          // They bought a specific book, so create THAT one.
          // (The Trigger already created a Free Tier one, but that's fine, they can have both)
          await PassportService.createBook(
            userId: userId,
            sku: widget.purchasedSku!,
          );
        } else {
          // Normal Login/Signup:
          // The SQL Trigger has ALREADY created the Free Tier book.
          // We don't need to do anything here except load it.
        }

        // 4. Refresh Cache so the new book appears immediately
        await PassportService.prewarmCache();

        if (mounted) {
          // 🚦 NAVIGATION LOGIC
          // If we came from Profile (and didn't just buy a book), just go back.
          if (widget.isRedirectingBack && widget.purchasedSku == null) {
            Navigator.pop(context);
          }
          // Otherwise (Shop or Default), go to the Collection Screen
          else {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder:
                    (context) => PassportCollectionScreen(
                      initialBookId:
                          (widget.purchasedSku != null)
                              ? 'newly_created_book'
                              : null,
                              incomingRestaurant: widget.incomingRestaurant, // 👈 PASS THE BATON!
                    ),
              ),
            );
          }
        }
      }
    } on AuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      debugPrint("🔴 CRITICAL AUTH ERROR: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ☁️ THE SYNC FUNCTION (Guest -> Cloud Merge)
  Future<void> _syncLocalDataToCloud(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final String? guestName = prefs.getString('guest_name');

    // Only sync if we actually have guest data AND we are Logging In (not Signing Up)
    // If Signing Up, the Form Data takes precedence.
    if (guestName != null && _isLogin) {
      final int age = prefs.getInt('guest_age') ?? 18;
      final String gender = prefs.getString('guest_gender') ?? 'X';
      final String? localPhotoPath = prefs.getString('guest_photo_local_path');
      String? uploadedPhotoUrl;

      // 1. Try uploading local photo if exists
      if (localPhotoPath != null) {
        try {
          final file = File(localPhotoPath);
          if (await file.exists()) {
            final fileExt = localPhotoPath.split('.').last;
            final fileName =
                '$userId-sync-${DateTime.now().millisecondsSinceEpoch}.$fileExt';
            // Note: Requires Storage Bucket 'avatars' to exist
            await Supabase.instance.client.storage
                .from('avatars')
                .upload(fileName, file);
            uploadedPhotoUrl = Supabase.instance.client.storage
                .from('avatars')
                .getPublicUrl(fileName);
          }
        } catch (e) {
          debugPrint("Photo Sync Failed (Bucket might be missing): $e");
        }
      }

      // 2. Build the update map
      final Map<String, dynamic> updates = {
        'user_id': userId,
        'display_name': guestName,
        'age': age,
        'gender': gender,
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (uploadedPhotoUrl != null) {
        updates['photo_url'] = uploadedPhotoUrl;
      }

      // 3. Perform the safe update
      await Supabase.instance.client.from('user_profiles').upsert(
        updates,
        onConflict: 'user_id',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // 🎨 Theme Colors
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDarkMode ? Colors.white : Colors.black;
    final hintColor = Colors.grey[600];

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          // 1. The Main Form
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(Icons.lock_outline, size: 60, color: textColor),
                  const SizedBox(height: 20),
                  Text(
                    _isLogin ? 'Welcome Back' : 'Create Account',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isLogin
                        ? 'Log in to access your Passport.'
                        : 'Join the club. Start collecting.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: hintColor, fontSize: 16),
                  ),
                  const SizedBox(height: 40),

                  // 📝 FORM FIELDS
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    style: TextStyle(color: textColor),
                    decoration: _inputDecoration("Email", Icons.email_outlined),
                  ),
                  const SizedBox(height: 16),

                  TextField(
                    controller: _passwordController,
                    obscureText: true,
                    style: TextStyle(color: textColor),
                    decoration: _inputDecoration(
                      "Password",
                      Icons.key_outlined,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 👇 NEW SIGN UP FIELDS (Hidden during Login)
                  if (!_isLogin) ...[
                    TextField(
                      controller: _nameController,
                      textCapitalization: TextCapitalization.characters,
                      style: TextStyle(color: textColor),
                      decoration: _inputDecoration(
                        "Full Name (for ID)",
                        Icons.badge_outlined,
                      ),
                    ),
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _ageController,
                            keyboardType: TextInputType.number,
                            style: TextStyle(color: textColor),
                            decoration: _inputDecoration(
                              "Age",
                              Icons.cake_outlined,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _selectedGender,
                            dropdownColor: isDarkMode ? Colors.grey[800] : Colors.white,
                            style: TextStyle(color: textColor, fontSize: 16),
                            decoration: _inputDecoration(
                              "Gender",
                              Icons.wc_outlined,
                            ),
                            items: const [
                              DropdownMenuItem(value: 'M', child: Text("Male")),
                              DropdownMenuItem(value: 'F', child: Text("Female")),
                              DropdownMenuItem(value: 'X', child: Text("Neutral")),
                            ],
                            onChanged: (val) => setState(() => _selectedGender = val!),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],

                  const SizedBox(height: 20),

                  // ACTION BUTTON
                  SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _authenticate,
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            isDarkMode ? Colors.white : Colors.black,
                        foregroundColor:
                            isDarkMode ? Colors.black : Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        _isLogin ? 'Log In' : 'Sign Up & Create Passport',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // TOGGLE LINK
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _isLogin
                            ? "Don't have an account? "
                            : "Already have an account? ",
                        style: TextStyle(color: textColor),
                      ),
                      GestureDetector(
                        onTap: () => setState(() => _isLogin = !_isLogin),
                        child: Text(
                          _isLogin ? "Sign Up" : "Log In",
                          style: const TextStyle(
                            color: Colors.blue,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),

          // 2. 🛡️ THE LOADING CURTAIN
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.7),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 20),
                    Text(
                      "Issuing Passport...",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  // Helper for cleaner code
  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: Colors.grey[600]),
      prefixIcon: Icon(icon, color: Colors.grey),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey[400]!),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.blue, width: 2),
      ),
    );
  }
}