import 'package:flutter/material.dart';
import 'package:frontend/login_screen.dart';
import 'package:frontend/main_app_screen.dart';
import 'package:frontend/app_theme.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _isLoggedIn = false; // Initial login state

  void _handleLoginSuccess() {
    setState(() {
      _isLoggedIn = true;
    });
  }

  void _handleLogout() {
    setState(() {
      _isLoggedIn = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Document Parser',
      theme: AppTheme.theme,
      debugShowCheckedModeBanner: false,
      home: _isLoggedIn
          ? MainAppScreen(onLogout: _handleLogout)
          : LoginScreen(onLoginSuccess: _handleLoginSuccess),
    );
  }
}
