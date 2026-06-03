import 'package:flutter/foundation.dart';

/// ------------------------------------------------------------------
/// Aggregate metrics returned by `GET /api/dashboard/overview`.
/// ------------------------------------------------------------------

@immutable
class DashboardMetrics {
  final double totalOpportunity;
  final double converted;
  final double pending;
  final double missedQuarter;
  final int actionCount;
  final int missedQuarterDays;
  final List<CategoryMetric> categories;

  const DashboardMetrics({
    required this.totalOpportunity,
    required this.converted,
    required this.pending,
    required this.missedQuarter,
    required this.actionCount,
    required this.missedQuarterDays,
    required this.categories,
  });

  factory DashboardMetrics.fromJson(Map<String, dynamic> json) {
    final cats = (json['categories'] as List?)
            ?.whereType<Map>()
            .map((c) => CategoryMetric.fromJson(c.cast<String, dynamic>()))
            .toList() ??
        const <CategoryMetric>[];

    return DashboardMetrics(
      totalOpportunity: _asDouble(json['total_opportunity']),
      converted: _asDouble(json['converted']),
      pending: _asDouble(json['pending']),
      missedQuarter: _asDouble(json['missed_quarter']),
      actionCount: _asInt(json['action_count']),
      missedQuarterDays: _asInt(json['missed_quarter_days']) == 0
          ? 90
          : _asInt(json['missed_quarter_days']),
      categories: cats,
    );
  }
}

@immutable
class CategoryMetric {
  final String dimension;
  final double totalOpportunity;
  final double converted;
  final double pending;
  final double missedQuarter;
  final int actionCount;

  const CategoryMetric({
    required this.dimension,
    required this.totalOpportunity,
    required this.converted,
    required this.pending,
    required this.missedQuarter,
    required this.actionCount,
  });

  factory CategoryMetric.fromJson(Map<String, dynamic> json) {
    return CategoryMetric(
      dimension: (json['dimension'] ?? 'uncategorized').toString(),
      totalOpportunity: _asDouble(json['total_opportunity']),
      converted: _asDouble(json['converted']),
      pending: _asDouble(json['pending']),
      missedQuarter: _asDouble(json['missed_quarter']),
      actionCount: _asInt(json['action_count']),
    );
  }

  /// Converted share (0.0 – 1.0) within this category. Safe for empty data.
  double get conversionRatio {
    if (totalOpportunity <= 0) return 0.0;
    return (converted / totalOpportunity).clamp(0.0, 1.0);
  }
}

/// ------------------------------------------------------------------
/// One row in the active reports list (overview response).
/// ------------------------------------------------------------------

@immutable
class ActiveReport {
  final int? id;
  final String clientPan;
  final String? clientName;
  final String? generatedAt;
  final String? expiresAt;
  final String? pdfFilename;
  final String? status;

  const ActiveReport({
    required this.clientPan,
    this.id,
    this.clientName,
    this.generatedAt,
    this.expiresAt,
    this.pdfFilename,
    this.status,
  });

  factory ActiveReport.fromJson(Map<String, dynamic> json) {
    return ActiveReport(
      id: json['id'] is int ? json['id'] as int : null,
      clientPan: (json['client_pan'] ?? '').toString(),
      clientName: json['client_name']?.toString(),
      generatedAt: json['generated_at']?.toString(),
      expiresAt: json['expires_at']?.toString(),
      pdfFilename: json['pdf_filename']?.toString(),
      status: json['status']?.toString(),
    );
  }

  /// Days until expiry, derived from `expires_at` (ISO 8601).
  /// Negative if already expired. `null` if no expiry set.
  int? get daysUntilExpiry {
    final raw = expiresAt;
    if (raw == null || raw.isEmpty) return null;
    final dt = DateTime.tryParse(raw);
    if (dt == null) return null;
    final now = DateTime.now().toUtc();
    final exp = dt.toUtc();
    return exp.difference(now).inDays;
  }

  /// Display name, falls back to PAN if name is missing.
  String get displayName =>
      (clientName == null || clientName!.isEmpty) ? clientPan : clientName!;
}

/// ------------------------------------------------------------------
/// Full overview response from `GET /api/dashboard/overview`.
/// ------------------------------------------------------------------

@immutable
class DashboardOverview {
  final String? mfdFirebaseUid;
  final DashboardMetrics metrics;
  final List<ActiveReport> activeReports;
  final int activeReportCount;

  const DashboardOverview({
    required this.metrics,
    required this.activeReports,
    this.mfdFirebaseUid,
    this.activeReportCount = 0,
  });

  factory DashboardOverview.fromJson(Map<String, dynamic> json) {
    final metricsJson =
        (json['metrics'] as Map?)?.cast<String, dynamic>() ?? const {};
    final reports = (json['active_reports'] as List?)
            ?.whereType<Map>()
            .map((r) => ActiveReport.fromJson(r.cast<String, dynamic>()))
            .toList() ??
        const <ActiveReport>[];
    return DashboardOverview(
      mfdFirebaseUid: json['mfd_firebase_uid']?.toString(),
      metrics: DashboardMetrics.fromJson(metricsJson),
      activeReports: reports,
      activeReportCount: _asInt(json['active_report_count']).clamp(0, 1 << 30),
    );
  }
}

/// ------------------------------------------------------------------
/// Client detail snapshot + action items.
/// ------------------------------------------------------------------

@immutable
class OverallHealth {
  final num? score;
  final String? label;

  const OverallHealth({this.score, this.label});

  factory OverallHealth.fromJson(Map<String, dynamic> json) {
    return OverallHealth(
      score: json['score'] is num ? json['score'] as num : null,
      label: json['label']?.toString(),
    );
  }
}

@immutable
class DimensionScore {
  final num? score;
  final String? label;
  final String? priority;

  const DimensionScore({this.score, this.label, this.priority});

  factory DimensionScore.fromJson(Map<String, dynamic> json) {
    return DimensionScore(
      score: json['score'] is num ? json['score'] as num : null,
      label: json['label']?.toString(),
      priority: json['priority']?.toString(),
    );
  }
}

@immutable
class ClientSnapshot {
  final String? clientName;
  final num? clientAge;
  final String? riskProfile;
  final OverallHealth overallHealth;
  final Map<String, DimensionScore> dimensions;
  final Map<String, dynamic> headlineIndicators;
  final Map<String, dynamic> diagnostics;
  final List<String> flags;
  final List<String> recommendations;
  final String? generatedAt;

  const ClientSnapshot({
    this.clientName,
    this.clientAge,
    this.riskProfile,
    this.overallHealth = const OverallHealth(),
    this.dimensions = const {},
    this.headlineIndicators = const {},
    this.diagnostics = const {},
    this.flags = const [],
    this.recommendations = const [],
    this.generatedAt,
  });

  factory ClientSnapshot.fromJson(Map<String, dynamic> json) {
    final dims = <String, DimensionScore>{};
    final rawDims = json['dimensions'];
    if (rawDims is Map) {
      rawDims.forEach((k, v) {
        if (v is Map) {
          dims[k.toString()] =
              DimensionScore.fromJson(v.cast<String, dynamic>());
        }
      });
    }

    return ClientSnapshot(
      clientName: json['client_name']?.toString(),
      clientAge: json['client_age'] is num ? json['client_age'] as num : null,
      riskProfile: json['risk_profile']?.toString(),
      overallHealth: OverallHealth.fromJson(
        (json['overall_health'] as Map?)?.cast<String, dynamic>() ??
            const {},
      ),
      dimensions: dims,
      headlineIndicators:
          (json['headline_indicators'] as Map?)?.cast<String, dynamic>() ??
              const {},
      diagnostics: (json['diagnostics'] as Map?)?.cast<String, dynamic>() ??
          const {},
      flags: (json['flags'] as List?)?.map((e) => e.toString()).toList() ??
          const [],
      recommendations:
          (json['recommendations'] as List?)?.map((e) => e.toString()).toList() ??
              const [],
      generatedAt: json['generated_at']?.toString(),
    );
  }
}

enum ActionUrgency { immediate, high, maintain, unknown }

ActionUrgency _parseUrgency(String? raw) {
  switch ((raw ?? '').toUpperCase()) {
    case 'IMMEDIATE':
      return ActionUrgency.immediate;
    case 'HIGH':
      return ActionUrgency.high;
    case 'MAINTAIN':
      return ActionUrgency.maintain;
    default:
      return ActionUrgency.unknown;
  }
}

@immutable
class ActionItem {
  final String itemId;
  final String dimension;
  final ActionUrgency urgency;
  final String? valueType;
  final num? valueNum;
  final String? title;
  final String? description;
  final String? finalStatus;

  const ActionItem({
    required this.itemId,
    required this.dimension,
    required this.urgency,
    this.valueType,
    this.valueNum,
    this.title,
    this.description,
    this.finalStatus,
  });

  bool get isConverted =>
      (finalStatus ?? '').toUpperCase() == 'CONVERTED';

  factory ActionItem.fromJson(Map<String, dynamic> json) {
    return ActionItem(
      itemId: (json['item_id'] ?? '').toString(),
      dimension: (json['dimension'] ?? 'general').toString(),
      urgency: _parseUrgency(json['urgency']?.toString()),
      valueType: json['value_type']?.toString(),
      valueNum:
          json['value_num'] is num ? json['value_num'] as num : null,
      title: json['title']?.toString(),
      description: json['description']?.toString(),
      finalStatus: json['final_status']?.toString(),
    );
  }
}

@immutable
class ClientDetail {
  final int? reportId;
  final String clientPan;
  final String? clientName;
  final String? generatedAt;
  final String? expiresAt;
  final String? pdfFilename;
  final String? status;
  final ClientSnapshot? snapshot;
  final List<ActionItem> actionItems;

  const ClientDetail({
    required this.clientPan,
    this.reportId,
    this.clientName,
    this.generatedAt,
    this.expiresAt,
    this.pdfFilename,
    this.status,
    this.snapshot,
    this.actionItems = const [],
  });

  String get displayName =>
      (clientName == null || clientName!.isEmpty) ? clientPan : clientName!;

  factory ClientDetail.fromJson(Map<String, dynamic> json) {
    final snap = json['snapshot'];
    final items = (json['action_items'] as List?)
            ?.whereType<Map>()
            .map((e) => ActionItem.fromJson(e.cast<String, dynamic>()))
            .toList() ??
        const <ActionItem>[];
    return ClientDetail(
      reportId: json['report_id'] is int ? json['report_id'] as int : null,
      clientPan: (json['client_pan'] ?? '').toString(),
      clientName: json['client_name']?.toString(),
      generatedAt: json['generated_at']?.toString(),
      expiresAt: json['expires_at']?.toString(),
      pdfFilename: json['pdf_filename']?.toString(),
      status: json['status']?.toString(),
      snapshot: snap is Map
          ? ClientSnapshot.fromJson(snap.cast<String, dynamic>())
          : null,
      actionItems: items,
    );
  }
}

/// ------------------------------------------------------------------
/// Annual / period summary from `GET /api/dashboard/annual`.
/// ------------------------------------------------------------------

@immutable
class AnnualMetrics {
  final String period;
  final String? periodStart;
  final String? periodEnd;
  final double totalIdentifiedValue;
  final int totalIdentifiedCount;
  final double convertedValue;
  final int convertedCount;
  final double pendingValue;
  final double conversionPct;

  const AnnualMetrics({
    required this.period,
    required this.totalIdentifiedValue,
    required this.totalIdentifiedCount,
    required this.convertedValue,
    required this.convertedCount,
    required this.pendingValue,
    required this.conversionPct,
    this.periodStart,
    this.periodEnd,
  });

  double get conversionRatio => (conversionPct / 100.0).clamp(0.0, 1.0);

  factory AnnualMetrics.fromJson(Map<String, dynamic> json) {
    return AnnualMetrics(
      period: (json['period'] ?? '365d').toString(),
      periodStart: json['period_start']?.toString(),
      periodEnd: json['period_end']?.toString(),
      totalIdentifiedValue: _asDouble(json['total_identified_value']),
      totalIdentifiedCount: _asInt(json['total_identified_count']),
      convertedValue: _asDouble(json['converted_value']),
      convertedCount: _asInt(json['converted_count']),
      pendingValue: _asDouble(json['pending_value']),
      conversionPct: _asDouble(json['conversion_pct']).clamp(0.0, 100.0),
    );
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

double _asDouble(dynamic v) {
  if (v == null) return 0.0;
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? 0.0;
  return 0.0;
}

int _asInt(dynamic v) {
  if (v == null) return 0;
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? 0;
  return 0;
}
