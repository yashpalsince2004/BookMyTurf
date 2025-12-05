import 'package:bookmyturf/screens/booking/booking_history_screen.dart';
import 'package:bookmyturf/screens/main_wrapper.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:lottie/lottie.dart';

// GENERATED FILE
import 'firebase_options.dart';

// Your Screens
import 'screens/auth/login_screen.dart';
import 'screens/auth/phone_login_screen.dart';
import 'screens/auth/otp_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  print("🔥 Firebase Initialized Successfully!");
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Book My Turf',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        scaffoldBackgroundColor: Colors.black,
      ),
      routes: {
        '/login': (_) => const LoginScreen(),
        '/phoneLogin': (_) => const PhoneLoginScreen(),
        "/bookingHistory": (context) => const BookingHistoryScreen(),
        '/home': (_) => MainWrapper(),
        '/otp': (context) {
          final verificationId =
          ModalRoute.of(context)!.settings.arguments as String;
          return OtpScreen(verificationId: verificationId);
        },
      },
      home: const AuthGate(),
    );
  }
}

// ---------------------------------------------------------
// SMART AUTH GATE
// ---------------------------------------------------------
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _animationFinished = false;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {

        // 1. Initial Loading (Wait for Auth Check)
        if (snapshot.connectionState == ConnectionState.waiting) {
          // Just show a black screen while checking auth (very fast)
          return const Scaffold(backgroundColor: Colors.black);
        }

        // 2. User IS Logged In
        if (snapshot.hasData) {
          // Use AnimatedSwitcher for smooth fade to Home
          return AnimatedSwitcher(
            duration: const Duration(milliseconds: 800),
            transitionBuilder: (child, animation) {
              return FadeTransition(opacity: animation, child: child);
            },
            child: _animationFinished
                ? MainWrapper()
                : SessionRestorationLoading(
              onComplete: () {
                setState(() {
                  _animationFinished = true;
                });
              },
            ),
          );
        }

        // 3. User is NOT Logged In
        else {
          _animationFinished = false;
          return const LoginScreen();
        }
      },
    );
  }
}

// ---------------------------------------------------------
// SESSION RESTORATION LOADING SCREEN
// ---------------------------------------------------------
class SessionRestorationLoading extends StatefulWidget {
  final VoidCallback onComplete;
  const SessionRestorationLoading({super.key, required this.onComplete});

  @override
  State<SessionRestorationLoading> createState() =>
      _SessionRestorationLoadingState();
}

class _SessionRestorationLoadingState extends State<SessionRestorationLoading>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _playSequence();
    });
  }

  Future<void> _playSequence() async {
    // No waiting for background images. Just play immediately.
    if (!mounted) return;

    // Start animation
    await _controller.forward();

    // Go to Home
    widget.onComplete();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Lottie.asset(
          "assets/lottie/login_loading.json",
          controller: _controller,
          width: 280,
          height: 280,
          fit: BoxFit.contain,
          onLoaded: (composition) {
            _controller.duration = composition.duration;
          },
        ),
      ),
    );
  }
}