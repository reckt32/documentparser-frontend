import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:frontend/constants.dart';

/// User model representing the authenticated user
class AppUser {
  final String firebaseUid;
  final String? email;
  final String? displayName;
  final bool hasPaid;
  final String? paymentDate;
  final int reportCredits;

  AppUser({
    required this.firebaseUid,
    this.email,
    this.displayName,
    this.hasPaid = false,
    this.paymentDate,
    this.reportCredits = 0,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      firebaseUid: json['firebase_uid'] ?? '',
      email: json['email'],
      displayName: json['display_name'],
      hasPaid: json['has_paid'] ?? false,
      paymentDate: json['payment_date'],
      reportCredits: json['report_credits'] ?? 0,
    );
  }
}

/// Authentication Service
/// 
/// Manages Firebase authentication state and provides methods for:
/// - Google Sign-in
/// - Email/Password authentication
/// - Token management for API calls
/// - Payment status tracking
class AuthService extends ChangeNotifier {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  
  User? _firebaseUser;
  AppUser? _appUser;
  String? _idToken;
  bool _isLoading = false;
  bool _isSyncing = false;  // Tracks if backend sync is in progress
  String? _error;

  // Getters
  User? get firebaseUser => _firebaseUser;
  AppUser? get appUser => _appUser;
  bool get isAuthenticated => _firebaseUser != null;
  bool get hasPaid => _appUser?.hasPaid ?? false;
  bool get hasCredits => (_appUser?.reportCredits ?? 0) > 0;
  int get reportCredits => _appUser?.reportCredits ?? 0;
  bool get isLoading => _isLoading;
  bool get isSyncing => _isSyncing;  // True while syncing with backend
  String? get error => _error;
  String? get displayName => _appUser?.displayName ?? _firebaseUser?.displayName;
  String? get email => _appUser?.email ?? _firebaseUser?.email;
  String? get photoUrl => _firebaseUser?.photoURL;

  AuthService() {
    // Listen to Firebase auth state changes
    _firebaseAuth.authStateChanges().listen(_onAuthStateChanged);
  }

  /// Handle Firebase auth state changes
  void _onAuthStateChanged(User? user) async {
    _firebaseUser = user;
    if (user != null) {
      // Get fresh ID token and sync with backend
      await _syncWithBackend();
    } else {
      _appUser = null;
      _idToken = null;
    }
    notifyListeners();
  }

  /// Sync user with backend after Firebase auth
  Future<void> _syncWithBackend() async {
    if (_firebaseUser == null) return;

    _isSyncing = true;
    _error = null;
    notifyListeners();

    try {
      _idToken = await _firebaseUser!.getIdToken();
      
      // Add timeout to prevent infinite loading
      final response = await http.post(
        Uri.parse('$kBackendUrl/auth/verify'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'id_token': _idToken}),
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw TimeoutException('Backend sync timed out'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _appUser = AppUser.fromJson(data['user']);
        _error = null;
      } else {
        _error = 'Failed to sync with backend';
        debugPrint('Backend sync failed: ${response.body}');
      }
    } on TimeoutException {
      _error = 'Connection timed out. Tap to retry.';
      debugPrint('Backend sync timed out');
    } catch (e) {
      _error = 'Network error. Tap to retry.';
      debugPrint('Backend sync error: $e');
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  /// Retry backend sync (called when user taps retry)
  Future<void> retrySync() async {
    await _syncWithBackend();
  }

  /// Force refresh payment status with reconciliation fallback
  /// 
  /// Calls /auth/status first. If that shows unpaid, calls /payment/reconcile
  /// to check Razorpay directly and recover if payment exists.
  Future<void> forceRefreshPaymentStatus() async {
    if (_firebaseUser == null) return;

    _isSyncing = true;
    _error = null;
    notifyListeners();

    try {
      final token = await getIdToken(forceRefresh: true);
      if (token == null) {
        _error = 'Authentication failed';
        return;
      }

      // First, get current status from backend
      var response = await http.get(
        Uri.parse('$kBackendUrl/auth/status'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final hasPaidFromServer = data['user']?['has_paid'] ?? false;

        if (hasPaidFromServer) {
          _appUser = AppUser.fromJson(data['user']);
          _error = null;
          return;
        }

        // Server says unpaid - try reconciliation with Razorpay
        debugPrint('Server shows unpaid, attempting reconciliation...');
        response = await http.post(
          Uri.parse('$kBackendUrl/payment/reconcile'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        ).timeout(const Duration(seconds: 15));

        if (response.statusCode == 200) {
          final reconcileData = json.decode(response.body);
          if (reconcileData['has_paid'] == true) {
            // Reconciliation found payment - update local state
            debugPrint('Reconciliation found payment! Updating state.');
            _appUser = AppUser(
              firebaseUid: _appUser!.firebaseUid,
              email: _appUser!.email,
              displayName: _appUser!.displayName,
              hasPaid: true,
              paymentDate: reconcileData['payment_date'] ?? DateTime.now().toIso8601String(),
            );
          } else {
            // Update app user from current status (unpaid confirmed)
            final statusData = json.decode((await http.get(
              Uri.parse('$kBackendUrl/auth/status'),
              headers: {
                'Authorization': 'Bearer $token',
                'Content-Type': 'application/json',
              },
            )).body);
            _appUser = AppUser.fromJson(statusData['user']);
          }
          _error = null;
        }
      } else {
        _error = 'Failed to check status';
      }
    } on TimeoutException {
      _error = 'Connection timed out';
      debugPrint('forceRefreshPaymentStatus timed out');
    } catch (e) {
      _error = 'Failed to refresh status: $e';
      debugPrint('forceRefreshPaymentStatus error: $e');
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  /// Get fresh ID token for API calls
  Future<String?> getIdToken({bool forceRefresh = false}) async {
    if (_firebaseUser == null) return null;
    
    try {
      _idToken = await _firebaseUser!.getIdToken(forceRefresh);
      return _idToken;
    } catch (e) {
      debugPrint('Failed to get ID token: $e');
      return null;
    }
  }

  /// Sign in with Google
  Future<bool> signInWithGoogle() async {
    _setLoading(true);
    _error = null;

    try {
      // Trigger Google Sign-in flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      
      if (googleUser == null) {
        _setLoading(false);
        return false; // User cancelled
      }

      // Get Google auth details
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // Create Firebase credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase
      await _firebaseAuth.signInWithCredential(credential);
      
      _setLoading(false);
      return true;
    } on FirebaseAuthException catch (e) {
      _error = _getAuthErrorMessage(e.code);
      _setLoading(false);
      return false;
    } catch (e) {
      _error = 'Sign-in failed: $e';
      _setLoading(false);
      return false;
    }
  }

  /// Sign in with email and password
  Future<bool> signInWithEmail(String email, String password) async {
    _setLoading(true);
    _error = null;

    try {
      await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      _setLoading(false);
      return true;
    } on FirebaseAuthException catch (e) {
      _error = _getAuthErrorMessage(e.code);
      _setLoading(false);
      return false;
    } catch (e) {
      _error = 'Sign-in failed: $e';
      _setLoading(false);
      return false;
    }
  }

  /// Create account with email and password
  Future<bool> signUpWithEmail(String email, String password) async {
    _setLoading(true);
    _error = null;

    try {
      await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      _setLoading(false);
      return true;
    } on FirebaseAuthException catch (e) {
      _error = _getAuthErrorMessage(e.code);
      _setLoading(false);
      return false;
    } catch (e) {
      _error = 'Sign-up failed: $e';
      _setLoading(false);
      return false;
    }
  }

  /// Sign out
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _firebaseAuth.signOut();
    _appUser = null;
    _idToken = null;
    notifyListeners();
  }

  /// Refresh payment status from backend
  Future<void> refreshPaymentStatus() async {
    if (_firebaseUser == null) return;

    try {
      final token = await getIdToken(forceRefresh: true);
      if (token == null) return;

      final response = await http.get(
        Uri.parse('$kBackendUrl/auth/status'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _appUser = AppUser.fromJson(data['user']);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Failed to refresh payment status: $e');
    }
  }

  /// Mark user as paid (called after successful payment)
  void markAsPaid({int creditsAdded = 3}) {
    if (_appUser != null) {
      _appUser = AppUser(
        firebaseUid: _appUser!.firebaseUid,
        email: _appUser!.email,
        displayName: _appUser!.displayName,
        hasPaid: true,
        paymentDate: DateTime.now().toIso8601String(),
        reportCredits: _appUser!.reportCredits + creditsAdded,
      );
      notifyListeners();
    }
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  /// Convert Firebase auth error codes to user-friendly messages
  String _getAuthErrorMessage(String code) {
    switch (code) {
      case 'user-not-found':
        return 'No account found with this email.';
      case 'wrong-password':
        return 'Incorrect password.';
      case 'email-already-in-use':
        return 'An account already exists with this email.';
      case 'weak-password':
        return 'Password is too weak. Use at least 6 characters.';
      case 'invalid-email':
        return 'Invalid email address.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'operation-not-allowed':
        return 'Sign-in method not enabled.';
      case 'network-request-failed':
        return 'Network error. Check your connection.';
      default:
        return 'Authentication failed. Please try again.';
    }
  }
}
