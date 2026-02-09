import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:frontend/app_theme.dart';
import 'package:frontend/services/auth_service.dart';
import 'package:frontend/services/payment_service.dart';

/// Payment Screen
/// 
/// Shown when user is authenticated but hasn't completed payment.
/// Clean, web-optimized design with Razorpay integration.
class PaymentScreen extends StatefulWidget {
  const PaymentScreen({super.key});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  bool _isProcessing = false;
  bool _isCheckingStatus = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _checkPaymentStatus();
  }

  /// Check payment status on screen init to handle edge cases
  /// where local state is out of sync with backend
  Future<void> _checkPaymentStatus() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    
    // Force refresh from backend to ensure we have latest status
    await authService.forceRefreshPaymentStatus();
    
    if (mounted) {
      setState(() {
        _isCheckingStatus = false;
      });
    }
  }

  Future<void> _startPayment() async {
    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    final paymentService = Provider.of<PaymentService>(context, listen: false);
    
    await paymentService.startPayment(
      onSuccess: (paymentId) {
        if (mounted) {
          setState(() {
            _isProcessing = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Payment successful! Welcome aboard.'),
              backgroundColor: Colors.green,
            ),
          );
        }
      },
      onError: (message) {
        if (mounted) {
          setState(() {
            _isProcessing = false;
            _errorMessage = message;
          });
        }
      },
    );

    if (mounted) {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  Future<void> _signOut() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    await authService.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final size = MediaQuery.of(context).size;

    // Show loading while checking payment status with backend
    if (_isCheckingStatus || authService.isSyncing) {
      return Scaffold(
        backgroundColor: AppTheme.backgroundCream,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: AppTheme.primaryNavy),
              const SizedBox(height: 16),
              Text(
                'Verifying payment status...',
                style: TextStyle(color: AppTheme.textLight, fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.backgroundCream,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          TextButton.icon(
            onPressed: _signOut,
            icon: const Icon(Icons.logout, size: 18),
            label: const Text('Sign Out'),
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.textLight,
            ),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Welcome message
                Text(
                  'Welcome, ${authService.displayName ?? 'there'}!',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: AppTheme.primaryNavy,
                        fontWeight: FontWeight.bold,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'One step to unlock your financial insights',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppTheme.textLight,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),

                // Pricing card
                Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 20,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Price badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.accentGold.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Text(
                          'LIFETIME ACCESS',
                          style: TextStyle(
                            color: AppTheme.accentGold,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Price
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '₹',
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  color: AppTheme.primaryNavy,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          Text(
                            '499',
                            style: Theme.of(context).textTheme.displayMedium?.copyWith(
                                  color: AppTheme.primaryNavy,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        ],
                      ),
                      Text(
                        'one-time payment',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppTheme.textLight,
                            ),
                      ),
                      const SizedBox(height: 28),

                      // Features list
                      _buildFeatureItem('Unlimited financial reports'),
                      _buildFeatureItem('AI-powered document analysis'),
                      _buildFeatureItem('Personalized recommendations'),
                      _buildFeatureItem('Goal planning & tracking'),
                      _buildFeatureItem('Tax optimization insights'),
                      const SizedBox(height: 28),

                      // Error message with retry option
                      if (_errorMessage != null)
                        Container(
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: AppTheme.errorRed.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.error_outline,
                                    color: AppTheme.errorRed,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _errorMessage!,
                                      style: const TextStyle(
                                        color: AppTheme.errorRed,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              GestureDetector(
                                onTap: _checkPaymentStatus,
                                child: Text(
                                  'Already paid? Tap here to check status',
                                  style: TextStyle(
                                    color: AppTheme.primaryNavy,
                                    fontSize: 12,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                      // Pay button
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _isProcessing ? null : _startPayment,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryNavy,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: _isProcessing
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.lock_open, size: 18),
                                    SizedBox(width: 8),
                                    Text(
                                      'Unlock Now',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Security note
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.shield_outlined,
                            size: 14,
                            color: Colors.grey.shade500,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Secured by Razorpay',
                            style: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureItem(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(
            Icons.check_circle,
            color: AppTheme.successGreen,
            size: 18,
          ),
          const SizedBox(width: 10),
          Text(
            text,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.textDark,
                ),
          ),
        ],
      ),
    );
  }
}
