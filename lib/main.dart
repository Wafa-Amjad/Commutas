import 'package:flutter/material.dart';
import 'screens/splash_screen.dart';
import 'theme.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Commutas',
      debugShowCheckedModeBanner: false,
      theme: CommutasThemes.lightTheme,
      home: const SplashScreen(),
    );
  }
}
