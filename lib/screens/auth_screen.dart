import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../screens/passport_collection_screen.dart';
import '../services/passport_service.dart';
import '../models/restaurant.dart'; // 👈 NEW IMPORT
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../services/revenuecat_service.dart';

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
            'gender': _selectedGender,
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
                    obscureText: _obscurePassword, // 👈 Spot 1
                    style: TextStyle(color: textColor),
                    decoration: _inputDecoration(
                      "Password",
                      Icons.key_outlined,
                    ).copyWith(
                      suffixIcon: IconButton(
                        splashRadius: 20, 
                        icon: Icon(
                          _obscurePassword // 👈 Spot 2
                              ? PhosphorIconsRegular.eyeClosed 
                              : PhosphorIconsRegular.eye,      
                          color: hintColor!.withOpacity(0.7), 
                          size: 22, 
                        ),
                        onPressed: () => setState(() => _obscurePassword = !_obscurePassword), // 👈 Spot 3
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),

                  // 👇 Forgot Password Button (Only visible on Login)
                  if (_isLogin)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _showForgotPasswordDialog,
                        child: Text("Forgot Password?", style: TextStyle(color: hintColor, fontWeight: FontWeight.bold)),
                      ),
                    ),

                  if (!_isLogin) const SizedBox(height: 16),

                  // 👇 SIGN UP FIELDS (Hidden during Login)
                  if (!_isLogin) ...[
                    TextField(
                      controller: _confirmPasswordController,
                      obscureText: _obscureConfirmPassword, // 👈 Spot 1
                      style: TextStyle(color: textColor),
                      decoration: _inputDecoration(
                        "Confirm Password",
                        Icons.lock_reset_outlined,
                      ).copyWith(
                        suffixIcon: IconButton(
                          splashRadius: 20, 
                          icon: Icon(
                            _obscureConfirmPassword // 👈 Spot 2
                                ? PhosphorIconsRegular.eyeClosed 
                                : PhosphorIconsRegular.eye,      
                            color: hintColor!.withOpacity(0.7), 
                            size: 22, 
                          ),
                          onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword), // 👈 Spot 3
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

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