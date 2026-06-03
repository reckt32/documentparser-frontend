import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:frontend/app_theme.dart';

/// Minimum report credits required to unlock the Practice Dashboard.
const int kDashboardUnlockedAtCredits = 5;

/// A premium hero-style banner that promotes the "Practice Dashboard".
///
/// Token gating rules:
///   • [reportCredits] >= [kDashboardUnlockedAtCredits] → fully active, gold/
///     navy gradient, calls [onUnlockedTap].
///   • otherwise → muted, greyed-out with a lock icon, shows a snackbar /
///     [onLockedTap] with the gating message instead of navigating.
class DashboardBanner extends StatefulWidget {
  /// Pass `null` for unauthenticated users — the banner is then hidden.
  final int? reportCredits;
  final VoidCallback onUnlockedTap;
  final VoidCallback? onLockedTap;

  const DashboardBanner({
    super.key,
    required this.reportCredits,
    required this.onUnlockedTap,
    this.onLockedTap,
  });

  bool get _isUnlocked =>
      (reportCredits ?? 0) >= kDashboardUnlockedAtCredits;

  @override
  State<DashboardBanner> createState() => _DashboardBannerState();
}

class _DashboardBannerState extends State<DashboardBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _hover = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  );

  @override
  void dispose() {
    _hover.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Hide entirely for unauthenticated visitors — there's no meaningful
    // "credits" to display and the hero CTA already covers onboarding.
    if (widget.reportCredits == null) return const SizedBox.shrink();

    final unlocked = widget._isUnlocked;

    return MouseRegion(
      onEnter: (_) => unlocked ? _hover.forward() : null,
      onExit: (_) => _hover.reverse(),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: unlocked ? widget.onUnlockedTap : _handleLockedTap,
        child: AnimatedBuilder(
          animation: _hover,
          builder: (context, child) {
            final t = _hover.value;
            return Transform.translate(
              offset: Offset(0, -2 * t),
              child: child,
            );
          },
          child: _BannerBody(
            isUnlocked: unlocked,
            credits: widget.reportCredits ?? 0,
          ),
        ),
      ),
    );
  }

  void _handleLockedTap() {
    if (widget.onLockedTap != null) {
      widget.onLockedTap!();
      return;
    }
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.hideCurrentSnackBar();
    messenger?.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppTheme.primaryNavy,
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(2),
        ),
        content: Row(
          children: [
            const Icon(Icons.lock_outline_rounded,
                color: AppTheme.accentGold, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '$kDashboardUnlockedAtCredits report credits required to '
                'unlock practice insights',
                style: GoogleFonts.dmSans(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        duration: const Duration(seconds: 4),
      ),
    );
  }
}

class _BannerBody extends StatelessWidget {
  final bool isUnlocked;
  final int credits;

  const _BannerBody({required this.isUnlocked, required this.credits});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 720;
        return Container(
          margin: const EdgeInsets.fromLTRB(0, 16, 0, 0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            boxShadow: isUnlocked
                ? [
                    BoxShadow(
                      color: AppTheme.primaryNavy.withValues(alpha: 0.18),
                      blurRadius: 28,
                      offset: const Offset(0, 12),
                    ),
                  ]
                : const [],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Stack(
              children: [
                // Layer 1: background
                Positioned.fill(child: _Background(isUnlocked: isUnlocked)),
                // Layer 2: subtle glass overlay for premium feel
                Positioned.fill(
                  child: _GlassOverlay(isUnlocked: isUnlocked),
                ),
                // Layer 3: decorative sparkles (active only)
                if (isUnlocked) const Positioned.fill(child: _SparkleField()),
                // Layer 4: content
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: isNarrow ? 20 : 36,
                    vertical: isNarrow ? 24 : 32,
                  ),
                  child: Flex(
                    direction: isNarrow ? Axis.vertical : Axis.horizontal,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _IconBlock(isUnlocked: isUnlocked),
                      SizedBox(width: isNarrow ? 0 : 28, height: isNarrow ? 20 : 0),
                      Expanded(child: _CopyBlock(
                        isUnlocked: isUnlocked,
                        credits: credits,
                      )),
                      SizedBox(width: isNarrow ? 0 : 24, height: isNarrow ? 20 : 0),
                      _ActionPill(isUnlocked: isUnlocked, credits: credits),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Background layers
// ---------------------------------------------------------------------------

class _Background extends StatelessWidget {
  final bool isUnlocked;
  const _Background({required this.isUnlocked});

  @override
  Widget build(BuildContext context) {
    if (isUnlocked) {
      return const DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.primaryNavy,
              Color(0xFF15263D),
              Color(0xFF1B3050),
            ],
          ),
        ),
      );
    }
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFEDEAE3),
            Color(0xFFE2DED4),
          ],
        ),
      ),
    );
  }
}

class _GlassOverlay extends StatelessWidget {
  final bool isUnlocked;
  const _GlassOverlay({required this.isUnlocked});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        painter: _GlassPainter(
          color: isUnlocked
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.white.withValues(alpha: 0.4),
        ),
      ),
    );
  }
}

class _GlassPainter extends CustomPainter {
  final Color color;
  _GlassPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    // diagonal sheen across the banner
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [color.withValues(alpha: 0.0), color, color.withValues(alpha: 0.0)],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width * 0.45, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _GlassPainter old) => old.color != color;
}

// Subtle decorative sparkles for the active state.
class _SparkleField extends StatelessWidget {
  const _SparkleField();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(painter: _SparklePainter()),
    );
  }
}

class _SparklePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = AppTheme.accentGold.withValues(alpha: 0.18);
    const positions = <Offset>[
      Offset(40, 30),
      Offset(110, 18),
      Offset(220, 60),
      Offset(330, 24),
      Offset(460, 80),
      Offset(560, 32),
      Offset(680, 70),
      Offset(820, 18),
    ];
    for (final p in positions) {
      if (p.dx > size.width) continue;
      canvas.drawCircle(p, 2.5, paint);
    }
    paint.color = AppTheme.accentGold.withValues(alpha: 0.10);
    const positions2 = <Offset>[
      Offset(80, 90),
      Offset(180, 110),
      Offset(300, 120),
      Offset(420, 130),
      Offset(540, 110),
      Offset(660, 130),
      Offset(780, 110),
    ];
    for (final p in positions2) {
      if (p.dx > size.width) continue;
      canvas.drawCircle(p, 1.5, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ---------------------------------------------------------------------------
// Sub-blocks
// ---------------------------------------------------------------------------

class _IconBlock extends StatelessWidget {
  final bool isUnlocked;
  const _IconBlock({required this.isUnlocked});

  @override
  Widget build(BuildContext context) {
    final bg = isUnlocked
        ? AppTheme.accentGold.withValues(alpha: 0.18)
        : Colors.white.withValues(alpha: 0.6);
    final ring = isUnlocked
        ? AppTheme.accentGold
        : AppTheme.textLight.withValues(alpha: 0.5);
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(36),
        border: Border.all(color: ring.withValues(alpha: 0.4), width: 1.5),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(
            isUnlocked
                ? Icons.insights_rounded
                : Icons.lock_outline_rounded,
            size: 32,
            color: isUnlocked ? AppTheme.accentGold : AppTheme.textLight,
          ),
        ],
      ),
    );
  }
}

class _CopyBlock extends StatelessWidget {
  final bool isUnlocked;
  final int credits;
  const _CopyBlock({required this.isUnlocked, required this.credits});

  @override
  Widget build(BuildContext context) {
    final titleColor =
        isUnlocked ? Colors.white : AppTheme.textDark.withValues(alpha: 0.7);
    final subColor = isUnlocked
        ? Colors.white.withValues(alpha: 0.78)
        : AppTheme.textMedium.withValues(alpha: 0.85);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Eyebrow label
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: isUnlocked
                    ? AppTheme.accentGold.withValues(alpha: 0.18)
                    : Colors.white.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(2),
                border: Border.all(
                  color: isUnlocked
                      ? AppTheme.accentGold.withValues(alpha: 0.4)
                      : AppTheme.textLight.withValues(alpha: 0.3),
                ),
              ),
              child: Text(
                isUnlocked ? 'PRACTICE DASHBOARD' : 'LOCKED',
                style: GoogleFonts.dmSans(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.6,
                  color: isUnlocked
                      ? AppTheme.accentGold
                      : AppTheme.textLight,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Title
        Text(
          isUnlocked
              ? 'See your practice insights in one view'
              : 'Unlock the Practice Dashboard',
          style: GoogleFonts.playfairDisplay(
            fontSize: 26,
            fontWeight: FontWeight.w700,
            height: 1.15,
            color: titleColor,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 6),
        // Subtitle
        Text(
          isUnlocked
              ? 'Track opportunities, monitor client follow-ups and review '
                  'your annual conversion impact — all in one place.'
              : 'Earn $kDashboardUnlockedAtCredits report credits to reveal '
                  'opportunity tracking, action follow-ups and conversion '
                  'analytics for every client.',
          style: GoogleFonts.dmSans(
            fontSize: 14,
            height: 1.5,
            color: subColor,
          ),
        ),
        if (isUnlocked) ...[
          const SizedBox(height: 14),
          _CreditsStrip(credits: credits),
        ],
      ],
    );
  }
}

class _CreditsStrip extends StatelessWidget {
  final int credits;
  const _CreditsStrip({required this.credits});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.stars_rounded, color: AppTheme.accentGold, size: 16),
        const SizedBox(width: 6),
        Text(
          '$credits credits available',
          style: GoogleFonts.dmSans(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppTheme.accentGold,
            letterSpacing: 0.4,
          ),
        ),
      ],
    );
  }
}

class _ActionPill extends StatelessWidget {
  final bool isUnlocked;
  final int credits;
  const _ActionPill({required this.isUnlocked, required this.credits});

  @override
  Widget build(BuildContext context) {
    final bg = isUnlocked
        ? AppTheme.accentGold
        : Colors.white.withValues(alpha: 0.85);
    final fg = isUnlocked ? AppTheme.primaryNavy : AppTheme.textMedium;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(2),
        border: isUnlocked
            ? null
            : Border.all(
                color: AppTheme.textLight.withValues(alpha: 0.4),
                width: 1,
              ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            isUnlocked ? 'Open Dashboard' : 'Locked',
            style: GoogleFonts.dmSans(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: fg,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            isUnlocked ? Icons.arrow_forward_rounded : Icons.lock_rounded,
            size: 16,
            color: fg,
          ),
        ],
      ),
    );
  }
}
