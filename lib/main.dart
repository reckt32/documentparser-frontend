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
class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _initialLoadComplete = false;

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthService>(
      builder: (context, authService, _) {
        // Only show the loading spinner on the INITIAL app startup.
        // Once the app has loaded, never swap MainAppScreen for a spinner
        // because that destroys the Navigator stack (and any pushed routes
        // like LoginScreen).
        if (!_initialLoadComplete) {
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
          // First time we reach here, the initial load is done
          _initialLoadComplete = true;
        }

        // We now show the MainAppScreen by default to allow for a public Landing Page
        // Authentication and Payment status will be checked inside specific screens/actions
        return MainAppScreen(
          onLogout: () async {
            await authService.signOut();
          },
        );
      },
    );
  }
}
