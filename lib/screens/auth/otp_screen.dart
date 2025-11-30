import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:lottie/lottie.dart'; // Import Lottie
import 'dart:async';

class OtpScreen extends StatefulWidget {
  final String verificationId;
  const OtpScreen({super.key, required this.verificationId});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> with TickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();

  // Logic & Animation States
  bool _isLoading = false;          // Controls Background Zoom
  bool _showLoadingOverlay = false; // Controls Lottie Visibility
  bool _isAnimatingOut = false;     // Controls Card Slide Down

  // Animation Controllers
  late AnimationController _entranceController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late AnimationController _lottieController; // Lottie Controller

  @override
  void initState() {
    super.initState();
    _preCacheAssets();

    // 1. Initialize Lottie Controller
    _lottieController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );

    // 2. Entrance Animation setup
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOutQuart,
    ));

    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.2, 1.0, curve: Curves.easeOut),
    ));

    _entranceController.forward();
  }

  void _preCacheAssets() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      precacheImage(const AssetImage("assets/images/turf_bg.png"), context);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _entranceController.dispose();
    _lottieController.dispose();
    super.dispose();
  }

  // ------------------------------------
  // LOGIC
  // ------------------------------------

  Future<void> _verifyOtp() async {
    final sms = _controller.text.trim();
    if (sms.length < 6) {
      _showSnack("Please enter a valid 6-digit OTP", isError: true);
      return;
    }

    // 1. Start Background Zoom AND Slide Card Out
    setState(() {
      _isLoading = true;
      _isAnimatingOut = true;
    });

    // 2. Wait for Slide to finish (600ms)
    await Future.delayed(const Duration(milliseconds: 600));

    if (!mounted) return;

    // 3. Show Lottie Overlay & Start Animation
    setState(() => _showLoadingOverlay = true);
    _lottieController.reset();
    final animationFuture = _lottieController.forward();

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: widget.verificationId,
        smsCode: sms,
      );

      await FirebaseAuth.instance.signInWithCredential(credential);

      if (!mounted) return;

      // 4. Wait for animation to finish before navigating
      await animationFuture;

      Navigator.pushReplacementNamed(context, "/home");

    } on FirebaseAuthException catch (e) {
      _resetUI();
      _showSnack(e.message ?? "Verification failed", isError: true);
    } catch (e) {
      _resetUI();
      _showSnack("An error occurred", isError: true);
    }
  }

  void _resetUI() {
    if (!mounted) return;
    _lottieController.stop();
    _lottieController.reset();
    setState(() {
      _isLoading = false;
      _showLoadingOverlay = false;
      _isAnimatingOut = false; // Reset slide
    });
  }

  void _showSnack(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.redAccent : Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ------------------------------------
  // UI BUILD
  // ------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      resizeToAvoidBottomInset: false,
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // -------------------------------------------
          // 1. BACKGROUND (Zoom Effect)
          // -------------------------------------------
          Positioned.fill(
            child: AnimatedScale(
              scale: _isLoading ? 1.1 : 1.0, // Zoom to 1.1 like login screen
              duration: const Duration(milliseconds: 1500),
              curve: Curves.easeInOut,
              child: Container(
                decoration: const BoxDecoration(
                  image: DecorationImage(
                    image: AssetImage("assets/images/turf_bg.png"),
                    fit: BoxFit.cover,
                    opacity: 0.8,
                  ),
                ),
              ),
            ),
          ),

          // -------------------------------------------
          // 2. GLASS CARD
          // -------------------------------------------
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: AnimatedSlide(
                    offset: _isAnimatingOut ? const Offset(0, 2.0) : Offset.zero,
                    duration: const Duration(milliseconds: 600),
                    curve: Curves.easeInOutCubic,
                    child: _buildGlassPanel(context),
                  ),
                ),
              ),
            ),
          ),

          // -------------------------------------------
          // 3. BACK BUTTON
          // -------------------------------------------
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 16,
            child: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),

          // -------------------------------------------
          // 4. LOTTIE LOADING OVERLAY
          // -------------------------------------------
          Positioned.fill(
            child: IgnorePointer(
              ignoring: !_showLoadingOverlay,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 600),
                opacity: _showLoadingOverlay ? 1.0 : 0.0,
                curve: Curves.easeInOut,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                  ),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                    child: Center(
                      child: Lottie.asset(
                        "assets/lottie/login_loading.json",
                        controller: _lottieController,
                        frameRate: FrameRate.max,
                        width: 280,
                        height: 280,
                        fit: BoxFit.contain,
                        repeat: false,
                        onLoaded: (composition) {
                          _lottieController.duration = composition.duration;
                        },
                      ),
                    ),
                  ),
                ),
              ),
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
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxWidth: 400),
          padding: const EdgeInsets.fromLTRB(24, 40, 24, 32),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: Colors.white.withOpacity(0.15), width: 1.5),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Verification",
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white.withOpacity(0.95),
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Enter the 6-digit code sent to you",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withOpacity(0.7),
                ),
              ),
              const SizedBox(height: 32),

              // OTP INPUT
              _buildGlassInput(),

              const SizedBox(height: 24),

              // BOUNCY BUTTON
              BouncyButton(
                onTap: _verifyOtp,
                child: Container(
                  width: double.infinity,
                  height: 56,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF4CAF50).withOpacity(0.9),
                        const Color(0xFF2E7D32).withOpacity(0.9),
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
                  child: const Center(
                    // Removed local spinner since we have full screen Lottie now
                    child: Text(
                      "Verify OTP",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ),
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
        color: Colors.black.withOpacity(0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.15)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: TextField(
        controller: _controller,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 22,
          fontWeight: FontWeight.w600,
          letterSpacing: 8.0,
        ),
        maxLength: 6,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
        ],
        decoration: const InputDecoration(
          hintText: "------",
          hintStyle: TextStyle(color: Colors.white38, letterSpacing: 8.0),
          border: InputBorder.none,
          counterText: "",
          contentPadding: EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }
}

// -------------------------------------------
// BOUNCY BUTTON WIDGET (Reused)
// -------------------------------------------
class BouncyButton extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;

  const BouncyButton({
    super.key,
    required this.child,
    required this.onTap
  });

  @override
  State<BouncyButton> createState() => _BouncyButtonState();
}

class _BouncyButtonState extends State<BouncyButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) => _controller.forward();
  void _onTapUp(TapUpDetails details) {
    _controller.reverse();
    widget.onTap();
  }
  void _onTapCancel() => _controller.reverse();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: widget.child,
      ),
    );
  }
}