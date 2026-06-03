import 'package:flutter/material.dart';
import 'package:frontend/app_theme.dart';
import 'package:frontend/models/dashboard_models.dart';
import 'package:frontend/screens/dashboard/widgets/dashboard_widgets.dart';
import 'package:frontend/services/dashboard_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

/// `/dashboard/annual` — period selector + pie/progress rings showing
/// identified, converted and pending totals + conversion %.
class AnnualImpactScreen extends StatefulWidget {
  const AnnualImpactScreen({super.key});

  @override
  State<AnnualImpactScreen> createState() => _AnnualImpactScreenState();
}

class _AnnualImpactScreenState extends State<AnnualImpactScreen> {
  // Display label → API period string
  static const _options = <_PeriodOption>[
    _PeriodOption('Last 30 days', '30d'),
    _PeriodOption('Last 90 days', '90d'),
    _PeriodOption('Last 6 months', '6m'),
    _PeriodOption('Last 1 year', '1y'),
    _PeriodOption('Last 2 years', '2y'),
  ];

  _PeriodOption _selected = _options[3];
  late Future<DashboardResult<AnnualMetrics>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load(_selected.period);
  }

  Future<DashboardResult<AnnualMetrics>> _load(String period) {
    return context.read<DashboardService>().getAnnual(period: period);
  }

  Future<void> _changePeriod(_PeriodOption opt) async {
    if (opt.period == _selected.period) return;
    setState(() {
      _selected = opt;
      _future = _load(opt.period);
    });
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundCream,
      appBar: const DashboardTopBar(
        title: 'Annual Impact',
        subtitle: 'Conversion performance over time',
      ),
      body: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(32, 28, 32, 64),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _PeriodPicker(
              options: _options,
              selected: _selected,
              onChanged: _changePeriod,
            ),
            const SizedBox(height: 24),
            FutureBuilder<DashboardResult<AnnualMetrics>>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return _LoadingPanel();
                }
                if (snap.hasError) {
                  return _ErrorPanel(
                    message: 'Failed to load annual impact',
                    detail: snap.error.toString(),
                  );
                }
                final result = snap.data;
                if (result == null) return _LoadingPanel();
                if (result.isFailure) {
                  return _ErrorPanel(
                    message: 'Could not load annual impact',
                    detail: result.error,
                  );
                }
                return _AnnualBody(metrics: result.data!);
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Period picker
// ---------------------------------------------------------------------------

class _PeriodOption {
  final String label;
  final String period;
  const _PeriodOption(this.label, this.period);
}

class _PeriodPicker extends StatelessWidget {
  final List<_PeriodOption> options;
  final _PeriodOption selected;
  final Future<void> Function(_PeriodOption) onChanged;
  const _PeriodPicker({
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Row(
        children: [
          const Icon(Icons.timeline_rounded,
              color: AppTheme.accentGold, size: 20),
          const SizedBox(width: 12),
          Text(
            'Time period',
            style: GoogleFonts.dmSans(
              fontSize: 13,
              color: AppTheme.textLight,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final o in options) ...[
                    _Chip(
                      label: o.label,
                      active: o.period == selected.period,
                      onTap: () => onChanged(o),
                    ),
                    const SizedBox(width: 8),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _Chip({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(2),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: active
              ? AppTheme.primaryNavy
              : Colors.white.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(2),
          border: Border.all(
            color: active
                ? AppTheme.primaryNavy
                : AppTheme.borderLight.withValues(alpha: 0.5),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.dmSans(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: active ? Colors.white : AppTheme.textMedium,
            letterSpacing: 0.4,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Body
// ---------------------------------------------------------------------------

class _AnnualBody extends StatelessWidget {
  final AnnualMetrics metrics;
  const _AnnualBody({required this.metrics});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final isWide = c.maxWidth > 900;
        final pies = <Widget>[
          _ConversionRingCard(metrics: metrics),
          _ValueBreakdownCard(metrics: metrics),
        ];
        if (isWide) {
          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: pies[0]),
                const SizedBox(width: 20),
                Expanded(child: pies[1]),
              ],
            ),
          );
        }
        return Column(
          children: [
            pies[0],
            const SizedBox(height: 20),
            pies[1],
          ],
        );
      },
    );
  }
}

class _ConversionRingCard extends StatelessWidget {
  final AnnualMetrics metrics;
  const _ConversionRingCard({required this.metrics});

  @override
  Widget build(BuildContext context) {
    final pct = metrics.conversionPct;
    final ratio = metrics.conversionRatio;
    return GlassPanel(
      padding: const EdgeInsets.fromLTRB(28, 28, 28, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Conversion rate',
            style: GoogleFonts.playfairDisplay(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppTheme.primaryNavy,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Share of identified opportunity value that was converted',
            style: GoogleFonts.dmSans(
              fontSize: 13,
              color: AppTheme.textLight,
            ),
          ),
          const SizedBox(height: 24),
          Center(
            child: SizedBox(
              width: 220,
              height: 220,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  TweenAnimationBuilder<double>(
                    duration: const Duration(milliseconds: 900),
                    curve: Curves.easeOutCubic,
                    tween: Tween(begin: 0, end: ratio),
                    builder: (context, value, _) {
                      return CustomPaint(
                        size: const Size(220, 220),
                        painter: _PiePainter(
                          progress: value,
                          converted: AppTheme.successGreen,
                          pending: AppTheme.accentGold.withValues(alpha: 0.4),
                        ),
                      );
                    },
                  ),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '${pct.toStringAsFixed(1)}%',
                        style: GoogleFonts.playfairDisplay(
                          fontSize: 44,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primaryNavy,
                          height: 1.0,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'CONVERTED',
                        style: GoogleFonts.dmSans(
                          fontSize: 10,
                          color: AppTheme.textLight,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.4,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          _Legend(
            entries: [
              _LegendEntry(
                color: AppTheme.successGreen,
                label: 'Converted',
                value: metrics.convertedValue,
                sub: '${metrics.convertedCount} items',
              ),
              _LegendEntry(
                color: AppTheme.accentGold.withValues(alpha: 0.6),
                label: 'Pending',
                value: metrics.pendingValue,
                sub:
                    '${(metrics.totalIdentifiedCount - metrics.convertedCount).clamp(0, 1 << 30)} items',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LegendEntry {
  final Color color;
  final String label;
  final double value;
  final String sub;
  const _LegendEntry({
    required this.color,
    required this.label,
    required this.value,
    required this.sub,
  });
}

class _Legend extends StatelessWidget {
  final List<_LegendEntry> entries;
  const _Legend({required this.entries});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < entries.length; i++) ...[
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: entries[i].color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  entries[i].label,
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryNavy,
                  ),
                ),
              ),
              Text(
                _formatRupees(entries[i].value),
                style: GoogleFonts.dmSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primaryNavy,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(left: 20),
              child: Text(
                entries[i].sub,
                style: GoogleFonts.dmSans(
                  fontSize: 11,
                  color: AppTheme.textLight,
                ),
              ),
            ),
          ),
          if (i != entries.length - 1) const SizedBox(height: 14),
        ],
      ],
    );
  }
}

class _ValueBreakdownCard extends StatelessWidget {
  final AnnualMetrics metrics;
  const _ValueBreakdownCard({required this.metrics});

  @override
  Widget build(BuildContext context) {
    final maxVal = [
      metrics.totalIdentifiedValue,
      metrics.convertedValue,
      metrics.pendingValue,
    ].fold<double>(0, (a, b) => a > b ? a : b);
    final bars = <_Bar>[
      _Bar(
        label: 'Identified',
        value: metrics.totalIdentifiedValue,
        max: maxVal,
        color: AppTheme.primaryNavy,
        count: metrics.totalIdentifiedCount,
      ),
      _Bar(
        label: 'Converted',
        value: metrics.convertedValue,
        max: maxVal,
        color: AppTheme.successGreen,
        count: metrics.convertedCount,
      ),
      _Bar(
        label: 'Pending',
        value: metrics.pendingValue,
        max: maxVal,
        color: AppTheme.accentGold,
        count: (metrics.totalIdentifiedCount - metrics.convertedCount)
            .clamp(0, 1 << 30),
      ),
    ];

    return GlassPanel(
      padding: const EdgeInsets.fromLTRB(28, 28, 28, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Value breakdown',
            style: GoogleFonts.playfairDisplay(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppTheme.primaryNavy,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Opportunity, converted and pending values (₹) over '
            '${metrics.period}',
            style: GoogleFonts.dmSans(
              fontSize: 13,
              color: AppTheme.textLight,
            ),
          ),
          const SizedBox(height: 24),
          for (var i = 0; i < bars.length; i++) ...[
            _ProgressBar(bar: bars[i]),
            if (i != bars.length - 1) const SizedBox(height: 24),
          ],
          const SizedBox(height: 28),
          _SummaryTiles(metrics: metrics),
        ],
      ),
    );
  }
}

class _Bar {
  final String label;
  final double value;
  final double max;
  final Color color;
  final int count;
  const _Bar({
    required this.label,
    required this.value,
    required this.max,
    required this.color,
    required this.count,
  });
}

class _ProgressBar extends StatelessWidget {
  final _Bar bar;
  const _ProgressBar({required this.bar});

  @override
  Widget build(BuildContext context) {
    final progress = bar.max <= 0 ? 0.0 : (bar.value / bar.max);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: bar.color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                bar.label,
                style: GoogleFonts.dmSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textDark,
                ),
              ),
            ),
            Text(
              _formatRupees(bar.value),
              style: GoogleFonts.dmSans(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppTheme.primaryNavy,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Stack(
            children: [
              Container(
                height: 10,
                color: AppTheme.borderLight.withValues(alpha: 0.4),
              ),
              FractionallySizedBox(
                widthFactor: progress.clamp(0.0, 1.0),
                child: TweenAnimationBuilder<double>(
                  duration: const Duration(milliseconds: 700),
                  curve: Curves.easeOutCubic,
                  tween: Tween(begin: 0, end: 1),
                  builder: (context, t, _) {
                    return Container(
                      height: 10,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            bar.color.withValues(alpha: 0.7),
                            bar.color,
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '${bar.count} ${bar.count == 1 ? "action item" : "action items"}',
          style: GoogleFonts.dmSans(
            fontSize: 12,
            color: AppTheme.textLight,
          ),
        ),
      ],
    );
  }
}

class _SummaryTiles extends StatelessWidget {
  final AnnualMetrics metrics;
  const _SummaryTiles({required this.metrics});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: AppTheme.backgroundCream,
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: const Color(0xFFE6E0D2)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _Tile(
              label: 'PERIOD',
              value: metrics.period.toUpperCase(),
            ),
          ),
          const _Divider(),
          Expanded(
            child: _Tile(
              label: 'ITEMS',
              value: '${metrics.totalIdentifiedCount}',
            ),
          ),
          const _Divider(),
          Expanded(
            child: _Tile(
              label: 'CONVERTED',
              value: '${metrics.convertedCount}',
            ),
          ),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 28,
      color: const Color(0xFFE6E0D2),
    );
  }
}

class _Tile extends StatelessWidget {
  final String label;
  final String value;
  const _Tile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: GoogleFonts.dmSans(
            fontSize: 9,
            color: AppTheme.textLight,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.4,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.dmSans(
            fontSize: 16,
            color: AppTheme.primaryNavy,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Pie / progress painter
// ---------------------------------------------------------------------------

class _PiePainter extends CustomPainter {
  final double progress; // 0.0 - 1.0 (converted share)
  final Color converted;
  final Color pending;
  _PiePainter({
    required this.progress,
    required this.converted,
    required this.pending,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 12;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 18
      ..color = pending;
    canvas.drawCircle(center, radius, track);

    final fg = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 18
      ..shader = SweepGradient(
        startAngle: -1.5708,
        endAngle: 4.7124,
        colors: [converted.withValues(alpha: 0.7), converted],
      ).createShader(rect);

    final sweep = 6.2832 * progress.clamp(0.0, 1.0);
    canvas.drawArc(rect, -1.5708, sweep, false, fg);
  }

  @override
  bool shouldRepaint(covariant _PiePainter old) =>
      old.progress != progress ||
      old.converted != converted ||
      old.pending != pending;
}

// ---------------------------------------------------------------------------
// Loading / error
// ---------------------------------------------------------------------------

class _LoadingPanel extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 360,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: AppTheme.accentGold),
            const SizedBox(height: 16),
            Text(
              'Loading annual impact…',
              style: GoogleFonts.dmSans(
                color: AppTheme.textLight,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorPanel extends StatelessWidget {
  final String message;
  final String? detail;
  const _ErrorPanel({required this.message, this.detail});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 240,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_rounded,
                  color: AppTheme.errorRed, size: 36),
              const SizedBox(height: 12),
              Text(
                message,
                style: GoogleFonts.playfairDisplay(
                  fontSize: 20,
                  color: AppTheme.primaryNavy,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (detail != null) ...[
                const SizedBox(height: 6),
                Text(
                  detail!,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    color: AppTheme.textLight,
                  ),
                ),
              ],
            ],
          ),
        ),
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
    return '₹${(amount / 1e7).toStringAsFixed(2)} Cr';
  }
  if (amount >= 1e5) {
    return '₹${(amount / 1e5).toStringAsFixed(2)} L';
  }
  if (amount >= 1e3) {
    return '₹${(amount / 1e3).toStringAsFixed(1)} K';
  }
  return '₹${amount.toStringAsFixed(0)}';
}
