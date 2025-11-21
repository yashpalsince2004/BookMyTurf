import 'dart:ui';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'dart:async';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  // Logic
  String? _loadingProvider;
  StreamSubscription? _gyroStream;

  // Parallax smooth values
  double _offsetX = 0;
  double _offsetY = 0;
  double smoothX = 0;
  double smoothY = 0;

  // Animation
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    // --------- Smooth Parallax Setup ----------
    const double smoothFactor = 0.05; // lower = smoother

    _gyroStream = gyroscopeEvents.listen((GyroscopeEvent e) {
      if (!mounted) return;

      double targetX = (e.y * 8).clamp(-20.0, 20.0);
      double targetY = (e.x * 8).clamp(-20.0, 20.0);

      // Low-pass filtering
      smoothX = smoothX + (targetX - smoothX) * smoothFactor;
      smoothY = smoothY + (targetY - smoothY) * smoothFactor;

      setState(() {
        _offsetX = smoothX;
        _offsetY = smoothY;
      });
    });

    // --------- Entrance Animations ----------
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animController,
        curve: Curves.easeOutQuart,
      ),
    );

    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.2, 1.0, curve: Curves.easeOut),
      ),
    );

    _animController.forward();
  }

  @override
  void dispose() {
    _gyroStream?.cancel();
    _animController.dispose();
    super.dispose();
  }

  // ------------------------------------
  // AUTH HANDLERS
  // ------------------------------------

  Future<void> _handleGoogleSignIn() async {
    setState(() => _loadingProvider = 'google');
    try {
      final result = await signInWithGoogle();
      if (result != null && mounted) {
        Navigator.pushReplacementNamed(context, "/home");
      }
    } catch (e) {
      _showSnackBar("Google Login failed. Please try again.", isError: true);
    } finally {
      if (mounted) setState(() => _loadingProvider = null);
    }
  }

  Future<void> _handleAppleSignIn() async {
    setState(() => _loadingProvider = 'apple');
    try {
      final result = await signInWithApple();
      if (result != null && mounted) {
        Navigator.pushReplacementNamed(context, "/home");
      }
    } catch (e) {
      _showSnackBar("Apple Login failed.", isError: true);
    } finally {
      if (mounted) setState(() => _loadingProvider = null);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor:
        isError ? Colors.redAccent.withOpacity(0.8) : Colors.green,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
      body: Stack(
        children: [
          // -------------------------------------------
          // SMOOTH PARALLAX + ZOOM BACKGROUND
          // -------------------------------------------
          Positioned.fill(
            child: Transform.scale(
              scale: 1.06, // zoom effect
              child: Transform.translate(
                offset: Offset(_offsetX, _offsetY),
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.black,
                    image: DecorationImage(
                      image: AssetImage("assets/images/turf_bg.png"),
                      fit: BoxFit.cover,
                      opacity: 0.8,
                    ),
                  ),
                ),
              ),
            ),
          ),

          // -------------------------------------------
          // GLASS CONTENT
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
            border: Border.all(color: Colors.white.withOpacity(0.2), width: 1.5),
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
                color: Colors.black.withOpacity(0.25),
                blurRadius: 25,
                spreadRadius: 5,
              ),
            ],
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
                  shadows: [
                    Shadow(
                      offset: const Offset(0, 2),
                      blurRadius: 10,
                      color: Colors.black.withOpacity(0.3),
                    )
                  ],
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

              _buildAuthButton(
                id: 'google',
                label: "Continue with Google",
                icon: Icons.g_mobiledata_rounded,
                onTap: _handleGoogleSignIn,
                color: Colors.white.withOpacity(0.15),
              ),

              const SizedBox(height: 16),

              if (Platform.isIOS) ...[
                _buildAuthButton(
                  id: 'apple',
                  label: "Continue with Apple",
                  icon: Icons.apple,
                  onTap: _handleAppleSignIn,
                  color: Colors.black.withOpacity(0.3),
                ),
                const SizedBox(height: 16),
              ],

              _buildAuthButton(
                id: 'phone',
                label: "Login with Phone",
                icon: Icons.phone_iphone_rounded,
                onTap: () => Navigator.pushNamed(context, "/phoneLogin"),
                color: Colors.white.withOpacity(0.15),
              ),

              const SizedBox(height: 32),

              GestureDetector(
                onTap: () => Navigator.pushReplacementNamed(context, "/home"),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  color: Colors.transparent,
                  child: Text(
                    "Skip for now →",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withOpacity(0.8),
                      decoration: TextDecoration.underline,
                      decorationColor: Colors.white.withOpacity(0.5),
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

  // ------------------------------------
  //   AUTH BUTTON (GLASS STYLE)
  // ------------------------------------

  Widget _buildAuthButton({
    required String id,
    required String label,
    required IconData icon,
    required VoidCallback onTap,
    required Color color,
  }) {
    final bool isLoading = _loadingProvider == id;
    final bool isAnyLoading = _loadingProvider != null;

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          height: 54,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withOpacity(0.25)),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: isAnyLoading ? null : onTap,
              splashColor: Colors.white.withOpacity(0.1),
              highlightColor: Colors.white.withOpacity(0.05),
              child: Center(
                child: isLoading
                    ? const SizedBox(
                  height: 22,
                  width: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white,
                  ),
                )
                    : Row(
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
            ),
          ),
        ),
      ),
    );
  }
}

// =======================================================================
//        AUTH HELPERS
// =======================================================================

Future<UserCredential?> signInWithGoogle() async {
  final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
  if (googleUser == null) return null;

  final GoogleSignInAuthentication googleAuth =
  await googleUser.authentication;

  final OAuthCredential credential = GoogleAuthProvider.credential(
    accessToken: googleAuth.accessToken,
    idToken: googleAuth.idToken,
  );

  return FirebaseAuth.instance.signInWithCredential(credential);
}

Future<UserCredential?> signInWithApple() async {
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

  return FirebaseAuth.instance.signInWithCredential(credential);
}
