import 'package:flutter/material.dart';
import 'package:frontend/app_theme.dart';
import 'package:frontend/models/dashboard_models.dart';
import 'package:frontend/screens/dashboard/widgets/dashboard_widgets.dart';
import 'package:frontend/services/dashboard_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:frontend/constants.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'annual_impact_screen.dart';
import 'client_detail_screen.dart';

/// `/dashboard` — the Practice Overview.
///
/// Calls `GET /api/dashboard/overview` and renders:
///   • A horizontally-scrolling row of aggregate metric cards
///   • Per-category progress bars
///   • A data table of active client reports sorted by nearest expiry
class PracticeOverviewScreen extends StatefulWidget {
  const PracticeOverviewScreen({super.key});

  @override
  State<PracticeOverviewScreen> createState() =>
      _PracticeOverviewScreenState();
}

class _PracticeOverviewScreenState extends State<PracticeOverviewScreen> {
  late Future<DashboardResult<DashboardOverview>> _overviewFuture;

  @override
  void initState() {
    super.initState();
    _overviewFuture = _load();
  }

  Future<DashboardResult<DashboardOverview>> _load() {
    final svc = context.read<DashboardService>();
    return svc.getOverview();
  }

  Future<void> _refresh() async {
    setState(() {
      _overviewFuture = _load();
    });
    await _overviewFuture;
  }

  Future<void> _downloadPdf(String filename) async {
    // The dashboard backend serves PDFs under /download/<filename>.
    final uri = Uri.parse('$kBackendUrl/download/$filename');
    final ok = await canLaunchUrl(uri);
    if (!ok) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void _openClient(BuildContext context, ActiveReport report) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ClientDetailScreen(clientPan: report.clientPan),
        settings: RouteSettings(name: '/dashboard/client/${report.clientPan}'),
      ),
    );
  }

  void _openAnnual(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const AnnualImpactScreen(),
        settings: const RouteSettings(name: '/dashboard/annual'),
      ),
    );
  }

  void _openCategory(BuildContext context, CategoryMetric metric) {
    final svc = context.read<DashboardService>();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CategoryBreakdownSheet(
        metric: metric,
        breakdownFuture: svc.getCategoryBreakdown(metric.dimension),
        onOpenClient: (pan) {
          Navigator.of(context).pop();
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ClientDetailScreen(clientPan: pan),
              settings: RouteSettings(name: '/dashboard/client/$pan'),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundCream,
      appBar: DashboardTopBar(
        title: 'Practice Dashboard',
        subtitle: 'Opportunities, follow-ups and conversion insights',
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded,
                color: AppTheme.accentGold),
            onPressed: _refresh,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        color: AppTheme.accentGold,
        child: FutureBuilder<DashboardResult<DashboardOverview>>(
          future: _overviewFuture,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const _LoadingState();
            }
            if (snap.hasError) {
              return _ErrorState(
                message: 'Failed to load dashboard',
                detail: snap.error.toString(),
                onRetry: _refresh,
              );
            }
            final result = snap.data;
            if (result == null) {
              return const _LoadingState();
            }
            if (result.isFailure) {
              return _ErrorState(
                message: 'Could not load dashboard',
                detail: result.error,
                onRetry: _refresh,
              );
            }
            return _OverviewBody(
              overview: result.data!,
              onOpenClient: (r) => _openClient(context, r),
              onDownload: (f) => _downloadPdf(f),
              onOpenAnnual: () => _openAnnual(context),
              onOpenCategory: (m) => _openCategory(context, m),
            );
          },
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Body
// ---------------------------------------------------------------------------

class _OverviewBody extends StatelessWidget {
  final DashboardOverview overview;
  final void Function(ActiveReport) onOpenClient;
  final void Function(String filename) onDownload;
  final VoidCallback onOpenAnnual;
  final void Function(CategoryMetric) onOpenCategory;

  const _OverviewBody({
    required this.overview,
    required this.onOpenClient,
    required this.onDownload,
    required this.onOpenAnnual,
    required this.onOpenCategory,
  });

  @override
  Widget build(BuildContext context) {
    final metrics = overview.metrics;
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(32, 28, 32, 64),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SectionHeader(
            eyebrow: 'OVERVIEW',
            title: 'Your practice at a glance',
            subtitle:
                '${overview.activeReportCount} active client '
                '${overview.activeReportCount == 1 ? "report" : "reports"}',
            trailing: Padding(
              padding: const EdgeInsets.only(top: 6.0),
              child: OutlinedButton.icon(
                onPressed: onOpenAnnual,
                icon: const Icon(Icons.bar_chart_rounded, size: 16),
                label: const Text('Annual impact'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.primaryNavy,
                  side: const BorderSide(color: Color(0xFFE6E0D2)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                  textStyle: GoogleFonts.dmSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          // Aggregate metric cards (horizontally scrollable)
          _AggregateMetricsRow(metrics: metrics),
          const SizedBox(height: 36),
          // Category progress bars
          _CategoryProgress(
            categories: metrics.categories,
            onTapCategory: onOpenCategory,
          ),
          const SizedBox(height: 36),
          // Active reports table
          _SectionHeader(
            eyebrow: 'CLIENTS',
            title: 'Active client reports',
            subtitle: 'Sorted by nearest expiry',
          ),
          const SizedBox(height: 20),
          _ActiveReportsTable(
            reports: overview.activeReports,
            onOpenClient: onOpenClient,
            onDownload: onDownload,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Aggregate metric row
// ---------------------------------------------------------------------------

class _AggregateMetricsRow extends StatelessWidget {
  final DashboardMetrics metrics;
  const _AggregateMetricsRow({required this.metrics});

  @override
  Widget build(BuildContext context) {
    final cards = <AggregateMetricCard>[
      AggregateMetricCard(
        label: 'TOTAL OPPORTUNITY',
        value: metrics.totalOpportunity,
        accent: AppTheme.primaryNavy,
        icon: Icons.bolt_rounded,
        footnote:
            '${metrics.actionCount} active action ${metrics.actionCount == 1 ? "item" : "items"}',
      ),
      AggregateMetricCard(
        label: 'CONVERTED',
        value: metrics.converted,
        accent: AppTheme.successGreen,
        icon: Icons.check_circle_rounded,
        footnote: _ratio(metrics.converted, metrics.totalOpportunity),
      ),
      AggregateMetricCard(
        label: 'PENDING',
        value: metrics.pending,
        accent: AppTheme.accentGold,
        icon: Icons.schedule_rounded,
        footnote: _ratio(metrics.pending, metrics.totalOpportunity),
      ),
      AggregateMetricCard(
        label: 'MISSED QUARTER',
        value: metrics.missedQuarter,
        accent: AppTheme.errorRed,
        icon: Icons.warning_amber_rounded,
        footnote: '> ${metrics.missedQuarterDays} days pending',
      ),
    ];

    return SizedBox(
      height: 168,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: cards.length,
        separatorBuilder: (_, __) => const SizedBox(width: 16),
        itemBuilder: (context, i) {
          return SizedBox(
            width: 260,
            child: cards[i],
          );
        },
      ),
    );
  }

  static String _ratio(double a, double b) {
    if (b <= 0) return '0% of total';
    final pct = (a / b) * 100;
    return '${pct.toStringAsFixed(0)}% of total';
  }
}

// ---------------------------------------------------------------------------
// Category progress
// ---------------------------------------------------------------------------

class _CategoryProgress extends StatelessWidget {
  final List<CategoryMetric> categories;
  final void Function(CategoryMetric) onTapCategory;
  const _CategoryProgress({
    required this.categories,
    required this.onTapCategory,
  });

  @override
  Widget build(BuildContext context) {
    if (categories.isEmpty) {
      return const _EmptyCard(
        icon: Icons.donut_large_rounded,
        title: 'No categories yet',
        subtitle:
            'Categories will appear here once you generate client reports.',
      );
    }
    final maxVal = categories
        .map((c) => c.totalOpportunity)
        .fold<double>(0, (a, b) => a > b ? a : b);
    return GlassPanel(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Category progress',
            style: GoogleFonts.playfairDisplay(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppTheme.primaryNavy,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Opportunity value (₹) across practice categories — tap a category to see the client breakdown',
            style: GoogleFonts.dmSans(
              fontSize: 13,
              color: AppTheme.textLight,
            ),
          ),
          const SizedBox(height: 22),
          for (var i = 0; i < categories.length; i++) ...[
            _CategoryRow(
              metric: categories[i],
              maxValue: maxVal,
              onTap: () => onTapCategory(categories[i]),
            ),
            if (i != categories.length - 1) const SizedBox(height: 18),
          ],
        ],
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  final CategoryMetric metric;
  final double maxValue;
  final VoidCallback onTap;
  const _CategoryRow({
    required this.metric,
    required this.maxValue,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final progress = maxValue <= 0 ? 0.0 : (metric.totalOpportunity / maxValue);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: _categoryColor(metric.dimension),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _prettify(metric.dimension),
                style: GoogleFonts.dmSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textDark,
                ),
              ),
            ),
            Text(
              _formatRupees(metric.totalOpportunity),
              style: GoogleFonts.dmSans(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppTheme.primaryNavy,
              ),
            ),
            const SizedBox(width: 6),
            const Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: AppTheme.textLight,
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Stack(
            children: [
              Container(
                height: 8,
                color: AppTheme.borderLight.withValues(alpha: 0.4),
              ),
              FractionallySizedBox(
                widthFactor: progress.clamp(0.0, 1.0),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.easeOutCubic,
                  height: 8,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        _categoryColor(metric.dimension),
                        _categoryColor(metric.dimension)
                            .withValues(alpha: 0.65),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Text(
              'Converted: ${_formatRupees(metric.converted)}',
              style: GoogleFonts.dmSans(
                fontSize: 12,
                color: AppTheme.successGreen,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 16),
            Text(
              'Pending: ${_formatRupees(metric.pending)}',
              style: GoogleFonts.dmSans(
                fontSize: 12,
                color: AppTheme.accentGold,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            Text(
              '${metric.actionCount} items',
              style: GoogleFonts.dmSans(
                fontSize: 12,
                color: AppTheme.textLight,
              ),
            ),
          ],
        ),
      ],
      ),
    );
  }
}

Color _categoryColor(String dimension) {
  switch (dimension.toLowerCase()) {
    case 'protection':
      return AppTheme.errorRed;
    case 'liquidity':
      return const Color(0xFF3F88C5);
    case 'debt_management':
      return const Color(0xFF7E57C2);
    case 'savings':
      return AppTheme.successGreen;
    case 'portfolio_health':
      return AppTheme.accentGold;
    case 'tax':
      return const Color(0xFFE07A5F);
    default:
      return AppTheme.primaryNavy;
  }
}

String _prettify(String dim) {
  return dim
      .replaceAll('_', ' ')
      .split(' ')
      .where((p) => p.isNotEmpty)
      .map((p) => p[0].toUpperCase() + p.substring(1))
      .join(' ');
}

// ---------------------------------------------------------------------------
// Category client-breakdown sheet
// ---------------------------------------------------------------------------

/// Bottom sheet shown when a category row (e.g. Protection) is tapped.
/// Lists every client contributing to the category total and their amount,
/// with a tap-through to the client detail screen.
class CategoryBreakdownSheet extends StatelessWidget {
  final CategoryMetric metric;
  final Future<DashboardResult<CategoryBreakdown>> breakdownFuture;
  final void Function(String clientPan) onOpenClient;

  const CategoryBreakdownSheet({
    super.key,
    required this.metric,
    required this.breakdownFuture,
    required this.onOpenClient,
  });

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.of(context).size.height * 0.75;
    final color = _categoryColor(metric.dimension);
    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: const BoxDecoration(
        color: AppTheme.backgroundCream,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.borderLight,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 18, 24, 14),
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _prettify(metric.dimension),
                          style: GoogleFonts.playfairDisplay(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.primaryNavy,
                          ),
                        ),
                        Text(
                          'Clients contributing to this category',
                          style: GoogleFonts.dmSans(
                            fontSize: 12,
                            color: AppTheme.textLight,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    _formatRupees(metric.totalOpportunity),
                    style: GoogleFonts.dmSans(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primaryNavy,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFEAE6DE)),
            Flexible(
              child: FutureBuilder<DashboardResult<CategoryBreakdown>>(
                future: breakdownFuture,
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.all(40),
                      child: Center(
                        child: CircularProgressIndicator(
                            color: AppTheme.accentGold),
                      ),
                    );
                  }
                  final result = snap.data;
                  if (snap.hasError ||
                      result == null ||
                      result.isFailure) {
                    return Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        result?.error ??
                            snap.error?.toString() ??
                            'Could not load client breakdown',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.dmSans(
                          fontSize: 13,
                          color: AppTheme.textLight,
                        ),
                      ),
                    );
                  }
                  final clients = result.data!.clients;
                  if (clients.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        'No client opportunities in this category yet.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.dmSans(
                          fontSize: 13,
                          color: AppTheme.textLight,
                        ),
                      ),
                    );
                  }
                  return ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
                    itemCount: clients.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1, color: Color(0xFFF1EDE5)),
                    itemBuilder: (context, i) => _BreakdownClientTile(
                      entry: clients[i],
                      accent: color,
                      onTap: () => onOpenClient(clients[i].clientPan),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BreakdownClientTile extends StatelessWidget {
  final CategoryClientEntry entry;
  final Color accent;
  final VoidCallback onTap;
  const _BreakdownClientTile({
    required this.entry,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(19),
              ),
              child: Center(
                child: Text(
                  _initials(entry.displayName),
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primaryNavy,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.displayName,
                    style: GoogleFonts.dmSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primaryNavy,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'PAN ${entry.clientPan} · '
                    '${entry.actionCount} ${entry.actionCount == 1 ? "item" : "items"}',
                    style: GoogleFonts.dmSans(
                      fontSize: 11,
                      color: AppTheme.textLight,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _formatRupees(entry.totalOpportunity),
                  style: GoogleFonts.dmSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primaryNavy,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  entry.pending > 0
                      ? 'Pending ${_formatRupees(entry.pending)}'
                      : 'Converted ${_formatRupees(entry.converted)}',
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: entry.pending > 0
                        ? AppTheme.accentGold
                        : AppTheme.successGreen,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: AppTheme.textLight,
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Active reports table
// ---------------------------------------------------------------------------

class _ActiveReportsTable extends StatelessWidget {
  final List<ActiveReport> reports;
  final void Function(ActiveReport) onOpenClient;
  final void Function(String filename) onDownload;
  const _ActiveReportsTable({
    required this.reports,
    required this.onOpenClient,
    required this.onDownload,
  });

  @override
  Widget build(BuildContext context) {
    if (reports.isEmpty) {
      return const _EmptyCard(
        icon: Icons.assignment_outlined,
        title: 'No active client reports',
        subtitle:
            'Generate a financial plan for a client to see it appear here.',
      );
    }
    return GlassPanel(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 0),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth > 760;
          if (isWide) {
            return _WideTable(
              reports: reports,
              onOpenClient: onOpenClient,
              onDownload: onDownload,
            );
          }
          return _MobileList(
            reports: reports,
            onOpenClient: onOpenClient,
            onDownload: onDownload,
          );
        },
      ),
    );
  }
}

class _WideTable extends StatelessWidget {
  final List<ActiveReport> reports;
  final void Function(ActiveReport) onOpenClient;
  final void Function(String filename) onDownload;
  const _WideTable({
    required this.reports,
    required this.onOpenClient,
    required this.onDownload,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _TableHeaderRow(),
        const Divider(height: 1, color: Color(0xFFEAE6DE)),
        for (final r in reports) ...[
          _TableDataRow(
            report: r,
            onOpenClient: () => onOpenClient(r),
            onDownload: () {
              if (r.pdfFilename != null) onDownload(r.pdfFilename!);
            },
          ),
          if (r != reports.last)
            const Divider(height: 1, color: Color(0xFFF1EDE5)),
        ],
      ],
    );
  }
}

class _TableHeaderRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const style = TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w700,
      letterSpacing: 1.0,
      color: AppTheme.textLight,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      child: Row(
        children: const [
          Expanded(flex: 4, child: Text('CLIENT', style: style)),
          Expanded(flex: 2, child: Text('GENERATED', style: style)),
          Expanded(flex: 2, child: Text('EXPIRES', style: style)),
          Expanded(flex: 3, child: Text('OPPORTUNITY', style: style)),
          Expanded(flex: 3, child: Text('ACTIONS', style: style)),
        ],
      ),
    );
  }
}

class _TableDataRow extends StatelessWidget {
  final ActiveReport report;
  final VoidCallback onOpenClient;
  final VoidCallback onDownload;
  const _TableDataRow({
    required this.report,
    required this.onOpenClient,
    required this.onDownload,
  });

  @override
  Widget build(BuildContext context) {
    final days = report.daysUntilExpiry;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: InkWell(
              onTap: onOpenClient,
              borderRadius: BorderRadius.circular(4),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppTheme.accentGold.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Center(
                      child: Text(
                        _initials(report.displayName),
                        style: GoogleFonts.dmSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primaryNavy,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          report.displayName,
                          style: GoogleFonts.dmSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.primaryNavy,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'PAN ${report.clientPan}',
                          style: GoogleFonts.dmSans(
                            fontSize: 12,
                            color: AppTheme.textLight,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              _formatDate(report.generatedAt),
              style: GoogleFonts.dmSans(
                fontSize: 13,
                color: AppTheme.textMedium,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: _ExpiryChip(days: days),
          ),
          Expanded(
            flex: 3,
            child: _OpportunityCell(report: report),
          ),
          Expanded(
            flex: 3,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _RowActionButton(
                  label: 'View actions',
                  icon: Icons.task_alt_rounded,
                  onPressed: onOpenClient,
                  emphasized: true,
                ),
                const SizedBox(width: 8),
                _RowActionButton(
                  label: 'Download PDF',
                  icon: Icons.file_download_rounded,
                  onPressed: onDownload,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact per-client opportunity summary shown in the active reports table.
/// Shows the total opportunity (cover + SIP) plus a tiny breakdown of the
/// two most important gaps so the MFD can decide at a glance who to call.
class _OpportunityCell extends StatelessWidget {
  final ActiveReport report;
  const _OpportunityCell({required this.report});

  @override
  Widget build(BuildContext context) {
    final total = report.totalOpportunityInr;
    if (total <= 0 && !report.hasSummary) {
      return Text(
        '—',
        style: GoogleFonts.dmSans(
          fontSize: 12,
          color: AppTheme.textLight,
        ),
      );
    }
    final lifeGap = report.lifeCoverGap?.toDouble() ?? 0;
    final healthGap = report.healthCoverGap?.toDouble() ?? 0;
    final sip = report.totalIdealSip?.toDouble() ?? 0;
    final goalPct = report.goalAchievementPct?.toDouble();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _formatRupees(total),
          style: GoogleFonts.dmSans(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppTheme.primaryNavy,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          _breakdown(lifeGap: lifeGap, healthGap: healthGap, sip: sip),
          style: GoogleFonts.dmSans(
            fontSize: 11,
            color: AppTheme.textLight,
            fontWeight: FontWeight.w500,
            height: 1.35,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        if (goalPct != null) ...[
          const SizedBox(height: 4),
          _GoalProgressBar(pct: goalPct),
        ],
      ],
    );
  }

  String _breakdown({
    required double lifeGap,
    required double healthGap,
    required double sip,
  }) {
    final parts = <String>[];
    if (lifeGap > 0) parts.add('Life ${_formatRupees(lifeGap)}');
    if (healthGap > 0) parts.add('Health ${_formatRupees(healthGap)}');
    if (sip > 0) parts.add('SIP ${_formatRupees(sip)}/mo');
    if (parts.isEmpty) {
      return 'On track';
    }
    return parts.join(' • ');
  }
}

class _GoalProgressBar extends StatelessWidget {
  final double pct;
  const _GoalProgressBar({required this.pct});

  @override
  Widget build(BuildContext context) {
    final ratio = (pct / 100).clamp(0.0, 1.0);
    final color = pct >= 75
        ? AppTheme.successGreen
        : (pct >= 40 ? AppTheme.accentGold : AppTheme.errorRed);
    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: Stack(
              children: [
                Container(
                  height: 4,
                  color: AppTheme.borderLight.withValues(alpha: 0.5),
                ),
                FractionallySizedBox(
                  widthFactor: ratio,
                  child: Container(
                    height: 4,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          '${pct.toStringAsFixed(0)}% goal',
          style: GoogleFonts.dmSans(
            fontSize: 10,
            color: color,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.4,
          ),
        ),
      ],
    );
  }
}

class _MobileList extends StatelessWidget {
  final List<ActiveReport> reports;
  final void Function(ActiveReport) onOpenClient;
  final void Function(String filename) onDownload;
  const _MobileList({
    required this.reports,
    required this.onOpenClient,
    required this.onDownload,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          for (final r in reports) ...[
            _MobileCard(
              report: r,
              onOpenClient: () => onOpenClient(r),
              onDownload: () {
                if (r.pdfFilename != null) onDownload(r.pdfFilename!);
              },
            ),
            if (r != reports.last) const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _MobileCard extends StatelessWidget {
  final ActiveReport report;
  final VoidCallback onOpenClient;
  final VoidCallback onDownload;
  const _MobileCard({
    required this.report,
    required this.onOpenClient,
    required this.onDownload,
  });

  @override
  Widget build(BuildContext context) {
    final days = report.daysUntilExpiry;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: const Color(0xFFEAE6DE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppTheme.accentGold.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Center(
                  child: Text(
                    _initials(report.displayName),
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primaryNavy,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      report.displayName,
                      style: GoogleFonts.dmSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primaryNavy,
                      ),
                    ),
                    Text(
                      'PAN ${report.clientPan}',
                      style: GoogleFonts.dmSans(
                        fontSize: 11,
                        color: AppTheme.textLight,
                      ),
                    ),
                  ],
                ),
              ),
              _ExpiryChip(days: days),
            ],
          ),
          if (report.hasSummary || report.totalOpportunityInr > 0) ...[
            const SizedBox(height: 10),
            _OpportunityCell(report: report),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _RowActionButton(
                  label: 'View actions',
                  icon: Icons.task_alt_rounded,
                  onPressed: onOpenClient,
                  emphasized: true,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _RowActionButton(
                  label: 'PDF',
                  icon: Icons.file_download_rounded,
                  onPressed: onDownload,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Atoms
// ---------------------------------------------------------------------------

class _SectionHeader extends StatelessWidget {
  final String eyebrow;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  const _SectionHeader({
    required this.eyebrow,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                eyebrow,
                style: GoogleFonts.dmSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.accentGold,
                  letterSpacing: 1.6,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                title,
                style: GoogleFonts.playfairDisplay(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primaryNavy,
                  height: 1.15,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle!,
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    color: AppTheme.textLight,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class _RowActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool emphasized;
  const _RowActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.emphasized = false,
  });

  @override
  Widget build(BuildContext context) {
    final bg = emphasized ? AppTheme.primaryNavy : Colors.transparent;
    final fg = emphasized ? Colors.white : AppTheme.primaryNavy;
    return TextButton.icon(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        backgroundColor: bg,
        foregroundColor: fg,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(2),
          side: BorderSide(
            color: emphasized
                ? AppTheme.primaryNavy
                : AppTheme.primaryNavy.withValues(alpha: 0.4),
          ),
        ),
        textStyle: GoogleFonts.dmSans(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.4,
        ),
      ),
      icon: Icon(icon, size: 14),
      label: Text(label),
    );
  }
}

class _ExpiryChip extends StatelessWidget {
  final int? days;
  const _ExpiryChip({required this.days});

  @override
  Widget build(BuildContext context) {
    String label;
    Color color;
    if (days == null) {
      label = 'No expiry';
      color = AppTheme.textLight;
    } else if (days! < 0) {
      label = 'Expired';
      color = AppTheme.errorRed;
    } else if (days! <= 7) {
      label = '$days d left';
      color = AppTheme.errorRed;
    } else if (days! <= 30) {
      label = '$days d left';
      color = const Color(0xFFE07A5F);
    } else {
      label = '$days d left';
      color = AppTheme.successGreen;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(2),
      ),
      child: Text(
        label,
        style: GoogleFonts.dmSans(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Loading / error / empty
// ---------------------------------------------------------------------------

class _LoadingState extends StatelessWidget {
  const _LoadingState();
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: AppTheme.accentGold),
          const SizedBox(height: 16),
          Text(
            'Loading practice insights…',
            style: GoogleFonts.dmSans(
              color: AppTheme.textLight,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final String? detail;
  final Future<void> Function() onRetry;
  const _ErrorState({
    required this.message,
    this.detail,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded,
                color: AppTheme.errorRed, size: 40),
            const SizedBox(height: 16),
            Text(
              message,
              style: GoogleFonts.playfairDisplay(
                fontSize: 22,
                color: AppTheme.primaryNavy,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (detail != null) ...[
              const SizedBox(height: 8),
              Text(
                detail!,
                textAlign: TextAlign.center,
                style: GoogleFonts.dmSans(
                  fontSize: 13,
                  color: AppTheme.textLight,
                ),
              ),
            ],
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const _EmptyCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 44),
      child: Column(
        children: [
          Icon(icon, color: AppTheme.textLight, size: 36),
          const SizedBox(height: 12),
          Text(
            title,
            style: GoogleFonts.playfairDisplay(
              fontSize: 20,
              color: AppTheme.primaryNavy,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: GoogleFonts.dmSans(
              fontSize: 13,
              color: AppTheme.textLight,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

String _formatRupees(double amount) {
  if (amount <= 0) return '₹0';
  if (amount >= 1e7) {
    return '₹${(amount / 1e7).toStringAsFixed(1)} Cr';
  }
  if (amount >= 1e5) {
    return '₹${(amount / 1e5).toStringAsFixed(1)} L';
  }
  if (amount >= 1e3) {
    return '₹${(amount / 1e3).toStringAsFixed(1)} K';
  }
  return '₹${amount.toStringAsFixed(0)}';
}

const _monthNames = [
  '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String _formatDate(String? iso) {
  if (iso == null || iso.isEmpty) return '—';
  final dt = DateTime.tryParse(iso);
  if (dt == null) return '—';
  final local = dt.toLocal();
  final m = _monthNames[local.month];
  return '${local.day} $m ${local.year}';
}

String _initials(String name) {
  final parts =
      name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
  return (parts.first.substring(0, 1) + parts[1].substring(0, 1))
      .toUpperCase();
}
