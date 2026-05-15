import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:frontend/app_theme.dart';
import 'package:frontend/services/auth_service.dart';

/// Login Screen
/// 
/// Simple Google Sign-In only, optimized for web browsers.
/// Used as a full-screen overlay managed by parent widget state,
/// NOT pushed as a Navigator route (to avoid widget tree destruction issues).
class LoginScreen extends StatefulWidget {
  /// Called when the user wants to dismiss the login screen (e.g. back button).
  final VoidCallback? onDismiss;

  const LoginScreen({super.key, this.onDismiss});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _signInWithGoogle() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final success = await authService.signInWithGoogle();
      
      // No navigation needed here. The parent widget listens to AuthService
      // and will automatically hide this screen when isAuthenticated becomes true.
      if (!success && mounted) {
        setState(() {
          _errorMessage = 'Sign-in failed. Please try again.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Sign-in failed: ${e.toString()}';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundCream,
      // Show a back button to dismiss login if callback provided
      appBar: widget.onDismiss != null
          ? AppBar(
              backgroundColor: AppTheme.backgroundCream,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.primaryNavy),
                onPressed: widget.onDismiss,
              ),
            )
          : null,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 180, maxWidth: 360),
                  child: Image.asset(
                    'assets/primarylogo.png',
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(height: 32),

                // Title
                Text(
                  'Meerkat',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: AppTheme.primaryNavy,
                        fontWeight: FontWeight.bold,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),

                // Subtitle
                Text(
                  'Your Watchful Advisor',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppTheme.textLight,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 48),

                // Error message
                if (_errorMessage != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 24),
                    decoration: BoxDecoration(
                      color: AppTheme.errorRed.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: AppTheme.errorRed,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(
                              color: AppTheme.errorRed,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Google Sign-In Button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: OutlinedButton(
                    onPressed: _isLoading ? null : _signInWithGoogle,
                    style: OutlinedButton.styleFrom(
                      backgroundColor: Colors.white,
                      side: const BorderSide(color: AppTheme.borderLight),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Image.network(
                                'https://www.google.com/favicon.ico',
                                width: 20,
                                height: 20,
                                errorBuilder: (_, __, ___) => const Icon(
                                  Icons.g_mobiledata,
                                  size: 24,
                                  color: AppTheme.primaryNavy,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Continue with Google',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: AppTheme.textDark,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 32),

                // Footer text
                Text(
                  'By continuing, you agree to our Terms of Service',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.textLight,
                      ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
