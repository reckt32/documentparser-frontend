import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:frontend/app_theme.dart';
import 'package:frontend/constants.dart';

/// Spend Right Screen — 4-question lifestyle input with live Golden Number
/// counter and animated Status Badge (Saver / Balanced / Spender).
class SpendRightScreen extends StatefulWidget {
  /// Optional callback when user taps "Use for Retirement Plan".
  /// Passes the computed golden_number (comfort_spends).
  final void Function(double goldenNumber)? onNavigateToRetirement;

  const SpendRightScreen({super.key, this.onNavigateToRetirement});

  @override
  State<SpendRightScreen> createState() => _SpendRightScreenState();
}

class _SpendRightScreenState extends State<SpendRightScreen>
    with TickerProviderStateMixin {
  final _incomeCtrl = TextEditingController();
  final _rentCtrl = TextEditingController();
  final _basicCtrl = TextEditingController();
  final _comfortCtrl = TextEditingController();

  // Result state
  Map<String, dynamic>? _result;
  bool _isLoading = false;
  String? _error;

  // Animation controllers
  late AnimationController _badgeAnimCtrl;
  late Animation<double> _badgeScale;
  late AnimationController _goldenCounterCtrl;

  // Animated golden number value
  double _animatedGoldenNumber = 0;
  double _targetGoldenNumber = 0;

  @override
  void initState() {
    super.initState();
    _badgeAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _badgeScale = CurvedAnimation(
      parent: _badgeAnimCtrl,
      curve: Curves.elasticOut,
    );
    _goldenCounterCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..addListener(() {
        setState(() {
          _animatedGoldenNumber = _goldenCounterCtrl.value * _targetGoldenNumber;
        });
      });

    // Add listeners for live calculation
    _incomeCtrl.addListener(_onInputChanged);
    _rentCtrl.addListener(_onInputChanged);
    _basicCtrl.addListener(_onInputChanged);
    _comfortCtrl.addListener(_onInputChanged);
  }

  @override
  void dispose() {
    _incomeCtrl.dispose();
    _rentCtrl.dispose();
    _basicCtrl.dispose();
    _comfortCtrl.dispose();
    _badgeAnimCtrl.dispose();
    _goldenCounterCtrl.dispose();
    super.dispose();
  }

  double? _parseValue(String text) {
    if (text.trim().isEmpty) return null;
    return double.tryParse(text.replaceAll(',', ''));
  }

  void _onInputChanged() {
    final comfort = _parseValue(_comfortCtrl.text);
    if (comfort != null && comfort != _targetGoldenNumber) {
      _targetGoldenNumber = comfort;
      _goldenCounterCtrl.forward(from: 0);
    }

    // Live local calculation (no API call yet)
    final income = _parseValue(_incomeCtrl.text);
    final rent = _parseValue(_rentCtrl.text);
    final basic = _parseValue(_basicCtrl.text);

    if (income != null && rent != null && basic != null && comfort != null && income > 0) {
      final surplus = income - rent - basic - comfort;
      final surplusPct = (surplus / income) * 100;
      String badge;
      if (surplusPct > 30) {
        badge = 'Saver';
      } else if (surplusPct >= 10) {
        badge = 'Balanced';
      } else {
        badge = 'Spender';
      }

      setState(() {
        _result = {
          'golden_number': comfort,
          'total_needs': rent + basic,
          'surplus': surplus,
          'surplus_pct': surplusPct,
          'status_badge': badge,
          'needs_pct': (rent + basic) / income * 100,
          'wants_pct': comfort / income * 100,
        };
      });

      if (!_badgeAnimCtrl.isCompleted) {
        _badgeAnimCtrl.forward();
      }
    }
  }

  Future<void> _calculate() async {
    final income = _parseValue(_incomeCtrl.text);
    final rent = _parseValue(_rentCtrl.text);
    final basic = _parseValue(_basicCtrl.text);
    final comfort = _parseValue(_comfortCtrl.text);

    if (income == null || rent == null || basic == null || comfort == null) {
      setState(() => _error = 'Please fill in all fields.');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final resp = await http.post(
        Uri.parse('$kBackendUrl/api/free/spend-right'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'income': income,
          'rent': rent,
          'basic_spends': basic,
          'comfort_spends': comfort,
        }),
      );

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        setState(() {
          _result = data;
          _isLoading = false;
        });
        _badgeAnimCtrl.forward(from: 0);
      } else {
        final err = jsonDecode(resp.body);
        setState(() {
          _error = err['error'] ?? 'Calculation failed.';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Connection error. Using local calculation.';
        _isLoading = false;
      });
    }
  }

  String _formatIndian(double amount) {
    if (amount.abs() >= 10000000) {
      return '₹${(amount / 10000000).toStringAsFixed(2)} Cr';
    } else if (amount.abs() >= 100000) {
      return '₹${(amount / 100000).toStringAsFixed(2)} L';
    } else if (amount.abs() >= 1000) {
      return '₹${(amount / 1000).toStringAsFixed(1)}K';
    }
    return '₹${amount.toStringAsFixed(0)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundCream,
      appBar: AppBar(
        backgroundColor: AppTheme.primaryNavy,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Spend Right',
          style: GoogleFonts.dmSans(
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHero(context),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: Column(
                children: [
                  _buildInputCard(
                    context,
                    icon: Icons.account_balance_wallet_outlined,
                    label: 'Monthly Income',
                    hint: 'Take-home salary',
                    controller: _incomeCtrl,
                    index: 0,
                  ),
                  const SizedBox(height: 16),
                  _buildInputCard(
                    context,
                    icon: Icons.home_outlined,
                    label: 'Rent / Housing EMI',
                    hint: 'Monthly rent or home loan EMI',
                    controller: _rentCtrl,
                    index: 1,
                  ),
                  const SizedBox(height: 16),
                  _buildInputCard(
                    context,
                    icon: Icons.shopping_cart_outlined,
                    label: 'Basic Spends',
                    hint: 'Groceries, utilities, transport',
                    controller: _basicCtrl,
                    index: 2,
                  ),
                  const SizedBox(height: 16),
                  _buildInputCard(
                    context,
                    icon: Icons.local_cafe_outlined,
                    label: 'Comfort Spends',
                    hint: 'Dining, shopping, entertainment',
                    controller: _comfortCtrl,
                    index: 3,
                    isGolden: true,
                  ),
                  const SizedBox(height: 32),

                  // Golden Number Live Counter
                  _buildGoldenNumberCounter(context),

                  const SizedBox(height: 24),

                  // Status Badge
                  if (_result != null) _buildStatusBadge(context),

                  const SizedBox(height: 24),

                  // Result Summary
                  if (_result != null) _buildResultSummary(context),

                  const SizedBox(height: 24),

                  // Calculate button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _calculate,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryNavy,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                        elevation: 0,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              'VERIFY WITH SERVER',
                              style: GoogleFonts.dmSans(
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1.5,
                                fontSize: 14,
                              ),
                            ),
                    ),
                  ),

                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      style: GoogleFonts.dmSans(
                        color: AppTheme.errorRed,
                        fontSize: 13,
                      ),
                    ),
                  ],

                  // CTA to Retirement Calculator
                  if (_result != null) ...[
                    const SizedBox(height: 32),
                    _buildRetirementCTA(context),
                  ],

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHero(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Color(0xFFE8E4DF), width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'FREE TOOL',
            style: GoogleFonts.dmSans(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 2.0,
              color: AppTheme.accentGold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Discover Your\nGolden Number',
            style: GoogleFonts.playfairDisplay(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryNavy,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 8),
          AppTheme.goldAccentBar(width: 60, height: 2),
          const SizedBox(height: 12),
          Text(
            'How much of your income goes to wants? Enter your monthly numbers below.',
            style: GoogleFonts.dmSans(
              fontSize: 14,
              color: AppTheme.textMedium,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputCard(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String hint,
    required TextEditingController controller,
    required int index,
    bool isGolden = false,
  }) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 400 + (index * 100)),
      curve: Curves.easeOut,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - value)),
            child: child,
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: isGolden
                ? AppTheme.accentGold.withValues(alpha: 0.5)
                : AppTheme.borderLight.withValues(alpha: 0.4),
            width: isGolden ? 2 : 1,
          ),
          boxShadow: isGolden
              ? [
                  BoxShadow(
                    color: AppTheme.accentGold.withValues(alpha: 0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isGolden
                    ? AppTheme.accentGold.withValues(alpha: 0.12)
                    : AppTheme.primaryNavy.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                icon,
                size: 20,
                color: isGolden ? AppTheme.accentGold : AppTheme.primaryNavy,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isGolden ? AppTheme.accentGold : AppTheme.textLight,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  TextField(
                    controller: controller,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d,.]'))],
                    style: GoogleFonts.dmSans(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primaryNavy,
                    ),
                    decoration: InputDecoration(
                      prefixText: '₹ ',
                      prefixStyle: GoogleFonts.dmSans(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textLight,
                      ),
                      hintText: hint,
                      hintStyle: GoogleFonts.dmSans(
                        fontSize: 14,
                        color: AppTheme.textLight.withValues(alpha: 0.5),
                      ),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                      isDense: true,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGoldenNumberCounter(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.primaryNavy,
            AppTheme.primaryNavy.withValues(alpha: 0.9),
          ],
        ),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        children: [
          Text(
            'YOUR GOLDEN NUMBER',
            style: GoogleFonts.dmSans(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 2.5,
              color: AppTheme.accentGold,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            width: 40,
            height: 2,
            decoration: BoxDecoration(
              color: AppTheme.accentGold.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(1),
            ),
          ),
          const SizedBox(height: 16),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Text(
              _animatedGoldenNumber > 0
                  ? _formatIndian(_animatedGoldenNumber)
                  : '₹ —',
              key: ValueKey<int>(_animatedGoldenNumber.toInt()),
              style: GoogleFonts.playfairDisplay(
                fontSize: 44,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                height: 1.0,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'per month on wants',
            style: GoogleFonts.dmSans(
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(BuildContext context) {
    final badge = _result!['status_badge'] as String;
    final surplusPct = (_result!['surplus_pct'] as num).toDouble();

    Color badgeColor;
    IconData badgeIcon;
    String badgeDescription;

    switch (badge) {
      case 'Saver':
        badgeColor = const Color(0xFF2E7D32);
        badgeIcon = Icons.savings_outlined;
        badgeDescription = 'You save over 30% of your income. Excellent discipline!';
        break;
      case 'Balanced':
        badgeColor = const Color(0xFFE68A00);
        badgeIcon = Icons.balance_outlined;
        badgeDescription = 'You save 10-30% of your income. Good balance!';
        break;
      default:
        badgeColor = const Color(0xFFD32F2F);
        badgeIcon = Icons.trending_down_outlined;
        badgeDescription = 'You save less than 10%. Consider reducing comfort spends.';
    }

    return ScaleTransition(
      scale: _badgeScale,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: badgeColor.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: badgeColor.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        child: Column(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: badgeColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(28),
              ),
              child: Icon(badgeIcon, size: 28, color: badgeColor),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: badgeColor,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                badge.toUpperCase(),
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${surplusPct.toStringAsFixed(1)}% surplus',
              style: GoogleFonts.dmSans(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: badgeColor,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              badgeDescription,
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(
                fontSize: 13,
                color: AppTheme.textMedium,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultSummary(BuildContext context) {
    final needs = (_result!['total_needs'] as num).toDouble();
    final wants = (_result!['golden_number'] as num).toDouble();
    final surplus = (_result!['surplus'] as num).toDouble();
    final needsPct = (_result!['needs_pct'] as num).toDouble();
    final wantsPct = (_result!['wants_pct'] as num).toDouble();
    final surplusPct = (_result!['surplus_pct'] as num).toDouble();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: AppTheme.borderLight.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'BREAKDOWN',
            style: GoogleFonts.dmSans(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 2.0,
              color: AppTheme.accentGold,
            ),
          ),
          const SizedBox(height: 16),
          _summaryRow('Needs (Rent + Basics)', _formatIndian(needs), '${needsPct.toStringAsFixed(1)}%'),
          const SizedBox(height: 10),
          _summaryRow('Wants (Golden Number)', _formatIndian(wants), '${wantsPct.toStringAsFixed(1)}%'),
          const SizedBox(height: 10),
          Divider(color: AppTheme.borderLight.withValues(alpha: 0.3)),
          const SizedBox(height: 10),
          _summaryRow(
            'Surplus (Savings)',
            _formatIndian(surplus),
            '${surplusPct.toStringAsFixed(1)}%',
            isBold: true,
            valueColor: surplus >= 0 ? AppTheme.successGreen : AppTheme.errorRed,
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value, String pct,
      {bool isBold = false, Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.dmSans(
              fontSize: 13,
              fontWeight: isBold ? FontWeight.w600 : FontWeight.normal,
              color: isBold ? AppTheme.primaryNavy : AppTheme.textMedium,
            ),
          ),
        ),
        Text(
          value,
          style: GoogleFonts.dmSans(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: valueColor ?? AppTheme.primaryNavy,
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 50,
          child: Text(
            pct,
            textAlign: TextAlign.right,
            style: GoogleFonts.dmSans(
              fontSize: 12,
              color: AppTheme.textLight,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRetirementCTA(BuildContext context) {
    return InkWell(
      onTap: () {
        final goldenNumber = (_result!['golden_number'] as num).toDouble();
        if (widget.onNavigateToRetirement != null) {
          widget.onNavigateToRetirement!(goldenNumber);
        } else {
          // Default: push retirement calculator via Navigator
          Navigator.of(context).pushNamed(
            '/retirement-calc',
            arguments: {'monthly_expense': goldenNumber},
          );
        }
      },
      borderRadius: BorderRadius.circular(4),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppTheme.accentGold.withValues(alpha: 0.08),
              AppTheme.accentGold.withValues(alpha: 0.03),
            ],
          ),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: AppTheme.accentGold.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppTheme.accentGold.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.trending_up_rounded,
                size: 20,
                color: AppTheme.accentGold,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Use this for your Retirement Plan',
                    style: GoogleFonts.dmSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primaryNavy,
                    ),
                  ),
                  Text(
                    'Pre-fill with your Golden Number →',
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      color: AppTheme.accentGold,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              size: 16,
              color: AppTheme.accentGold,
            ),
          ],
        ),
      ),
    );
  }
}
