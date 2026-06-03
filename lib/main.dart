import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';

import 'package:frontend/main_app_screen.dart';
import 'package:frontend/app_theme.dart';
import 'package:frontend/services/auth_service.dart';
import 'package:frontend/services/api_service.dart';
import 'package:frontend/services/dashboard_service.dart';
import 'package:frontend/services/payment_service.dart';
import 'package:frontend/firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase with platform-specific options
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Auth service manages Firebase authentication state
        ChangeNotifierProvider(create: (_) => AuthService()),

        // API service depends on AuthService for token management
        ProxyProvider<AuthService, ApiService>(
          update: (_, authService, __) => ApiService(authService),
        ),

        // Dashboard service wraps the practice dashboard REST endpoints.
        ProxyProvider<ApiService, DashboardService>(
          update: (_, api, __) => DashboardService(api),
        ),

        // Payment service depends on both AuthService and ApiService
        ProxyProvider2<AuthService, ApiService, PaymentService>(
          update:
              (_, authService, apiService, previous) =>
                  previous ?? PaymentService(authService, apiService),
        ),
      ],
      child: MaterialApp(
        title: 'Meerkat',
        theme: AppTheme.theme,
        debugShowCheckedModeBanner: false,
        home: const AuthWrapper(),
      ),
    );
  }
}

/// Wrapper widget that handles authentication state
/// Shows appropriate screen based on auth and payment status
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthService>(
      builder: (context, authService, _) {
        // Show loading only for the initial Firebase auth-state resolution.
        // Sign-in and backend sync must not unmount MainAppScreen, because the
        // login UI is a child overlay managed by MainAppScreen state.
        if (authService.isInitializing) {
          return Scaffold(
            backgroundColor: AppTheme.backgroundCream,
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(color: AppTheme.primaryNavy),
                  const SizedBox(height: 16),
                  Text(
                    'Loading...',
                    style: TextStyle(color: AppTheme.textLight, fontSize: 14),
                  ),
                ],
              ),
            ),
          );
        }

        // Always show MainAppScreen — it handles login overlay internally
        return MainAppScreen(
          onLogout: () async {
            await authService.signOut();
          },
        );
      },
    );
  }
}
