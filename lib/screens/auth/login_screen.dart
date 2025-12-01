import 'dart:ui';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:lottie/lottie.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'dart:async';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {

  // Logic
  String? _loadingProvider;

  // Animation States
  bool _showLoadingOverlay = false;
  bool _isAnimatingOut = false;

  // Controllers
  late AnimationController _entranceController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late AnimationController _lottieController;

  @override
  void initState() {
    super.initState();
    _preCacheAssets(); // <--- PRE-CACHE ASSETS

    _lottieController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );

    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    // Smoother Curve (EaseOutBack makes it settle nicely)
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

  // Helper to ensure assets are ready (Prevents first-frame jank)
  void _preCacheAssets() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      precacheImage(const AssetImage("assets/images/turf_bg.png"), context);
    });
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _lottieController.dispose();
    super.dispose();
  }

  // ------------------------------------
  // AUTH HANDLERS
  // ------------------------------------

  Future<void> _handleGoogleSignIn() async {
    // Prevent double taps
    if (_loadingProvider != null) return;

    setState(() {
      _loadingProvider = 'google';
    });

    try {
      // 1. Wait for User to Sign In (Google Sheet)
      final loginResult = await signInWithGoogle();

      if (loginResult != null && mounted) {
        // 2. SUCCESS! Now start the visual transition

        // A. Slide Card Down
        setState(() {
          _isAnimatingOut = true;
        });

        // B. Wait for slide to finish
        await Future.delayed(const Duration(milliseconds: 600));

        if (!mounted) return;

        // C. Show Lottie Overlay & Play Animation
        setState(() => _showLoadingOverlay = true);
        _lottieController.reset();
        await _lottieController.forward();

        // D. Navigate to Home
        Navigator.pushReplacementNamed(context, "/home");
      } else {
        // User cancelled
        _resetUI();
      }
    } catch (e) {
      debugPrint("Error: $e");
      if (mounted) _showSnackBar("Google Login failed.", isError: true);
      _resetUI();
    }
  }

  Future<void> _handleAppleSignIn() async {
    setState(() {
      _isAnimatingOut = true;
      _loadingProvider = 'apple';
    });

    await Future.delayed(const Duration(milliseconds: 500));

    if (!mounted) return;
    setState(() => _showLoadingOverlay = true);

    _lottieController.reset();
    final animationFuture = _lottieController.forward();

    try {
      final loginResult = await signInWithApple();
      if (loginResult != null && mounted) {
        await animationFuture;
        Navigator.pushReplacementNamed(context, "/home");
      } else {
        _resetUI();
      }
    } catch (e) {
      if (mounted) _showSnackBar("Apple Login failed.", isError: true);
      _resetUI();
    }
  }

  void _resetUI() {
    if (!mounted) return;
    _lottieController.stop();
    _lottieController.reset();
    setState(() {
      _isAnimatingOut = false;
      _showLoadingOverlay = false;
      _loadingProvider = null;
    });
  }

  void _showSnackBar(String message, {bool isError = false}) {
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
      backgroundColor: Colors.black, // Fallback color
      body: Stack(
        children: [
          // -------------------------------------------
          // 1. BACKGROUND WITH ZOOM EFFECT
          // -------------------------------------------
          Positioned.fill(
            child: AnimatedScale(
              // Zoom in slightly when loading starts
              scale: _isAnimatingOut ? 1.1 : 1.0,
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
          // 2. GLASS PANEL
          // -------------------------------------------
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: AnimatedSlide(
                    offset: _isAnimatingOut ? const Offset(0, 1.5) : Offset.zero,
                    duration: const Duration(milliseconds: 600),
                    curve: Curves.easeInOutCubic, // Very smooth curve
                    child: _buildGlassPanel(context),
                  ),
                ),
              ),
            ),
          ),

          // -------------------------------------------
          // 3. LOADING OVERLAY
          // -------------------------------------------
          Positioned.fill(
            child: IgnorePointer(
              ignoring: !_showLoadingOverlay,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 600),
                opacity: _showLoadingOverlay ? 1.0 : 0.0,
                curve: Curves.easeInOut,
                child: Container(
                  // Using a slight blur here adds a very premium feel
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
// ==========================================
// PASTE THIS AT THE VERY BOTTOM OF THE FILE
// (Outside of any class brackets)
// ==========================================

  Future<UserCredential?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) return null; // User cancelled

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      return await FirebaseAuth.instance.signInWithCredential(credential);
    } catch (e) {
      debugPrint("Google Sign In Error: $e");
      rethrow;
    }
  }

  Future<UserCredential?> signInWithApple() async {
    try {
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      final OAuthCredential credential = OAuthProvider("apple.com").credential(
        idToken: appleCredential.identityToken,
        accessToken: appleCredential.authorizationCode,
      );

      return await FirebaseAuth.instance.signInWithCredential(credential);
    } catch (e) {
      debugPrint("Apple Sign In Error: $e");
      rethrow;
    }
  }
  Widget _buildGlassPanel(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20), // Higher blur for premium look
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxWidth: 400),
          padding: const EdgeInsets.fromLTRB(24, 40, 24, 32),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08), // More subtle
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: Colors.white.withOpacity(0.15), width: 1.5),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Book My Turf",
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.bold,
                  color: Colors.white.withOpacity(0.95),
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Play anywhere, anytime",
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withOpacity(0.75),
                  letterSpacing: 0.5,
                ),
              ),

              const SizedBox(height: 40),

              // USES CUSTOM BOUNCY BUTTON
              BouncyButton(
                onTap: _handleGoogleSignIn,
                child: _buildAuthButtonContent(
                  label: "Continue with Google",
                  icon: Icons.g_mobiledata_rounded,
                  color: Colors.white.withOpacity(0.15),
                ),
              ),

              const SizedBox(height: 16),

              if (Platform.isIOS) ...[
                BouncyButton(
                  onTap: _handleAppleSignIn,
                  child: _buildAuthButtonContent(
                    label: "Continue with Apple",
                    icon: Icons.apple,
                    color: Colors.black.withOpacity(0.4),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              BouncyButton(
                onTap: () => Navigator.pushNamed(context, "/phoneLogin"),
                child: _buildAuthButtonContent(
                  label: "Login with Phone",
                  icon: Icons.phone_iphone_rounded,
                  color: Colors.white.withOpacity(0.15),
                ),
              ),

              const SizedBox(height: 32),

              GestureDetector(
                onTap: () => Navigator.pushReplacementNamed(context, "/home"),
                child: Text(
                  "Skip for now →",
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.8),
                    decoration: TextDecoration.underline,
                    decorationColor: Colors.white.withOpacity(0.5),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Refactored button content to use inside BouncyButton
  Widget _buildAuthButtonContent({
    required String label,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      height: 54,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.25)),
      ),
      child: Center(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 24),
            const SizedBox(width: 12),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// -------------------------------------------
// 4. NEW: BOUNCY BUTTON WIDGET
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
      duration: const Duration(milliseconds: 100), // Fast bounce
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

  void _onTapDown(TapDownDetails details) {
    _controller.forward();
  }

  void _onTapUp(TapUpDetails details) {
    _controller.reverse();
    widget.onTap();
  }

  void _onTapCancel() {
    _controller.reverse();
  }

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