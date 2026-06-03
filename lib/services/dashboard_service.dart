import 'dart:async';
import 'package:frontend/models/dashboard_models.dart';
import 'package:frontend/services/api_service.dart';

/// Thin wrapper around the dashboard REST endpoints.
///
/// All methods surface server failures via the returned [DashboardResult] so
/// the UI layer can render inline error states without throwing.
class DashboardService {
  final ApiService _api;

  DashboardService(this._api);

  /// `GET /api/dashboard/overview`
  Future<DashboardResult<DashboardOverview>> getOverview() async {
    final resp = await _api.get('/api/dashboard/overview');
    return _wrap(resp, (data) => DashboardOverview.fromJson(data));
  }

  /// `GET /api/dashboard/client/<pan>`
  Future<DashboardResult<ClientDetail>> getClientDetail(String pan) async {
    final normalized = pan.trim().toUpperCase();
    if (normalized.isEmpty) {
      return DashboardResult.failure('Client PAN is required');
    }
    final resp = await _api.get('/api/dashboard/client/$normalized');
    if (!resp.success) {
      // 404 means "no active report" — not really a failure, treat as empty.
      if (resp.statusCode == 404 && resp.data is Map) {
        final data = (resp.data as Map).cast<String, dynamic>();
        return DashboardResult.success(
          ClientDetail.fromJson({
            'client_pan': normalized,
            'client_name': data['client_pan'] ?? normalized,
            'snapshot': null,
            'action_items': const <dynamic>[],
            'message': data['message'],
          }),
        );
      }
      return DashboardResult.failure(
        resp.errorMessage ?? 'Failed to load client detail',
      );
    }
    return DashboardResult.success(
      ClientDetail.fromJson((resp.data as Map).cast<String, dynamic>()),
    );
  }

  /// `PUT /api/dashboard/action/<item_id>` with body `{ "status": "..." }`
  Future<DashboardResult<ActionItem>> updateActionStatus(
    String itemId, {
    required String status,
  }) async {
    final normalized = itemId.trim();
    if (normalized.isEmpty) {
      return DashboardResult.failure('item_id is required');
    }
    final resp = await _api.put(
      '/api/dashboard/action/${Uri.encodeComponent(normalized)}',
      {'status': status},
    );
    if (!resp.success) {
      return DashboardResult.failure(
        resp.errorMessage ?? 'Failed to update action status',
      );
    }
    final data = (resp.data as Map).cast<String, dynamic>();
    final action = data['action'];
    if (action is Map) {
      return DashboardResult.success(
        ActionItem.fromJson(action.cast<String, dynamic>()),
      );
    }
    // Fallback: synthesise from the body so the UI can still re-render.
    return DashboardResult.success(
      ActionItem(
        itemId: normalized,
        dimension: 'unknown',
        urgency: ActionUrgency.unknown,
        finalStatus: status.toUpperCase(),
      ),
    );
  }

  /// `GET /api/dashboard/annual?period=...`
  Future<DashboardResult<AnnualMetrics>> getAnnual({String? period}) async {
    final endpoint = period == null || period.isEmpty
        ? '/api/dashboard/annual'
        : '/api/dashboard/annual?period=${Uri.encodeQueryComponent(period)}';
    final resp = await _api.get(endpoint);
    return _wrap(resp, (data) => AnnualMetrics.fromJson(data));
  }

  // ---------------------------------------------------------------------------

  DashboardResult<T> _wrap<T>(
    ApiResponse resp,
    T Function(Map<String, dynamic> data) builder,
  ) {
    if (!resp.success) {
      return DashboardResult.failure(
        resp.errorMessage ?? 'Request failed',
      );
    }
    if (resp.data is! Map) {
      return DashboardResult.failure('Unexpected response from server');
    }
    return DashboardResult.success(
      builder((resp.data as Map).cast<String, dynamic>()),
    );
  }
}

/// Lightweight result wrapper so we can return either a parsed payload
/// or a friendly error message without throwing.
class DashboardResult<T> {
  final T? data;
  final String? error;

  const DashboardResult._({this.data, this.error});

  factory DashboardResult.success(T data) =>
      DashboardResult._(data: data);

  factory DashboardResult.failure(String error) =>
      DashboardResult._(error: error);

  bool get isSuccess => data != null;
  bool get isFailure => error != null;
}
