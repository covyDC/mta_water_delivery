import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
// Emulator imports removed since the app now uses production Firebase endpoints by default.
import 'firebase_options.dart';
import 'package:mta_water_delivery/screens/auth/login.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Attach local emulator endpoints when running in debug mode.
  // This keeps emulator usage local and avoids any billing or production effects.
  // Emulator connections were removed so the app will use configured
  // production Firebase endpoints by default. If you want to use the
  // local Firebase emulators again, add back the emulator calls or
  // use a --dart-define toggle to conditionally enable them.

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: const LoginPage(),
    );
  }
}
