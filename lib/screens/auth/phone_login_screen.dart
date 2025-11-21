import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'dart:async';

class PhoneLoginScreen extends StatefulWidget {
  const PhoneLoginScreen({super.key});

  @override
  State<PhoneLoginScreen> createState() => _PhoneLoginScreenState();
}

class _PhoneLoginScreenState extends State<PhoneLoginScreen>
    with SingleTickerProviderStateMixin {
  // Logic Variables
  String _phoneNumber = "";
  bool _isLoading = false;
  StreamSubscription? _gyroStream;

  // Animation Variables
  double _offsetX = 0;
  double _offsetY = 0;
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    // 1. Setup Parallax Background
    // We throttle the updates slightly or just clamp them to ensure smooth 60fps
    _gyroStream = gyroscopeEvents.listen((GyroscopeEvent e) {
      if (mounted) {
        setState(() {
          // Multiplier reduced slightly for a subtler, more premium feel
          _offsetX = (e.y * 5).clamp(-15.0, 15.0);
          _offsetY = (e.x * 5).clamp(-15.0, 15.0);
        });
      }
    });

    // 2. Setup Entrance Animation
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutQuart,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: const Interval(0.2, 1.0, curve: Curves.easeOut),
    ));

    _animController.forward();
  }

  @override
  void dispose() {
    _gyroStream?.cancel();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (_phoneNumber.isEmpty || _phoneNumber.length < 4) {
      _showSnackBar("Please enter a valid phone number", isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: _phoneNumber,
        verificationCompleted: (_) {
          setState(() => _isLoading = false);
        },
        verificationFailed: (FirebaseAuthException e) {
          setState(() => _isLoading = false);
          _showSnackBar(e.message ?? "Verification failed", isError: true);
        },
        codeSent: (String verificationId, int? resendToken) {
          setState(() => _isLoading = false);
          Navigator.pushNamed(
            context,
            "/otp",
            arguments: verificationId,
          );
        },
        codeAutoRetrievalTimeout: (_) {
          if (mounted) setState(() => _isLoading = false);
        },
      );
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar("An unexpected error occurred.", isError: true);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.redAccent.withOpacity(0.8) : Colors.green,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Using LayoutBuilder to ensure responsiveness on all screen sizes
    return Scaffold(
      extendBody: true,
      resizeToAvoidBottomInset: false, // Prevents background squishing
      body: Stack(
        children: [
          // -------------------------------------------
          // LAYER 1: Parallax Background
          // -------------------------------------------
          Positioned.fill(
            child: Transform.translate(
              offset: Offset(_offsetX, _offsetY),
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.black, // Fallback color
                  image: DecorationImage(
                    image: AssetImage("assets/images/turf_bg.png"),
                    fit: BoxFit.cover,
                    opacity: 0.8, // Slightly darkened for text readability
                  ),
                ),
              ),
            ),
          ),

          // -------------------------------------------
          // LAYER 2: Main Content
          // -------------------------------------------
          Center(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: _buildGlassPanel(context),
                ),
              ),
            ),
          ),

          // -------------------------------------------
          // LAYER 3: Back Button (Floating safely)
          // -------------------------------------------
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 16,
            child: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassPanel(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxWidth: 400),
          padding: const EdgeInsets.fromLTRB(24, 40, 24, 32),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: Colors.white.withOpacity(0.2),
              width: 1.5,
            ),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(0.2),
                Colors.white.withOpacity(0.05),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min, // Dynamic height
            children: [
              // Title
              Text(
                "Welcome Back",
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white.withOpacity(0.95),
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Enter your phone number to continue",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withOpacity(0.7),
                ),
              ),
              const SizedBox(height: 32),

              // Input Field
              _buildGlassInput(),

              const SizedBox(height: 24),

              // Action Button
              _buildGlassButton(
                text: "Get OTP",
                onTap: _handleLogin,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGlassInput() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.15)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: IntlPhoneField(
        initialCountryCode: 'IN',
        dropdownIcon: const Icon(Icons.keyboard_arrow_down, color: Colors.white70),
        dropdownTextStyle: const TextStyle(color: Colors.white, fontSize: 16),
        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
        cursorColor: Colors.white,
        decoration: const InputDecoration(
          hintText: "Phone Number",
          hintStyle: TextStyle(color: Colors.white38),
          border: InputBorder.none,
          counterText: "", // Hides the character counter
          contentPadding: EdgeInsets.symmetric(vertical: 14),
        ),
        onChanged: (phone) {
          _phoneNumber = phone.completeNumber;
        },
      ),
    );
  }

  Widget _buildGlassButton({required String text, required VoidCallback onTap}) {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: [
            const Color(0xFF4CAF50).withOpacity(0.8), // Turf Green
            const Color(0xFF2E7D32).withOpacity(0.8),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4CAF50).withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _isLoading ? null : onTap,
          borderRadius: BorderRadius.circular(16),
          child: Center(
            child: _isLoading
                ? const SizedBox(
              height: 24,
              width: 24,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2.5,
              ),
            )
                : Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
          ),
        ),
      ),
    );
  }
}