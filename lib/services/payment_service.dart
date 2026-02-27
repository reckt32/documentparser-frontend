import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
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
  int? _currentAmountPaise;
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
    _currentAmountPaise = orderData['amount'];
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
  ///
  /// Razorpay's success callback is authoritative — the payment IS captured.
  /// We update local state immediately so the UI navigates, then verify
  /// with the backend and refresh from server to ensure consistency.
  void _handlePaymentSuccess(PaymentSuccessResponse response) async {
    debugPrint('Payment success: ${response.paymentId}');
    
    try {
      // Update local state IMMEDIATELY — don't wait for backend verify.
      // Razorpay only fires this callback when payment is captured.
      _authService.markAsPaid();
      
      // CRITICAL: Razorpay's callback comes from JavaScript interop.
      // notifyListeners() inside markAsPaid() may not trigger a Flutter
      // frame rebuild in this JS callback context. Force it.
      WidgetsBinding.instance.scheduleFrame();
      
      // Also schedule a delayed re-notify as a safety net for web rendering
      Future.delayed(const Duration(milliseconds: 100), () {
        _authService.notifyListeners();
      });
      
      _onSuccess?.call(response.paymentId ?? '');

      // Push purchase event to GTM dataLayer for conversion tracking
      _pushPurchaseToDataLayer(
        paymentId: response.paymentId ?? '',
        orderId: response.orderId ?? _currentOrderId ?? '',
        amountPaise: _currentAmountPaise ?? 99900,
      );
      
      // Verify with backend (blocking) then refresh state from server
      try {
        final verifyResponse = await _apiService.post('/payment/verify', {
          'order_id': response.orderId ?? _currentOrderId,
          'payment_id': response.paymentId,
          'signature': response.signature,
        });
        
        if (verifyResponse.success) {
          debugPrint('Backend verification confirmed');
        } else {
          debugPrint('Backend verify failed (webhook will handle): ${verifyResponse.errorMessage}');
        }
      } catch (e) {
        debugPrint('Backend verify error (webhook will handle): $e');
      }
      
      // Always refresh from server to ensure credits are synced
      await _authService.refreshPaymentStatus();
    } catch (e) {
      debugPrint('Error in payment success handler: $e');
      // Even on error, try to refresh from server as last resort
      try {
        await _authService.refreshPaymentStatus();
      } catch (_) {}
      _onError?.call('Payment processing error. Please check your payment status.');
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

  /// Push a GA4 ecommerce 'purchase' event to the GTM dataLayer
  void _pushPurchaseToDataLayer({
    required String paymentId,
    required String orderId,
    required int amountPaise,
  }) {
    try {
      final amountRupees = amountPaise / 100;
      final jsEvent = {
        'event': 'purchase',
        'ecommerce': {
          'transaction_id': paymentId,
          'value': amountRupees,
          'currency': 'INR',
          'items': [
            {
              'item_id': 'report_credits_3',
              'item_name': '3 Financial Reports',
              'price': amountRupees,
              'quantity': 1,
            }
          ],
        },
        'razorpay_order_id': orderId,
      }.jsify();

      // Access window.dataLayer and push the event
      final dataLayer = globalContext.getProperty('dataLayer'.toJS);
      if (dataLayer.isA<JSArray>()) {
        (dataLayer as JSArray).callMethod('push'.toJS, jsEvent);
        debugPrint('GTM purchase event pushed: $paymentId');
      } else {
        debugPrint('GTM dataLayer not found on window');
      }
    } catch (e) {
      // Never let analytics break the payment flow
      debugPrint('Failed to push GTM purchase event: $e');
    }
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
        pricePaise: response.data['report_price_paise'] ?? 99900,
        remainingCredits: response.data['remaining_credits'] ?? 0,
        canGenerateReport: response.data['can_generate_report'] ?? false,
        creditsPerPayment: response.data['credits_per_payment'] ?? 3,
      );
    }
    
    return PaymentStatus(hasPaid: false, pricePaise: 99900, remainingCredits: 0);
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
