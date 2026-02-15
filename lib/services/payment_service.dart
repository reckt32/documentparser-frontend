import 'package:flutter/foundation.dart';
import 'package:razorpay_web/razorpay_web.dart';
import 'package:frontend/services/auth_service.dart';
import 'package:frontend/services/api_service.dart';

/// Payment result callback types
typedef PaymentSuccessCallback = void Function(String paymentId);
typedef PaymentErrorCallback = void Function(String message);

/// Payment Service
/// 
/// Handles Razorpay payment integration:
/// - Creating payment orders
/// - Processing payments using Razorpay SDK
/// - Verifying payments with backend
class PaymentService {
  final AuthService _authService;
  final ApiService _apiService;
  late Razorpay _razorpay;
  
  PaymentSuccessCallback? _onSuccess;
  PaymentErrorCallback? _onError;
  
  String? _currentOrderId;
  bool _isInitialized = false;

  PaymentService(this._authService, this._apiService);

  /// Initialize Razorpay SDK
  void init() {
    if (_isInitialized) return;
    
    _razorpay = Razorpay();
    _razorpay.on('payment.success', _handlePaymentSuccess);
    _razorpay.on('payment.error', _handlePaymentError);
    _razorpay.on('payment.external_wallet', _handleExternalWallet);
    
    _isInitialized = true;
  }

  /// Dispose Razorpay SDK
  void dispose() {
    if (_isInitialized) {
      _razorpay.clear();
      _isInitialized = false;
    }
  }

  /// Start payment flow
  /// 
  /// 1. Creates order on backend
  /// 2. Opens Razorpay checkout
  /// 3. Handles success/failure callbacks
  Future<bool> startPayment({
    required PaymentSuccessCallback onSuccess,
    required PaymentErrorCallback onError,
  }) async {
    init();
    
    _onSuccess = onSuccess;
    _onError = onError;

    // Create order on backend
    final response = await _apiService.post('/payment/create-order', {});
    
    if (!response.success) {
      onError(response.errorMessage ?? 'Failed to create order');
      return false;
    }

    final orderData = response.data['order'];
    _currentOrderId = orderData['order_id'];
    final keyId = orderData['key_id'];
    final amount = orderData['amount'];
    final userEmail = response.data['user_email'] ?? '';

    // Open Razorpay checkout
    var options = {
      'key': keyId,
      'amount': amount,
      'order_id': _currentOrderId,
      'name': 'Financial Report',
      'description': '3 Financial Reports',
      'prefill': {
        'email': userEmail,
      },
      'theme': {
        'color': '#1D3557',
      },
    };

    try {
      _razorpay.open(options);
      return true;
    } catch (e) {
      onError('Failed to open payment: $e');
      return false;
    }
  }

  /// Handle successful payment from Razorpay
  void _handlePaymentSuccess(PaymentSuccessResponse response) async {
    debugPrint('Payment success: ${response.paymentId}');
    
    // Verify payment with backend
    final verifyResponse = await _apiService.post('/payment/verify', {
      'order_id': response.orderId ?? _currentOrderId,
      'payment_id': response.paymentId,
      'signature': response.signature,
    });

    if (verifyResponse.success) {
      // Update local auth state
      _authService.markAsPaid();
      _onSuccess?.call(response.paymentId ?? '');
    } else {
      // Verify call failed — but webhook may have already processed the payment.
      // Refresh from backend to pick up webhook-processed payment.
      debugPrint('Verify failed, refreshing status from backend...');
      await _authService.forceRefreshPaymentStatus();
      if (_authService.hasCredits) {
        _onSuccess?.call(response.paymentId ?? '');
      } else {
        _onError?.call(verifyResponse.errorMessage ?? 'Payment verification failed');
      }
    }
  }

  /// Handle payment error from Razorpay
  void _handlePaymentError(PaymentFailureResponse response) {
    debugPrint('Payment error: ${response.code} - ${response.message}');
    
    String message;
    // Error codes: 0 = payment cancelled, 2 = network error
    switch (response.code) {
      case 0:
        message = 'Payment cancelled';
        break;
      case 2:
        message = 'Network error. Please check your connection.';
        break;
      default:
        message = response.message ?? 'Payment failed';
    }
    
    _onError?.call(message);
  }

  /// Handle external wallet selection
  void _handleExternalWallet(ExternalWalletResponse response) {
    debugPrint('External wallet selected: ${response.walletName}');
    // This is typically just informational
  }

  /// Get current payment status
  Future<PaymentStatus> getPaymentStatus() async {
    final response = await _apiService.get('/payment/status');
    
    if (response.success) {
      return PaymentStatus(
        hasPaid: response.data['has_paid'] ?? false,
        paymentId: response.data['payment_id'],
        paymentDate: response.data['payment_date'],
        pricePaise: response.data['report_price_paise'] ?? 49900,
        remainingCredits: response.data['remaining_credits'] ?? 0,
        canGenerateReport: response.data['can_generate_report'] ?? false,
        creditsPerPayment: response.data['credits_per_payment'] ?? 3,
      );
    }
    
    return PaymentStatus(hasPaid: false, pricePaise: 49900, remainingCredits: 0);
  }
}

/// Payment status model
class PaymentStatus {
  final bool hasPaid;
  final String? paymentId;
  final String? paymentDate;
  final int pricePaise;
  final int remainingCredits;
  final bool canGenerateReport;
  final int creditsPerPayment;

  PaymentStatus({
    required this.hasPaid,
    this.paymentId,
    this.paymentDate,
    required this.pricePaise,
    this.remainingCredits = 0,
    this.canGenerateReport = false,
    this.creditsPerPayment = 3,
  });

  /// Get formatted price in rupees
  String get formattedPrice {
    final rupees = pricePaise / 100;
    return '₹${rupees.toStringAsFixed(0)}';
  }
  
  /// Check if user needs to pay to generate reports
  bool get needsPayment => remainingCredits <= 0;
}
