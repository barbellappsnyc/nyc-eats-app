import 'dart:io';
import 'package:flutter/material.dart';
import 'package:nyc_eats/widgets/animated_background.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../screens/passport_collection_screen.dart';
import '../services/passport_service.dart';
import '../models/restaurant.dart'; // 👈 NEW IMPORT
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../services/revenuecat_service.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import 'package:flutter/cupertino.dart';

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
  final _confirmPasswordController = TextEditingController(); // 👈 NEW

  // 🆕 NEW CONTROLLERS FOR SIGN UP
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  String _selectedGender = 'X'; // Default

  final _customGenderController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _customGenderController.addListener(() {
      final text = _customGenderController.text.trim().toLowerCase();
      // 🪤 The Trap: Snap back to standard if they type Male/Female
      if (text == 'male') {
        setState(() { _selectedGender = 'M'; _customGenderController.clear(); FocusManager.instance.primaryFocus?.unfocus(); });
      } else if (text == 'female') {
        setState(() { _selectedGender = 'F'; _customGenderController.clear(); FocusManager.instance.primaryFocus?.unfocus(); });
      }
    });
  }

  bool _isLoading = false;
  bool _isLogin = true; // Toggle between Login and Sign Up

  // 👇 NEW: Track whether passwords are hidden
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _nameController.dispose();
    _ageController.dispose();
    _customGenderController.dispose();
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

    if (!_isLogin) {
      if (password != _confirmPasswordController.text.trim()) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Passwords do not match.')),
        );
        return;
      }
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
        response = await Supabase.instance.client.auth.signInWithPassword(
          email: email,
          password: password,
        );
      } else {
        final String name = _nameController.text.isNotEmpty ? _nameController.text.toUpperCase() : "TRAVELER";
        final int age = int.tryParse(_ageController.text) ?? 18;

        response = await Supabase.instance.client.auth.signUp(
          email: email,
          password: password,
          data: {
            'display_name': name,
            'age': age,
            'gender': _selectedGender == 'CUSTOM' 
                ? (_customGenderController.text.trim().isNotEmpty ? _customGenderController.text.trim() : 'X') 
                : _selectedGender,
            'full_name': name,
          },
        );
      }

      if (response.user != null) {
        // 🛑 NEW: TRIGGER THE SIGN UP OTP DIALOG
        if (response.session == null && !_isLogin) {
          if (mounted) {
            setState(() => _isLoading = false);
            _showSignUpOTPDialog(email); 
          }
          return; // Stop here until they verify the code
        }

        // 🟢 If we get past the waiting room, finalize the login!
        await _finalizeLogin(response.user!.id);
      }
    } on AuthException catch (e) {
      // 👇 FIX 3: Catch Auth errors specifically for plain English messages
      if (mounted) {
        String errorMsg = e.message;
        if (e.message.toLowerCase().contains('invalid credentials')) {
          errorMsg = "Incorrect email or password. Please try again.";
        }
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMsg), backgroundColor: Colors.red));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('An unexpected error occurred. Please try again.'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ---------------------------------------------------------
  // 🧹 NEW HELPER: Finalize Login & Navigate
  // ---------------------------------------------------------
  Future<void> _finalizeLogin(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('guest_stamps');

    await _syncLocalDataToCloud(userId);

    if (widget.purchasedSku != null) {
      await PassportService.createBook(userId: userId, sku: widget.purchasedSku!);
    }

    // 👇 NEW: Hunt for any crashed/missing purchases before letting them in!
    await RevenueCatService.catchZombiePurchases(userId);

    await PassportService.prewarmCache();

    if (mounted) {
      if (widget.isRedirectingBack && widget.purchasedSku == null) {
        Navigator.pop(context);
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => PassportCollectionScreen(
              initialBookId: (widget.purchasedSku != null) ? 'newly_created_book' : null,
              incomingRestaurant: widget.incomingRestaurant,
            ),
          ),
        );
      }
    }
  }

  // ---------------------------------------------------------
  // 🛑 NEW: Sign Up Verification OTP Dialog
  // ---------------------------------------------------------
  void _showSignUpOTPDialog(String email) {
    final otpController = TextEditingController();
    bool isDialogLoading = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final textColor = isDark ? Colors.white : Colors.black;

          return AlertDialog(
            backgroundColor: isDark ? const Color(0xFF2C2C2C) : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text("Verify Your Email", style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "We sent a 6-digit code to $email. Enter it below to activate your account.",
                  style: TextStyle(color: textColor.withOpacity(0.8), height: 1.4),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: otpController,
                  keyboardType: TextInputType.number,
                  style: TextStyle(color: textColor),
                  decoration: _inputDecoration("6-Digit Code", Icons.numbers),
                ),
                if (isDialogLoading) ...[
                  const SizedBox(height: 16),
                  const CircularProgressIndicator(),
                ]
              ],
            ),
            actions: [
              TextButton(
                onPressed: isDialogLoading ? null : () {
                  Navigator.pop(ctx);
                  setState(() => _isLogin = true); // Switch UI to login so they can verify later if they want
                },
                child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDark ? Colors.white : Colors.black,
                  foregroundColor: isDark ? Colors.black : Colors.white,
                ),
                onPressed: isDialogLoading ? null : () async {
                  final code = otpController.text.trim();
                  if (code.isEmpty) return;

                  setStateDialog(() => isDialogLoading = true);
                  try {
                    final response = await Supabase.instance.client.auth.verifyOTP(
                      email: email,
                      token: code,
                      type: OtpType.signup,
                    );
                    
                    if (context.mounted && response.user != null) {
                      Navigator.pop(ctx); // Close Dialog
                      setState(() => _isLoading = true); // Turn on main loading curtain
                      await _finalizeLogin(response.user!.id); // 🟢 Proceed to passports!
                    }
                  } on AuthException catch (e) {
                    setStateDialog(() => isDialogLoading = false);
                    String errorMsg = e.message;
                    if (e.message.toLowerCase().contains('expired') || e.message.toLowerCase().contains('invalid')) {
                      errorMsg = "The code you entered is incorrect or has expired.";
                    }
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMsg), backgroundColor: Colors.red));
                  } catch (e) {
                    setStateDialog(() => isDialogLoading = false);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("An unexpected error occurred."), backgroundColor: Colors.red));
                  }
                },
                child: const Text("Verify", style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
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

  void _showForgotPasswordDialog() {
    // 👇 FIX 2: Automatically grab the email if they already typed it!
    final initialEmail = _emailController.text.trim();
    final isValidEmail = initialEmail.contains('@') && initialEmail.contains('.');
    
    final resetEmailController = TextEditingController(text: isValidEmail ? initialEmail : '');
    final otpController = TextEditingController();
    final newPasswordController = TextEditingController();
    
    bool isCodeSent = false;
    bool isDialogLoading = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final textColor = isDark ? Colors.white : Colors.black;

          return AlertDialog(
            backgroundColor: isDark ? const Color(0xFF2C2C2C) : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text(
              isCodeSent ? "Enter Reset Code" : "Reset Password", 
              style: TextStyle(fontWeight: FontWeight.bold, color: textColor)
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!isCodeSent) ...[
                  Text(
                    "Enter your email address and we'll send you a secure 6-digit reset code.",
                    style: TextStyle(color: textColor.withOpacity(0.8), height: 1.4),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: resetEmailController,
                    keyboardType: TextInputType.emailAddress,
                    style: TextStyle(color: textColor),
                    decoration: _inputDecoration("Email", Icons.email_outlined),
                  ),
                ] else ...[
                  Text(
                    "Enter the 6-digit code sent to ${resetEmailController.text}",
                    style: TextStyle(color: textColor.withOpacity(0.8), height: 1.4),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: otpController,
                    keyboardType: TextInputType.number,
                    style: TextStyle(color: textColor),
                    decoration: _inputDecoration("6-Digit Code", Icons.numbers),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: newPasswordController,
                    obscureText: true,
                    style: TextStyle(color: textColor),
                    decoration: _inputDecoration("New Password", Icons.lock_reset),
                  ),
                ],
                if (isDialogLoading) ...[
                  const SizedBox(height: 16),
                  const CircularProgressIndicator(),
                ]
              ],
            ),
            actions: [
              TextButton(
                onPressed: isDialogLoading ? null : () => Navigator.pop(ctx),
                child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDark ? Colors.white : Colors.black,
                  foregroundColor: isDark ? Colors.black : Colors.white,
                ),
                onPressed: isDialogLoading ? null : () async {
                  if (!isCodeSent) {
                    final email = resetEmailController.text.trim();
                    if (email.isEmpty) return;
                    
                    setStateDialog(() => isDialogLoading = true);
                    try {
                      await Supabase.instance.client.auth.resetPasswordForEmail(email);
                      setStateDialog(() {
                        isCodeSent = true;
                        isDialogLoading = false;
                      });
                    } on AuthException catch (e) {
                      setStateDialog(() => isDialogLoading = false);
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message), backgroundColor: Colors.red));
                    } catch (e) {
                      setStateDialog(() => isDialogLoading = false);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("An unexpected error occurred."), backgroundColor: Colors.red));
                    }
                  } 
                  else {
                    final code = otpController.text.trim();
                    final newPass = newPasswordController.text.trim();
                    if (code.isEmpty || newPass.isEmpty) return;

                    setStateDialog(() => isDialogLoading = true);
                    try {
                      await Supabase.instance.client.auth.verifyOTP(
                        email: resetEmailController.text.trim(),
                        token: code,
                        type: OtpType.recovery,
                      );
                      
                      await Supabase.instance.client.auth.updateUser(
                        UserAttributes(password: newPass),
                      );
                      
                      if (context.mounted) {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Password updated successfully! You can now log in."), backgroundColor: Colors.green),
                        );
                      }
                    } on AuthException catch (e) {
                      // 👇 FIX 3: Plain English Errors for the Code verification!
                      setStateDialog(() => isDialogLoading = false);
                      String errorMsg = e.message;
                      if (e.message.toLowerCase().contains('expired') || e.message.toLowerCase().contains('invalid')) {
                        errorMsg = "The code you entered is incorrect or has expired.";
                      }
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMsg), backgroundColor: Colors.red));
                    } catch (e) {
                      setStateDialog(() => isDialogLoading = false);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("An unexpected error occurred."), backgroundColor: Colors.red));
                    }
                  }
                },
                child: Text(isCodeSent ? "Update Password" : "Send Code", style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  // 🍽️ Layer 2: Static Grid of Food Emojis
  Widget _buildEmojiGrid() {
    final List<String> foodEmojis = [
      '🍕', '🍔', '🍟', '🌭', '🍿', '🥞', '🧇', '🥓', '🥩', '🍗', '🍖', '🌮',
      '🌯', '🥙', '🧆', '🥘', '🍲', '🍝', '🍜', '🍦', '🍧', '🍨', '🍩', '🍪', 
      '🎂', '🍰', '🧁', '🥧', '🍫', '🍬', '🍭', '🍡', '🍢', '🍣', '🍤', '🍥',
    ];

    return IgnorePointer( 
      // Allows vertical bleeding
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(), 
        child: Column(
          children: List.generate(
            (MediaQuery.of(context).size.height / 50).ceil(), 
            (rowIndex) => Opacity(
              opacity: 0.40, // 👈 Pushed opacity up to 40%
              // Allows horizontal bleeding off the right side
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const NeverScrollableScrollPhysics(),
                child: Row(
                  children: List.generate(
                    12, 
                    (colIndex) {
                      final emoji = foodEmojis[(rowIndex + colIndex) % foodEmojis.length];
                      return Padding(
                        padding: const EdgeInsets.all(16.0), // Slightly more spacing for bigger emojis
                        child: Text(
                          emoji, 
                          style: const TextStyle(fontSize: 36) // 👈 Increased size from 22 to 36!
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const Color navyBlue = Color(0xFF1A237E);
    const Color passportRed = Color(0xFFD32F2F);
    final Color hintColor = Colors.grey[600]!;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: Colors.transparent, // 👈 CHANGED: Let the layers show through!
        body: Stack(
          fit: StackFit.expand,
          children: [
            // 🚦 LAYER 1: Plum Red & White Moving Gradient
            const Positioned.fill(
              child: AnimatedBackground(sku: 'auth'),
            ),

            // 🍽️ LAYER 2: The Static Emoji Grid
            Positioned.fill(
              child: _buildEmojiGrid(),
            ),

            // 📝 LAYER 3: The Scrolling Liquid Glass Form
            SingleChildScrollView(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 60,
                left: 24, // Slightly reduced padding to give the card breathing room
                right: 24,
                bottom: 24,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 16.0, sigmaY: 16.0), // 🔮 Glassmorphism Blur
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.45), // 🧴 Translucent frosted glass
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.white.withOpacity(0.6), width: 1.5), // Shiny edge
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 30, offset: const Offset(0, 10))
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // 🛡️ OFFICIAL CREST
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: navyBlue, width: 3),
                          ),
                          child: const Center(
                            child: Icon(Icons.public, size: 50, color: navyBlue),
                          ),
                        ),
                        const SizedBox(height: 24),
                        
                        // 🔤 WARMER HEADERS
                        Text(
                          _isLogin ? 'WELCOME BACK' : 'GRAB YOUR PASSPORT',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontFamily: 'Courier',
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            color: navyBlue,
                            letterSpacing: 1.0,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _isLogin
                              ? 'LOG IN TO CONTINUE YOUR JOURNEY.'
                              : 'LET\'S GET YOU READY TO EXPLORE NYC.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Courier', 
                            color: hintColor, 
                            fontSize: 12, 
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5
                          ),
                        ),
                        const SizedBox(height: 40),

                        // 📝 FORM FIELDS
                        TextField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
                          decoration: _inputDecoration("EMAIL ADDRESS", Icons.email_outlined),
                        ),
                        const SizedBox(height: 16),

                        TextField(
                          controller: _passwordController,
                          obscureText: _obscurePassword, 
                          style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
                          decoration: _inputDecoration(
                            "PASSWORD",
                            Icons.key_outlined,
                          ).copyWith(
                            suffixIcon: IconButton(
                              splashRadius: 20, 
                              icon: Icon(
                                _obscurePassword ? PhosphorIconsRegular.eyeClosed : PhosphorIconsRegular.eye,      
                                color: hintColor.withOpacity(0.7), 
                                size: 22, 
                              ),
                              onPressed: () => setState(() => _obscurePassword = !_obscurePassword), 
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),

                        // 👇 Forgot Password Button
                        if (_isLogin)
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: _showForgotPasswordDialog,
                              child: Text("FORGOT PASSWORD?", style: TextStyle(color: hintColor, fontWeight: FontWeight.bold, fontFamily: 'Courier')),
                            ),
                          ),

                        if (!_isLogin) const SizedBox(height: 16),

                        // 👇 SIGN UP FIELDS
                        if (!_isLogin) ...[
                          TextField(
                            controller: _confirmPasswordController,
                            obscureText: _obscureConfirmPassword, 
                            style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
                            decoration: _inputDecoration(
                              "CONFIRM PASSWORD",
                              Icons.lock_reset_outlined,
                            ).copyWith(
                              suffixIcon: IconButton(
                                splashRadius: 20, 
                                icon: Icon(
                                  _obscureConfirmPassword ? PhosphorIconsRegular.eyeClosed : PhosphorIconsRegular.eye,      
                                  color: hintColor.withOpacity(0.7), 
                                  size: 22, 
                                ),
                                onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword), 
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          TextField(
                            controller: _nameController,
                            textCapitalization: TextCapitalization.characters,
                            style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
                            decoration: _inputDecoration(
                              "WHAT SHOULD WE CALL YOU?",
                              Icons.badge_outlined,
                            ),
                          ),
                          const SizedBox(height: 16),

                          Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: TextField(
                                  controller: _ageController,
                                  keyboardType: TextInputType.number,
                                  style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
                                  decoration: _inputDecoration("AGE", Icons.cake_outlined),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 4,
                                child: _selectedGender == 'CUSTOM'
                                  ? TextField(
                                      autofocus: true, 
                                      controller: _customGenderController,
                                      textCapitalization: TextCapitalization.characters,
                                      style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 14),
                                      decoration: _inputDecoration("CUSTOM GENDER", Icons.wc_outlined).copyWith(
                                        suffixIcon: IconButton(
                                          icon: const Icon(Icons.close, size: 16),
                                          onPressed: () => setState(() => _selectedGender = 'M'), 
                                        ),
                                      ),
                                    )
                                  : DropdownButtonFormField<String>(
                                      isExpanded: true, 
                                      value: ['M', 'F'].contains(_selectedGender) ? _selectedGender : 'CUSTOM',
                                      dropdownColor: const Color(0xFFFDFBF7),
                                      style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 14),
                                      decoration: _inputDecoration("GENDER", Icons.wc_outlined),
                                      items: const [
                                        DropdownMenuItem(value: 'M', child: Text("MALE")),
                                        DropdownMenuItem(value: 'F', child: Text("FEMALE")),
                                        DropdownMenuItem(value: 'CUSTOM', child: Text("CUSTOM...")),
                                      ],
                                      onChanged: (val) => setState(() => _selectedGender = val!),
                                    ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                        ],

                        const SizedBox(height: 20),

                        // 🛑 MAIN ACTION BUTTON
                        SizedBox(
                          height: 56,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _authenticate,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: passportRed, 
                              foregroundColor: Colors.white,
                              elevation: 8,
                              shadowColor: passportRed.withOpacity(0.5),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: Text(
                              _isLogin ? 'START EXPLORING' : 'CREATE PASSPORT',
                              style: const TextStyle(
                                fontFamily: 'Courier',
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),

                        // 🔄 TOGGLE LINK
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _isLogin ? "NEW TO NYC EATS? " : "ALREADY HAVE A PASSPORT? ",
                              style: const TextStyle(color: Colors.black54, fontFamily: 'Courier', fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                            GestureDetector(
                              onTap: () => setState(() => _isLogin = !_isLogin),
                              child: Text(
                                _isLogin ? "SIGN UP" : "LOG IN",
                                style: const TextStyle(
                                  color: navyBlue,
                                  fontFamily: 'Courier',
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // ✖️ LAYER 4: The Fixed Frosted Apple-Style Close Button
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              left: 20,
              child: ClipOval(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.5), 
                      border: Border.all(color: Colors.white.withOpacity(0.8)), 
                    ),
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      icon: const Icon(Icons.close, color: navyBlue, size: 24),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                ),
              ),
            ),

            // 🛡️ LAYER 5: THE LOADING CURTAIN
            if (_isLoading)
              Container(
                color: navyBlue.withOpacity(0.9), 
                child: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CupertinoActivityIndicator(color: Colors.white, radius: 16),
                      SizedBox(height: 24),
                      Text(
                        "ISSUING PASSPORT...",
                        style: TextStyle(
                          fontFamily: 'Courier',
                          color: Colors.white,
                          fontSize: 16,
                          letterSpacing: 2.0,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // 📐 INPUT DECORATION HELPER
  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(fontFamily: 'Courier', color: Colors.black54, fontWeight: FontWeight.bold, letterSpacing: 0.5),
      prefixIcon: Icon(icon, color: const Color(0xFF1A237E).withOpacity(0.7)),
      filled: true,
      fillColor: Colors.black.withOpacity(0.02), // 👈 Restored to a subtle, solid grey tint
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.black.withOpacity(0.1), width: 2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFF1A237E), width: 2), 
      ),
    );
  }
}