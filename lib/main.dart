import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:frontend/login_screen.dart';
import 'package:frontend/main_app_screen.dart';
import 'package:frontend/payment_screen.dart';
import 'package:frontend/app_theme.dart';
import 'package:frontend/services/auth_service.dart';
import 'package:frontend/services/api_service.dart';
import 'package:frontend/services/payment_service.dart';
import 'package:frontend/firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase with platform-specific options
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
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
        
        // Payment service depends on both AuthService and ApiService
        ProxyProvider2<AuthService, ApiService, PaymentService>(
          update: (_, authService, apiService, previous) => 
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
        // Show loading while Firebase initializes or backend sync is in progress
        if (authService.isLoading || authService.isSyncing) {
          return Scaffold(
            backgroundColor: AppTheme.backgroundCream,
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(
                    color: AppTheme.primaryNavy,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Loading...',
                    style: TextStyle(
                      color: AppTheme.textLight,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        // Show error state with retry if sync failed but user is authenticated
        if (authService.error != null && authService.isAuthenticated) {
          return Scaffold(
            backgroundColor: AppTheme.backgroundCream,
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.cloud_off,
                    size: 48,
                    color: AppTheme.textLight,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    authService.error!,
                    style: TextStyle(
                      color: AppTheme.textLight,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => authService.retrySync(),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryNavy,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        // User is not logged in - show login screen
        if (!authService.isAuthenticated) {
          return const LoginScreen();
        }

        // User has no report credits - show payment screen
        if (!authService.hasCredits) {
          return const PaymentScreen();
        }

        // User is authenticated and has credits - show main app
        return MainAppScreen(
          onLogout: () async {
            await authService.signOut();
          },
        );
      },
    );
  }
}
