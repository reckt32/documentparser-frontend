import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:frontend/constants.dart';
import 'package:frontend/app_theme.dart';

class LoginScreen extends StatefulWidget {
  final VoidCallback onLoginSuccess;

  const LoginScreen({super.key, required this.onLoginSuccess});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  String _errorMessage = '';

  Future<void> _login() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final response = await http.post(
        Uri.parse('$kBackendUrl/login'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'username': _usernameController.text,
          'password': _passwordController.text,
        }),
      );

      if (response.statusCode == 200) {
        // Login successful
        widget.onLoginSuccess();
      } else {
        // Login failed
        final errorData = json.decode(response.body);
        setState(() {
          _errorMessage = errorData['message'] ?? 'Login failed. Please try again.';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error: Could not connect to the server.';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isWideScreen = size.width > 800;

    return Scaffold(
      body: isWideScreen
          ? Row(
              children: [
                // Left branding panel
                Expanded(
                  flex: 5,
                  child: _buildBrandingPanel(),
                ),
                // Right login form
                Expanded(
                  flex: 5,
                  child: _buildLoginForm(context),
                ),
              ],
            )
          : _buildLoginForm(context),
    );
  }

  Widget _buildBrandingPanel() {
    return Container(
      color: AppTheme.primaryNavy,
      padding: const EdgeInsets.all(60),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Primary logo
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 80, maxWidth: 200),
            child: Image.asset(
              'assets/primarylogo.png',
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(height: 32),
          // Gold accent bar
          AppTheme.goldAccentBar(width: 80, height: 3),
          const SizedBox(height: 40),
          // Split typography - "Financial Intelligence"
          Text(
            'Financial',
            style: Theme.of(context).textTheme.displayMedium?.copyWith(
                  color: Colors.white,
                  height: 0.9,
                ),
          ),
          Text(
            'Intelligence',
            style: Theme.of(context).textTheme.displayMedium?.copyWith(
                  color: AppTheme.accentGold,
                  height: 0.9,
                ),
          ),
          const SizedBox(height: 32),
          Text(
            'Parse, analyze, and optimize your financial documents with precision and clarity.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 16,
                  height: 1.6,
                ),
          ),
          const SizedBox(height: 60),
          // Feature points with gold accent
          _buildFeaturePoint('Document analysis powered by advanced technology'),
          const SizedBox(height: 16),
          _buildFeaturePoint('Automated financial insights and recommendations'),
          const SizedBox(height: 16),
          _buildFeaturePoint('Secure, professional-grade data handling'),
        ],
      ),
    );
  }

  Widget _buildFeaturePoint(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 6,
          height: 6,
          margin: const EdgeInsets.only(top: 8),
          decoration: const BoxDecoration(
            color: AppTheme.accentGold,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.85),
                  height: 1.6,
                ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoginForm(BuildContext context) {
    return Container(
      color: AppTheme.backgroundCream,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 60, vertical: 40),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                Text(
                  'Welcome Back',
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        color: AppTheme.primaryNavy,
                      ),
                ),
                const SizedBox(height: 8),
                AppTheme.goldAccentBar(width: 60, height: 2),
                const SizedBox(height: 16),
                Text(
                  'Login to your account to continue',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 48),

                // Username field
                Text(
                  'USERNAME',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: AppTheme.textDark,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.0,
                      ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _usernameController,
                  decoration: const InputDecoration(
                    hintText: 'Enter your username',
                  ),
                  keyboardType: TextInputType.text,
                ),
                const SizedBox(height: 24),

                // Password field
                Text(
                  'PASSWORD',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: AppTheme.textDark,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.0,
                      ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _passwordController,
                  decoration: const InputDecoration(
                    hintText: 'Enter your password',
                  ),
                  obscureText: true,
                ),
                const SizedBox(height: 32),

                // Error message
                if (_errorMessage.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    margin: const EdgeInsets.only(bottom: 24),
                    decoration: BoxDecoration(
                      color: AppTheme.errorRed.withValues(alpha: 0.1),
                      border: Border(
                        left: BorderSide(
                          color: AppTheme.errorRed,
                          width: 3,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.error_outline,
                          color: AppTheme.errorRed,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _errorMessage,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: AppTheme.errorRed,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Login button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _login,
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text('Login'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
