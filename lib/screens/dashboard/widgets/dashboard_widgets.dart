import 'package:flutter/material.dart';
import 'package:frontend/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';

/// Top app bar used by all dashboard screens. Keeps the dark navy aesthetic
/// of the rest of the app while leaving room for screen-specific actions.
class DashboardTopBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final bool showBack;

  const DashboardTopBar({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const [],
    this.showBack = true,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 4);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: AppTheme.primaryNavy,
      foregroundColor: Colors.white,
      elevation: 0,
      automaticallyImplyLeading: showBack && Navigator.canPop(context),
      titleSpacing: 16,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title,
            style: GoogleFonts.dmSans(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: 0.4,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 1),
            Text(
              subtitle!,
              style: GoogleFonts.dmSans(
                fontSize: 11,
                color: Colors.white.withValues(alpha: 0.65),
              ),
            ),
          ],
        ],
      ),
      actions: [
        ...actions,
        const SizedBox(width: 4),
      ],
    );
  }
}

/// A glassmorphism panel — translucent surface with a subtle gradient,
/// a soft border and a long shadow. Used for cards across the dashboard.
class GlassPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color? color;
  final VoidCallback? onTap;

  const GlassPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.radius = 4,
    this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final body = Container(
      decoration: BoxDecoration(
        color: color ?? Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.6),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryNavy.withValues(alpha: 0.06),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: 0.6),
                Colors.white.withValues(alpha: 0.0),
              ],
              stops: const [0.0, 0.6],
            ),
          ),
          child: child,
        ),
      ),
    );
    if (onTap == null) return body;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        child: body,
      ),
    );
  }
}

/// A single aggregate metric card (Total Opportunity, Converted, Pending…).
class AggregateMetricCard extends StatelessWidget {
  final String label;
  final double value;
  final Color accent;
  final IconData icon;
  final String footnote;
  final String? trendLabel;
  final bool trendUp;

  const AggregateMetricCard({
    super.key,
    required this.label,
    required this.value,
    required this.accent,
    required this.icon,
    required this.footnote,
    this.trendLabel,
    this.trendUp = true,
  });

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(2),
                ),
                child: Icon(icon, color: accent, size: 20),
              ),
              const Spacer(),
              if (trendLabel != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: (trendUp
                            ? AppTheme.successGreen
                            : AppTheme.errorRed)
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        trendUp
                            ? Icons.trending_up_rounded
                            : Icons.trending_down_rounded,
                        size: 12,
                        color: trendUp
                            ? AppTheme.successGreen
                            : AppTheme.errorRed,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        trendLabel!,
                        style: GoogleFonts.dmSans(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: trendUp
                              ? AppTheme.successGreen
                              : AppTheme.errorRed,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.dmSans(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textLight,
                  letterSpacing: 1.4,
                ),
              ),
              const SizedBox(height: 6),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 400),
                child: Text(
                  _formatRupees(value),
                  key: ValueKey(value),
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primaryNavy,
                    height: 1.05,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                footnote,
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  color: AppTheme.textMedium,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

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
