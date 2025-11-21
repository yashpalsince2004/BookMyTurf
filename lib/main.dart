import 'package:bookmyturf/screens/main_wrapper.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'screens/home/home_screen.dart';


// GENERATED FILE — must exist after flutterfire configure
import 'firebase_options.dart';

// Your Screens
import 'screens/auth/login_screen.dart';
import 'screens/auth/phone_login_screen.dart';
import 'screens/auth/otp_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 🚀 Initialize Firebase BEFORE runApp()
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

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
      ),

      // --------------------------------------------------
      // ROUTES
      // --------------------------------------------------
      routes: {
        '/login': (_) => const LoginScreen(),
        '/phoneLogin': (_) => const PhoneLoginScreen(),
        '/otp': (context) {
          final verificationId =
          ModalRoute.of(context)!.settings.arguments as String;
          return OtpScreen(verificationId: verificationId);
        },
        '/home': (_) => MainWrapper(),

      },

      // Your initial screen
      home: const LoginScreen(),
    );
  }
}
