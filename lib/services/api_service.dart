import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:frontend/constants.dart';
import 'package:frontend/services/auth_service.dart';

/// API Service
/// 
/// Centralized HTTP client that automatically injects Firebase ID token
/// for authenticated requests. Handles common error cases including
/// 401 (unauthorized) and 402 (payment required).
class ApiService {
  final AuthService _authService;

  ApiService(this._authService);

  /// Make an authenticated GET request
  Future<ApiResponse> get(String endpoint) async {
    final headers = await _getAuthHeaders();
    if (headers == null) {
      return ApiResponse.error('Not authenticated', statusCode: 401);
    }

    try {
      final response = await http.get(
        Uri.parse('$kBackendUrl$endpoint'),
        headers: headers,
      );
      return _handleResponse(response);
    } catch (e) {
      return ApiResponse.error('Network error: $e');
    }
  }

  /// Make an authenticated POST request
  Future<ApiResponse> post(String endpoint, Map<String, dynamic> body) async {
    final headers = await _getAuthHeaders();
    if (headers == null) {
      return ApiResponse.error('Not authenticated', statusCode: 401);
    }

    try {
      final response = await http.post(
        Uri.parse('$kBackendUrl$endpoint'),
        headers: headers,
        body: json.encode(body),
      );
      return _handleResponse(response);
    } catch (e) {
      return ApiResponse.error('Network error: $e');
    }
  }

  /// Make an unauthenticated POST request
  Future<ApiResponse> postUnauthenticated(String endpoint, Map<String, dynamic> body) async {
    try {
      final response = await http.post(
        Uri.parse('$kBackendUrl$endpoint'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      );
      return _handleResponse(response);
    } catch (e) {
      return ApiResponse.error('Network error: $e');
    }
  }

  /// Get headers with Authorization token
  Future<Map<String, String>?> _getAuthHeaders() async {
    final token = await _authService.getIdToken();
    if (token == null) return null;

    return {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
  }

  /// Handle HTTP response and convert to ApiResponse
  ApiResponse _handleResponse(http.Response response) {
    try {
      final data = json.decode(response.body);
      
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return ApiResponse.success(data);
      }

      // Handle specific error codes
      switch (response.statusCode) {
        case 401:
          return ApiResponse.error(
            data['message'] ?? 'Authentication required',
            statusCode: 401,
            data: data,
          );
        case 402:
          return ApiResponse.error(
            data['message'] ?? 'Payment required',
            statusCode: 402,
            data: data,
          );
        case 400:
          return ApiResponse.error(
            data['error'] ?? 'Bad request',
            statusCode: 400,
            data: data,
          );
        default:
          return ApiResponse.error(
            data['error'] ?? 'Request failed',
            statusCode: response.statusCode,
            data: data,
          );
      }
    } catch (e) {
      debugPrint('Failed to parse response: $e');
      return ApiResponse.error(
        'Invalid response from server',
        statusCode: response.statusCode,
      );
    }
  }
}

/// API Response wrapper
class ApiResponse {
  final bool success;
  final dynamic data;
  final String? errorMessage;
  final int? statusCode;

  ApiResponse._({
    required this.success,
    this.data,
    this.errorMessage,
    this.statusCode,
  });

  factory ApiResponse.success(dynamic data) {
    return ApiResponse._(success: true, data: data, statusCode: 200);
  }

  factory ApiResponse.error(String message, {int? statusCode, dynamic data}) {
    return ApiResponse._(
      success: false,
      errorMessage: message,
      statusCode: statusCode,
      data: data,
    );
  }

  /// Check if error is due to missing payment
  bool get isPaymentRequired => statusCode == 402;

  /// Check if error is due to authentication
  bool get isUnauthorized => statusCode == 401;
}
