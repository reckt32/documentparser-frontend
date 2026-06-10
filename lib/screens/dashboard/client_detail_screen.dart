import 'package:flutter/material.dart';
import 'package:frontend/app_theme.dart';
import 'package:frontend/models/dashboard_models.dart';
import 'package:frontend/screens/dashboard/widgets/dashboard_widgets.dart';
import 'package:frontend/services/dashboard_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

/// `/dashboard/client/<pan>` — a client's snapshot + action items.
///
/// Calls `GET /api/dashboard/client/<pan>` and lets the MFD toggle each
/// IMMEDIATE / HIGH action to CONVERTED via `PUT /api/dashboard/action/<id>`.
class ClientDetailScreen extends StatefulWidget {
  final String clientPan;
  const ClientDetailScreen({super.key, required this.clientPan});

  @override
  State<ClientDetailScreen> createState() => _ClientDetailScreenState();
}

class _ClientDetailScreenState extends State<ClientDetailScreen> {
  late Future<DashboardResult<ClientDetail>> _future;
  // Local overlay of action statuses so toggles feel instant even before
  // the network round-trip completes. Keyed by `item_id`.
  final Map<String, bool> _converted = {};
  // Track which item_ids are currently being mutated.
  final Set<String> _pending = {};

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<DashboardResult<ClientDetail>> _load() {
    return context.read<DashboardService>().getClientDetail(widget.clientPan);
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _load();
    });
    await _future;
  }

  Future<void> _toggle(ActionItem item) async {
    if (_pending.contains(item.itemId)) return;
    final svc = context.read<DashboardService>();
    final newStatus = item.isConverted ? 'PENDING' : 'CONVERTED';

    setState(() {
      _pending.add(item.itemId);
      _converted[item.itemId] = newStatus == 'CONVERTED';
    });

    final result = await svc.updateActionStatus(
      item.itemId,
      status: newStatus,
    );

    if (!mounted) return;
    setState(() {
      _pending.remove(item.itemId);
    });

    if (result.isFailure) {
      // Rollback the optimistic change.
      setState(() {
        _converted.remove(item.itemId);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppTheme.primaryNavy,
          content: Text(
            result.error ?? 'Could not update action status',
            style: const TextStyle(color: Colors.white),
          ),
        ),
      );
    }
  }

  bool _isConverted(ActionItem item) {
    if (_converted.containsKey(item.itemId)) return _converted[item.itemId]!;
    return item.isConverted;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundCream,
      appBar: DashboardTopBar(
        title: widget.clientPan,
        subtitle: 'Client detail',
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
        child: FutureBuilder<DashboardResult<ClientDetail>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const _LoadingState();
            }
            if (snap.hasError) {
              return _ErrorState(
                message: 'Failed to load client',
                detail: snap.error.toString(),
                onRetry: _refresh,
              );
            }
            final result = snap.data;
            if (result == null) return const _LoadingState();
            if (result.isFailure) {
              return _ErrorState(
                message: 'Could not load client',
                detail: result.error,
                onRetry: _refresh,
              );
            }
            return _ClientBody(
              detail: result.data!,
              isConverted: _isConverted,
              isPending: (id) => _pending.contains(id),
              onToggle: _toggle,
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

class _ClientBody extends StatelessWidget {
  final ClientDetail detail;
  final bool Function(ActionItem) isConverted;
  final bool Function(String itemId) isPending;
  final Future<void> Function(ActionItem) onToggle;

  const _ClientBody({
    required this.detail,
    required this.isConverted,
    required this.isPending,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(32, 28, 32, 64),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ClientHeader(detail: detail),
          const SizedBox(height: 28),
          _DimensionsPanel(snapshot: detail.snapshot),
          const SizedBox(height: 28),
          _ProtectionSummary(snapshot: detail.snapshot),
          const SizedBox(height: 28),
          _ActionItemsSection(
            items: detail.actionItems,
            isConverted: isConverted,
            isPending: isPending,
            onToggle: onToggle,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Header
// ---------------------------------------------------------------------------

class _ClientHeader extends StatelessWidget {
  final ClientDetail detail;
  const _ClientHeader({required this.detail});

  @override
  Widget build(BuildContext context) {
    final snap = detail.snapshot;
    final healthScore = snap?.overallHealth.score;
    final healthLabel = snap?.overallHealth.label ?? 'Unknown';
    final score = healthScore?.toDouble() ?? 0.0;
    return GlassPanel(
      padding: const EdgeInsets.fromLTRB(28, 28, 28, 28),
      child: LayoutBuilder(
        builder: (context, c) {
          final isNarrow = c.maxWidth < 720;
          final healthRing = _HealthRing(
            score: score,
            label: healthLabel,
          );
          final info = Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'CLIENT',
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    color: AppTheme.accentGold,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.6,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  detail.displayName,
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 30,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primaryNavy,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'PAN ${detail.clientPan}',
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    color: AppTheme.textLight,
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    if (snap?.riskProfile != null)
                      _MetaPill(
                        icon: Icons.shield_outlined,
                        label: 'Risk',
                        value: snap!.riskProfile!,
                      ),
                    if (snap?.clientAge != null)
                      _MetaPill(
                        icon: Icons.cake_outlined,
                        label: 'Age',
                        value: '${snap!.clientAge}',
                      ),
                    _MetaPill(
                      icon: Icons.event_outlined,
                      label: 'Generated',
                      value: _formatDate(detail.generatedAt),
                    ),
                  ],
                ),
              ],
            ),
          );
          if (isNarrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                info,
                const SizedBox(height: 24),
                Center(child: healthRing),
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              info,
              const SizedBox(width: 28),
              healthRing,
            ],
          );
        },
      ),
    );
  }
}

class _MetaPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _MetaPill({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.backgroundCream,
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: const Color(0xFFE6E0D2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppTheme.accentGold),
          const SizedBox(width: 6),
          Text(
            '$label: ',
            style: GoogleFonts.dmSans(
              fontSize: 12,
              color: AppTheme.textLight,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.dmSans(
              fontSize: 12,
              color: AppTheme.primaryNavy,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _HealthRing extends StatelessWidget {
  final double score;
  final String label;
  const _HealthRing({required this.score, required this.label});

  @override
  Widget build(BuildContext context) {
    final ratio = (score / 100).clamp(0.0, 1.0);
    final color = _scoreColor(score);
    return SizedBox(
      width: 140,
      height: 140,
      child: Stack(
        alignment: Alignment.center,
        children: [
          TweenAnimationBuilder<double>(
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeOutCubic,
            tween: Tween(begin: 0, end: ratio),
            builder: (context, value, _) {
              return CustomPaint(
                size: const Size(140, 140),
                painter: _RingPainter(
                  progress: value,
                  color: color,
                ),
              );
            },
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                score.toStringAsFixed(0),
                style: GoogleFonts.playfairDisplay(
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primaryNavy,
                  height: 1.0,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '/100',
                style: GoogleFonts.dmSans(
                  fontSize: 11,
                  color: AppTheme.textLight,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(2),
                ),
                child: Text(
                  label.toUpperCase(),
                  style: GoogleFonts.dmSans(
                    fontSize: 9,
                    color: color,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

Color _scoreColor(double score) {
  if (score >= 75) return AppTheme.successGreen;
  if (score >= 50) return AppTheme.accentGold;
  return AppTheme.errorRed;
}

class _RingPainter extends CustomPainter {
  final double progress;
  final Color color;
  _RingPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 8;
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..color = AppTheme.borderLight.withValues(alpha: 0.4);
    canvas.drawCircle(center, radius, track);

    final fg = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 10
      ..shader = SweepGradient(
        startAngle: -1.5708, // -pi/2
        endAngle: 4.7124,    // 3*pi/2
        colors: [
          color.withValues(alpha: 0.6),
          color,
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    final sweep = 6.2832 * progress; // 2*pi
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -1.5708,
      sweep,
      false,
      fg,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.progress != progress || old.color != color;
}

// ---------------------------------------------------------------------------
// Dimensions panel
// ---------------------------------------------------------------------------

class _DimensionsPanel extends StatelessWidget {
  final ClientSnapshot? snapshot;
  const _DimensionsPanel({required this.snapshot});

  @override
  Widget build(BuildContext context) {
    final dims = snapshot?.dimensions ?? const <String, DimensionScore>{};
    if (dims.isEmpty) return const SizedBox.shrink();
    return GlassPanel(
      padding: const EdgeInsets.fromLTRB(28, 22, 28, 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Dimension snapshot',
            style: GoogleFonts.playfairDisplay(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppTheme.primaryNavy,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Health score breakdown across key practice areas',
            style: GoogleFonts.dmSans(
              fontSize: 13,
              color: AppTheme.textLight,
            ),
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, c) {
              final isWide = c.maxWidth > 720;
              final entries = dims.entries.toList();
              final cells = <Widget>[];
              for (var i = 0; i < entries.length; i++) {
                final cell = _DimensionCell(
                  label: _prettify(entries[i].key),
                  dim: entries[i].value,
                );
                cells.add(cell);
              }
              if (isWide) {
                final w = (c.maxWidth - 16) / 2;
                return Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: cells
                      .map((cell) => SizedBox(width: w, child: cell))
                      .toList(),
                );
              }
              return Column(
                children: cells
                    .map((cell) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: cell,
                        ))
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _DimensionCell extends StatelessWidget {
  final String label;
  final DimensionScore dim;
  const _DimensionCell({required this.label, required this.dim});

  @override
  Widget build(BuildContext context) {
    final score = dim.score?.toDouble() ?? 0.0;
    final ratio = (score / 100).clamp(0.0, 1.0);
    final color = _scoreColor(score);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      decoration: BoxDecoration(
        color: AppTheme.backgroundCream,
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: const Color(0xFFE6E0D2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textDark,
                  ),
                ),
              ),
              Text(
                '${dim.score?.toStringAsFixed(0) ?? '—'}/100',
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  color: AppTheme.textLight,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: Stack(
              children: [
                Container(
                  height: 6,
                  color: AppTheme.borderLight.withValues(alpha: 0.5),
                ),
                FractionallySizedBox(
                  widthFactor: ratio,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 600),
                    height: 6,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
          if (dim.label != null) ...[
            const SizedBox(height: 6),
            Text(
              dim.label!,
              style: GoogleFonts.dmSans(
                fontSize: 11,
                color: color,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Protection summary
// ---------------------------------------------------------------------------

/// Compact panel showing per-client protection + emergency-fund gap values
/// from the new enriched snapshot. Keeps the MFD grounded in actual numbers
/// rather than relying on the dimension labels alone.
class _ProtectionSummary extends StatelessWidget {
  final ClientSnapshot? snapshot;
  const _ProtectionSummary({required this.snapshot});

  @override
  Widget build(BuildContext context) {
    final snap = snapshot;
    if (snap == null) return const SizedBox.shrink();
    final p = snap.protection;
    final l = snap.liquidityDetail;
    final alloc = snap.allocationSummary;

    // If the snapshot has no enriched data (older reports), don't render.
    final hasProtection =
        p.lifeCoverRequired != null || p.healthCoverRecommended != null;
    final hasLiquidity = l.emergencyFundTargetInr != null;
    final hasAllocation = alloc.totalIdealSip != null;
    if (!hasProtection && !hasLiquidity && !hasAllocation) {
      return const SizedBox.shrink();
    }

    return GlassPanel(
      padding: const EdgeInsets.fromLTRB(28, 22, 28, 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Coverage & savings gaps',
            style: GoogleFonts.playfairDisplay(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppTheme.primaryNavy,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Actual rupee amounts identified by the analysis',
            style: GoogleFonts.dmSans(
              fontSize: 13,
              color: AppTheme.textLight,
            ),
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, c) {
              final isWide = c.maxWidth > 720;
              final cards = <Widget>[
                if (hasProtection) _ProtectionCard(protection: p),
                if (hasLiquidity) _EmergencyFundCard(liquidity: l),
                if (hasAllocation) _SipSummaryCard(allocation: alloc),
              ];
              if (isWide) {
                final w = (c.maxWidth - 32) / cards.length.clamp(1, 3);
                return Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: cards
                      .map((c) => SizedBox(width: w, child: c))
                      .toList(),
                );
              }
              return Column(
                children: cards
                    .map((c) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: c,
                        ))
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ProtectionCard extends StatelessWidget {
  final ProtectionDetail protection;
  const _ProtectionCard({required this.protection});

  @override
  Widget build(BuildContext context) {
    final lifeGap = protection.lifeCoverGap?.toDouble() ?? 0;
    final healthGap = protection.healthCoverGap?.toDouble() ?? 0;
    final provMonthly = protection.insuranceProvisionMonthly?.toDouble() ?? 0;
    return _SummaryCard(
      title: 'Protection',
      accent: AppTheme.errorRed,
      rows: [
        _SummaryRow(
          label: 'Life cover gap',
          value: lifeGap > 0 ? _formatRupeesShort(lifeGap) : 'Adequate',
          valueColor: lifeGap > 0 ? AppTheme.errorRed : AppTheme.successGreen,
        ),
        _SummaryRow(
          label: 'Health cover gap',
          value: healthGap > 0 ? _formatRupeesShort(healthGap) : 'Adequate',
          valueColor: healthGap > 0 ? AppTheme.errorRed : AppTheme.successGreen,
        ),
        if (provMonthly > 0)
          _SummaryRow(
            label: 'Insurance provision',
            value: '${_formatRupeesShort(provMonthly)}/mo',
            valueColor: AppTheme.textDark,
          ),
      ],
    );
  }
}

class _EmergencyFundCard extends StatelessWidget {
  final LiquidityDetail liquidity;
  const _EmergencyFundCard({required this.liquidity});

  @override
  Widget build(BuildContext context) {
    final gap = liquidity.emergencyFundGapInr?.toDouble() ?? 0;
    final months = liquidity.monthsCovered?.toDouble();
    final target = liquidity.emergencyFundTargetInr?.toDouble() ?? 0;
    return _SummaryCard(
      title: 'Emergency fund',
      accent: const Color(0xFF3F88C5),
      rows: [
        _SummaryRow(
          label: 'Months covered',
          value: months != null ? '${months.toStringAsFixed(1)} mo' : '—',
          valueColor: AppTheme.textDark,
        ),
        _SummaryRow(
          label: 'Target',
          value: target > 0 ? _formatRupeesShort(target) : '—',
          valueColor: AppTheme.textDark,
        ),
        _SummaryRow(
          label: 'Gap',
          value: gap > 0 ? _formatRupeesShort(gap) : 'Funded',
          valueColor: gap > 0 ? AppTheme.errorRed : AppTheme.successGreen,
        ),
      ],
    );
  }
}

class _SipSummaryCard extends StatelessWidget {
  final AllocationSummary allocation;
  const _SipSummaryCard({required this.allocation});

  @override
  Widget build(BuildContext context) {
    final ideal = allocation.totalIdealSip?.toDouble() ?? 0;
    final allocated = allocation.totalAllocatedSip?.toDouble() ?? 0;
    final pct = allocation.goalAchievementPct?.toDouble();
    final color = pct == null
        ? AppTheme.textLight
        : (pct >= 75
            ? AppTheme.successGreen
            : (pct >= 40 ? AppTheme.accentGold : AppTheme.errorRed));
    return _SummaryCard(
      title: 'Goal SIPs',
      accent: AppTheme.accentGold,
      rows: [
        _SummaryRow(
          label: 'Ideal SIP',
          value: ideal > 0 ? '${_formatRupeesShort(ideal)}/mo' : '—',
          valueColor: AppTheme.textDark,
        ),
        _SummaryRow(
          label: 'Allocated SIP',
          value: allocated > 0 ? '${_formatRupeesShort(allocated)}/mo' : '—',
          valueColor: AppTheme.textDark,
        ),
        if (pct != null)
          _SummaryRow(
            label: 'Goal achievement',
            value: '${pct.toStringAsFixed(0)}%',
            valueColor: color,
          ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final Color accent;
  final List<_SummaryRow> rows;
  const _SummaryCard({
    required this.title,
    required this.accent,
    required this.rows,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: AppTheme.backgroundCream,
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: const Color(0xFFE6E0D2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 14,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: GoogleFonts.dmSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primaryNavy,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final r in rows) ...[
            r,
            if (r != rows.last) const SizedBox(height: 6),
          ],
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  const _SummaryRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.dmSans(
              fontSize: 12,
              color: AppTheme.textLight,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Text(
          value,
          style: GoogleFonts.dmSans(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: valueColor ?? AppTheme.primaryNavy,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Action items
// ---------------------------------------------------------------------------

class _ActionItemsSection extends StatelessWidget {
  final List<ActionItem> items;
  final bool Function(ActionItem) isConverted;
  final bool Function(String itemId) isPending;
  final Future<void> Function(ActionItem) onToggle;

  const _ActionItemsSection({
    required this.items,
    required this.isConverted,
    required this.isPending,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return GlassPanel(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 36),
        child: Column(
          children: [
            const Icon(Icons.task_alt_rounded,
                color: AppTheme.successGreen, size: 36),
            const SizedBox(height: 12),
            Text(
              'No action items',
              style: GoogleFonts.playfairDisplay(
                fontSize: 20,
                color: AppTheme.primaryNavy,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'This client has no follow-ups at the moment.',
              style: GoogleFonts.dmSans(
                fontSize: 13,
                color: AppTheme.textLight,
              ),
            ),
          ],
        ),
      );
    }

    final byUrgency = <ActionUrgency, List<ActionItem>>{};
    for (final i in items) {
      byUrgency.putIfAbsent(i.urgency, () => []).add(i);
    }
    // Display order: IMMEDIATE, HIGH, MAINTAIN, unknown.
    const order = [
      ActionUrgency.immediate,
      ActionUrgency.high,
      ActionUrgency.maintain,
      ActionUrgency.unknown,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final urgency in order)
          if (byUrgency[urgency]?.isNotEmpty ?? false) ...[
            _UrgencyHeader(urgency: urgency,
                count: byUrgency[urgency]!.length),
            const SizedBox(height: 12),
            for (final item in byUrgency[urgency]!) ...[
              _ActionItemCard(
                item: item,
                converted: isConverted(item),
                pending: isPending(item.itemId),
                onToggle: () => onToggle(item),
              ),
              const SizedBox(height: 10),
            ],
            const SizedBox(height: 12),
          ],
      ],
    );
  }
}

class _UrgencyHeader extends StatelessWidget {
  final ActionUrgency urgency;
  final int count;
  const _UrgencyHeader({required this.urgency, required this.count});

  @override
  Widget build(BuildContext context) {
    final (label, color, icon) = switch (urgency) {
      ActionUrgency.immediate => (
        'IMMEDIATE',
        AppTheme.errorRed,
        Icons.priority_high_rounded,
      ),
      ActionUrgency.high => (
        'HIGH',
        const Color(0xFFE07A5F),
        Icons.error_outline_rounded,
      ),
      ActionUrgency.maintain => (
        'MAINTAIN',
        AppTheme.successGreen,
        Icons.check_circle_outline_rounded,
      ),
      _ => (
        'OTHER',
        AppTheme.textLight,
        Icons.info_outline_rounded,
      ),
    };
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(2),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.dmSans(
                  fontSize: 11,
                  color: color,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.4,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '$count ${count == 1 ? "item" : "items"}',
          style: GoogleFonts.dmSans(
            fontSize: 12,
            color: AppTheme.textLight,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _ActionItemCard extends StatelessWidget {
  final ActionItem item;
  final bool converted;
  final bool pending;
  final VoidCallback onToggle;
  const _ActionItemCard({
    required this.item,
    required this.converted,
    required this.pending,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final showToggle = item.urgency == ActionUrgency.immediate ||
        item.urgency == ActionUrgency.high;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: converted
            ? AppTheme.successGreen.withValues(alpha: 0.06)
            : Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(3),
        border: Border.all(
          color: converted
              ? AppTheme.successGreen.withValues(alpha: 0.35)
              : const Color(0xFFEAE6DE),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.accentGold.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(2),
                        ),
                        child: Text(
                          _prettify(item.dimension),
                          style: GoogleFonts.dmSans(
                            fontSize: 10,
                            color: AppTheme.accentGold,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                      if (item.valueNum != null) ...[
                        const SizedBox(width: 8),
                        Text(
                          _formatValue(item),
                          style: GoogleFonts.dmSans(
                            fontSize: 11,
                            color: AppTheme.textMedium,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 320),
                    style: GoogleFonts.dmSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: converted
                          ? AppTheme.successGreen
                          : AppTheme.primaryNavy,
                      decoration: converted
                          ? TextDecoration.lineThrough
                          : TextDecoration.none,
                      decorationColor:
                          AppTheme.successGreen.withValues(alpha: 0.6),
                      decorationThickness: 2,
                    ),
                    child: Text(item.title ?? 'Action item'),
                  ),
                  if (item.description != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      item.description!,
                      style: GoogleFonts.dmSans(
                        fontSize: 13,
                        color: AppTheme.textMedium,
                        height: 1.45,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (showToggle) ...[
              const SizedBox(width: 16),
              _ConvertToggle(
                value: converted,
                onChanged: pending ? null : onToggle,
                pending: pending,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ConvertToggle extends StatelessWidget {
  final bool value;
  final VoidCallback? onChanged;
  final bool pending;
  const _ConvertToggle({
    required this.value,
    required this.onChanged,
    required this.pending,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onChanged,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
            width: 56,
            height: 32,
            decoration: BoxDecoration(
              color: value
                  ? AppTheme.successGreen
                  : AppTheme.borderLight.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(16),
              boxShadow: value
                  ? [
                      BoxShadow(
                        color: AppTheme.successGreen.withValues(alpha: 0.4),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : const [],
            ),
            child: Stack(
              children: [
                AnimatedAlign(
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeOutCubic,
                  alignment:
                      value ? Alignment.centerRight : Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.all(3),
                    child: pending
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Container(
                            width: 26,
                            height: 26,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 220),
                              child: value
                                  ? const Icon(
                                      Icons.check_rounded,
                                      key: ValueKey('check'),
                                      color: AppTheme.successGreen,
                                      size: 16,
                                    )
                                  : const Icon(
                                      Icons.close_rounded,
                                      key: ValueKey('close'),
                                      color: AppTheme.textLight,
                                      size: 16,
                                    ),
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value ? 'Converted' : 'Mark converted',
          style: GoogleFonts.dmSans(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: value ? AppTheme.successGreen : AppTheme.textLight,
            letterSpacing: 0.4,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Loading / error
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
            'Loading client detail…',
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

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

const _monthNames = [
  '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String _formatDate(String? iso) {
  if (iso == null || iso.isEmpty) return '—';
  final dt = DateTime.tryParse(iso);
  if (dt == null) return '—';
  final l = dt.toLocal();
  return '${l.day} ${_monthNames[l.month]} ${l.year}';
}

String _prettify(String dim) {
  return dim
      .replaceAll('_', ' ')
      .split(' ')
      .where((p) => p.isNotEmpty)
      .map((p) => p[0].toUpperCase() + p.substring(1))
      .join(' ');
}

String _formatValue(ActionItem item) {
  final v = item.valueNum;
  if (v == null) return '';
  switch (item.valueType) {
    // ---- Legacy value types (kept for backward compat) ----
    case 'required_life_cover_inr':
      return 'Cover: ${_formatRupeesShort(v.toDouble())}';
    case 'emergency_fund_months':
      return '${v.toStringAsFixed(1)} months';
    case 'emi_to_income_pct':
      return '${v.toStringAsFixed(0)}% EMI';
    // ---- New (post-rewrite) value types ----
    case 'life_cover_gap_inr':
      return 'Gap: ${_formatRupeesShort(v.toDouble())}';
    case 'health_cover_gap_inr':
      return 'Gap: ${_formatRupeesShort(v.toDouble())}';
    case 'life_premium_monthly_inr':
      return 'Prem: ${_formatRupeesShort(v.toDouble())}/mo';
    case 'health_premium_monthly_inr':
      return 'Prem: ${_formatRupeesShort(v.toDouble())}/mo';
    case 'rebalance_shift_inr':
      return 'Shift: ${_formatRupeesShort(v.toDouble())}';
    case 'emergency_fund_gap_inr':
      return 'Gap: ${_formatRupeesShort(v.toDouble())}';
    case 'monthly_emi_inr':
      return '${_formatRupeesShort(v.toDouble())} EMI/mo';
    case 'monthly_surplus_inr':
      return '${_formatRupeesShort(v.toDouble())} surplus/mo';
    case 'sip_amount_inr':
      return '${_formatRupeesShort(v.toDouble())} SIP/mo';
    case 'tax_saving_potential_inr':
      return '${_formatRupeesShort(v.toDouble())} tax save/yr';
    case 'ihs_score':
      return 'Score: ${v.toStringAsFixed(0)}';
    default:
      return v.toStringAsFixed(0);
  }
}

String _formatRupeesShort(double amount) {
  if (amount <= 0) return '₹0';
  if (amount >= 1e7) {
    return '₹${(amount / 1e7).toStringAsFixed(2)} Cr';
  }
  if (amount >= 1e5) {
    return '₹${(amount / 1e5).toStringAsFixed(1)} L';
  }
  if (amount >= 1e3) {
    return '₹${(amount / 1e3).toStringAsFixed(1)} K';
  }
  return '₹${amount.toStringAsFixed(0)}';
}
