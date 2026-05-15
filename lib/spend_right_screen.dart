import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:frontend/app_theme.dart';
import 'package:frontend/constants.dart';
import 'package:frontend/services/auth_service.dart';
import 'package:provider/provider.dart';
import 'package:frontend/payment_screen.dart';
import 'package:frontend/main_app_screen.dart';

/// Golden Number Calculator — 4 spending questions → ideal monthly income.
class SpendRightScreen extends StatefulWidget {
  final void Function(double goldenNumber)? onNavigateToRetirement;
  const SpendRightScreen({super.key, this.onNavigateToRetirement});

  @override
  State<SpendRightScreen> createState() => _SpendRightScreenState();
}

class _SpendRightScreenState extends State<SpendRightScreen>
    with TickerProviderStateMixin {
  // 4 spending question controllers
  final _clothingCtrl = TextEditingController();
  final _travelCtrl = TextEditingController();
  final _lifestyleCtrl = TextEditingController();
  final _gadgetsCtrl = TextEditingController();
  // Post-reveal actual income
  final _actualIncomeCtrl = TextEditingController();

  // State
  bool _isLoading = false;
  String? _error;
  double _goldenNumber = 0;
  double _totalMonthlyWants = 0;
  double _clothingMonthly = 0;
  double _travelMonthly = 0;
  double _lifestyleMonthly = 0;
  double _gadgetsMonthly = 0;
  bool _revealed = false; // Has the golden number been calculated?
  String? _status; // GOLDEN SPENDER / ON TRACK / ADVENTURE SPENDER
  double _surplusDeficit = 0;

  // Animation
  late AnimationController _revealAnimCtrl;
  late Animation<double> _revealScale;
  late AnimationController _counterCtrl;
  double _animatedGolden = 0;

  @override
  void initState() {
    super.initState();
    _revealAnimCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 600));
    _revealScale = CurvedAnimation(
      parent: _revealAnimCtrl, curve: Curves.elasticOut);
    _counterCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 900))
      ..addListener(() {
        setState(() => _animatedGolden = _counterCtrl.value * _goldenNumber);
      });

    for (final c in [_clothingCtrl, _travelCtrl, _lifestyleCtrl, _gadgetsCtrl]) {
      c.addListener(_onSpendingChanged);
    }
    _actualIncomeCtrl.addListener(_onActualIncomeChanged);
  }

  @override
  void dispose() {
    _clothingCtrl.dispose();
    _travelCtrl.dispose();
    _lifestyleCtrl.dispose();
    _gadgetsCtrl.dispose();
    _actualIncomeCtrl.dispose();
    _revealAnimCtrl.dispose();
    _counterCtrl.dispose();
    super.dispose();
  }

  double _p(String t) => double.tryParse(t.replaceAll(',', '')) ?? 0;

  void _onSpendingChanged() {
    final clothing = _p(_clothingCtrl.text);
    final travel = _p(_travelCtrl.text);
    final lifestyle = _p(_lifestyleCtrl.text);
    final gadgets = _p(_gadgetsCtrl.text);

    final cm = clothing / 12.0;
    final tm = travel / 12.0;
    final lm = lifestyle;
    final gm = gadgets / 36.0;
    final total = cm + tm + lm + gm;

    double gn = 0;
    if (total > 0) {
      final raw = total / 0.38;
      gn = (raw / 1000).round() * 1000.0;
    }

    if (gn != _goldenNumber) {
      setState(() {
        _clothingMonthly = cm;
        _travelMonthly = tm;
        _lifestyleMonthly = lm;
        _gadgetsMonthly = gm;
        _totalMonthlyWants = total;
        _goldenNumber = gn;
        _revealed = gn > 0;
      });
      _counterCtrl.forward(from: 0);
      if (_revealed && !_revealAnimCtrl.isCompleted) {
        _revealAnimCtrl.forward();
      }
      // Re-check status if actual income already entered
      _onActualIncomeChanged();
    }
  }

  void _onActualIncomeChanged() {
    final actual = _p(_actualIncomeCtrl.text);
    if (actual > 0 && _goldenNumber > 0) {
      setState(() {
        _surplusDeficit = actual - _totalMonthlyWants;
        if (actual >= _goldenNumber) {
          _status = 'GOLDEN SPENDER';
        } else if (actual >= _goldenNumber * 0.8) {
          _status = 'ON TRACK';
        } else {
          _status = 'ADVENTURE SPENDER';
        }
      });
    } else {
      setState(() => _status = null);
    }
  }

  Future<void> _verifyWithServer() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final token = await authService.getIdToken();
      final headers = {'Content-Type': 'application/json'};
      if (token != null) headers['Authorization'] = 'Bearer $token';

      final resp = await http.post(
        Uri.parse('$kBackendUrl/api/free/spend-right'),
        headers: headers,
        body: jsonEncode({
          'annual_clothing': _p(_clothingCtrl.text),
          'annual_travel': _p(_travelCtrl.text),
          'monthly_lifestyle': _p(_lifestyleCtrl.text),
          'total_gadget_value': _p(_gadgetsCtrl.text),
          'actual_income': _p(_actualIncomeCtrl.text),
        }),
      );

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        setState(() {
          _goldenNumber = (data['golden_number'] as num).toDouble();
          _totalMonthlyWants = (data['total_monthly_wants'] as num).toDouble();
          final bd = data['breakdown'] as Map<String, dynamic>;
          _clothingMonthly = (bd['clothing_monthly'] as num).toDouble();
          _travelMonthly = (bd['travel_monthly'] as num).toDouble();
          _lifestyleMonthly = (bd['lifestyle_monthly'] as num).toDouble();
          _gadgetsMonthly = (bd['gadgets_monthly'] as num).toDouble();
          _revealed = true;
          if (data.containsKey('status')) {
            _status = data['status'] as String;
            _surplusDeficit = (data['surplus_deficit'] as num).toDouble();
          }
          _isLoading = false;
        });
        _counterCtrl.forward(from: 0);
        _revealAnimCtrl.forward(from: 0);
      } else {
        String msg = 'Calculation failed (${resp.statusCode}).';
        try { msg = (jsonDecode(resp.body))['error'] ?? msg; } catch (_) {}
        setState(() { _error = msg; _isLoading = false; });
      }
    } catch (e) {
      setState(() { _error = 'Connection error. Please check your internet.'; _isLoading = false; });
    }
  }

  String _fmt(double a) {
    if (a.abs() >= 10000000) return '₹${(a / 10000000).toStringAsFixed(2)} Cr';
    if (a.abs() >= 100000) return '₹${(a / 100000).toStringAsFixed(2)} L';
    if (a.abs() >= 1000) return '₹${(a / 1000).toStringAsFixed(1)}K';
    return '₹${a.toStringAsFixed(0)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundCream,
      appBar: AppBar(
        backgroundColor: AppTheme.primaryNavy,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text('Golden Number', style: GoogleFonts.dmSans(fontWeight: FontWeight.w600, letterSpacing: 0.5)),
        leading: IconButton(icon: const Icon(Icons.arrow_back_rounded), onPressed: () => Navigator.of(context).pop()),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHero(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: Column(children: [
                _buildQ(0, Icons.checkroom_outlined, 'Question 1', 'Annual clothing spend', 'Jeans, T-shirts, shoes, blazer, etc.', _clothingCtrl),
                const SizedBox(height: 16),
                _buildQ(1, Icons.flight_outlined, 'Question 2', 'Annual travel / vacation cost', 'Total annual travel budget', _travelCtrl),
                const SizedBox(height: 16),
                _buildQ(2, Icons.restaurant_outlined, 'Question 3', 'Monthly lifestyle spend', 'Entertainment, Netflix, Swiggy, dining, parties', _lifestyleCtrl),
                const SizedBox(height: 16),
                _buildQ(3, Icons.devices_outlined, 'Question 4', 'Total current gadget value', 'Phone + laptop + headphones worth today', _gadgetsCtrl, isLast: true),
                const SizedBox(height: 32),

                // Golden Number Reveal
                _buildGoldenReveal(),

                // Post-reveal: actual income input
                if (_revealed) ...[
                  const SizedBox(height: 28),
                  _buildActualIncomeInput(),
                ],

                // Status badge
                if (_status != null) ...[
                  const SizedBox(height: 24),
                  _buildStatusBadge(),
                ],

                // Breakdown
                if (_revealed) ...[
                  const SizedBox(height: 24),
                  _buildBreakdown(),
                ],

                const SizedBox(height: 24),

                // Verify button
                SizedBox(
                  width: double.infinity, height: 52,
                  child: ElevatedButton(
                    onPressed: _isLoading || !_revealed ? null : _verifyWithServer,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryNavy,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                      elevation: 0,
                    ),
                    child: _isLoading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text('SAVE & VERIFY', style: GoogleFonts.dmSans(fontWeight: FontWeight.w600, letterSpacing: 1.5, fontSize: 14)),
                  ),
                ),

                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: GoogleFonts.dmSans(color: AppTheme.errorRed, fontSize: 13)),
                ],

                // Retirement CTA
                if (_revealed) ...[
                  const SizedBox(height: 32),
                  _buildRetirementCTA(),
                ],
                const SizedBox(height: 40),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHero() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE8E4DF), width: 1)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('FREE TOOL', style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 2.0, color: AppTheme.accentGold)),
        const SizedBox(height: 8),
        Text('Discover Your\nGolden Number', style: GoogleFonts.playfairDisplay(fontSize: 32, fontWeight: FontWeight.bold, color: AppTheme.primaryNavy, height: 1.1)),
        const SizedBox(height: 8),
        AppTheme.goldAccentBar(width: 60, height: 2),
        const SizedBox(height: 12),
        Text('Answer 4 quick questions about your spending.\nWe\'ll tell you what your ideal monthly income should be.',
          style: GoogleFonts.dmSans(fontSize: 14, color: AppTheme.textMedium, height: 1.5)),
      ]),
    );
  }

  Widget _buildQ(int idx, IconData icon, String qLabel, String label, String hint, TextEditingController ctrl, {bool isLast = false}) {
    final isAnnual = idx != 2; // Q3 is monthly, rest are annual or total value
    final suffix = idx == 3 ? '(amortized over 3 years)' : (isAnnual ? '(annual)' : '(monthly)');
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 400 + (idx * 100)),
      curve: Curves.easeOut,
      builder: (ctx, v, child) => Opacity(opacity: v, child: Transform.translate(offset: Offset(0, 20 * (1 - v)), child: child)),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: isLast ? AppTheme.accentGold.withValues(alpha: 0.5) : AppTheme.borderLight.withValues(alpha: 0.4), width: isLast ? 2 : 1),
          boxShadow: isLast ? [BoxShadow(color: AppTheme.accentGold.withValues(alpha: 0.08), blurRadius: 12, offset: const Offset(0, 4))] : [],
        ),
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(color: AppTheme.primaryNavy.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(20)),
            child: Icon(icon, size: 20, color: AppTheme.primaryNavy),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(qLabel, style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.accentGold, letterSpacing: 0.5)),
              const SizedBox(width: 8),
              Text(suffix, style: GoogleFonts.dmSans(fontSize: 10, color: AppTheme.textLight)),
            ]),
            const SizedBox(height: 2),
            Text(label, style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.primaryNavy)),
            const SizedBox(height: 4),
            TextField(
              controller: ctrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d,.]'))],
              style: GoogleFonts.dmSans(fontSize: 18, fontWeight: FontWeight.w600, color: AppTheme.primaryNavy),
              decoration: InputDecoration(
                prefixText: '₹ ',
                prefixStyle: GoogleFonts.dmSans(fontSize: 18, fontWeight: FontWeight.w600, color: AppTheme.textLight),
                hintText: hint,
                hintStyle: GoogleFonts.dmSans(fontSize: 13, color: AppTheme.textLight.withValues(alpha: 0.5)),
                border: InputBorder.none, contentPadding: EdgeInsets.zero, isDense: true,
              ),
            ),
          ])),
        ]),
      ),
    );
  }

  Widget _buildGoldenReveal() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [AppTheme.primaryNavy, AppTheme.primaryNavy.withValues(alpha: 0.9)]),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(children: [
        Text('YOUR GOLDEN NUMBER', style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 2.5, color: AppTheme.accentGold)),
        const SizedBox(height: 4),
        Container(width: 40, height: 2, decoration: BoxDecoration(color: AppTheme.accentGold.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(1))),
        const SizedBox(height: 16),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: Text(
            _animatedGolden > 0 ? _fmt(_animatedGolden) : '₹ —',
            key: ValueKey<int>(_animatedGolden.toInt()),
            style: GoogleFonts.playfairDisplay(fontSize: 44, fontWeight: FontWeight.bold, color: Colors.white, height: 1.0),
          ),
        ),
        const SizedBox(height: 8),
        Text('ideal monthly take-home income',
          style: GoogleFonts.dmSans(fontSize: 13, color: Colors.white.withValues(alpha: 0.6))),
        if (_revealed) ...[
          const SizedBox(height: 6),
          Text('to sustain your current lifestyle comfortably',
            style: GoogleFonts.dmSans(fontSize: 11, color: AppTheme.accentGold.withValues(alpha: 0.7))),
        ],
      ]),
    );
  }

  Widget _buildActualIncomeInput() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppTheme.accentGold.withValues(alpha: 0.3)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('NOW TELL US...', style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 2.0, color: AppTheme.accentGold)),
        const SizedBox(height: 8),
        Row(children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(color: AppTheme.accentGold.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
            child: const Icon(Icons.account_balance_wallet_outlined, size: 20, color: AppTheme.accentGold),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Your actual monthly take-home', style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.primaryNavy)),
            const SizedBox(height: 4),
            TextField(
              controller: _actualIncomeCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d,.]'))],
              style: GoogleFonts.dmSans(fontSize: 18, fontWeight: FontWeight.w600, color: AppTheme.primaryNavy),
              decoration: InputDecoration(
                prefixText: '₹ ',
                prefixStyle: GoogleFonts.dmSans(fontSize: 18, fontWeight: FontWeight.w600, color: AppTheme.textLight),
                hintText: 'After taxes',
                hintStyle: GoogleFonts.dmSans(fontSize: 14, color: AppTheme.textLight.withValues(alpha: 0.5)),
                border: InputBorder.none, contentPadding: EdgeInsets.zero, isDense: true,
              ),
            ),
          ])),
        ]),
      ]),
    );
  }

  Widget _buildStatusBadge() {
    Color badgeColor;
    IconData badgeIcon;
    String emoji;
    String desc;

    switch (_status) {
      case 'GOLDEN SPENDER':
        badgeColor = const Color(0xFF2E7D32);
        badgeIcon = Icons.emoji_events_outlined;
        emoji = '🟢';
        desc = 'Your income comfortably supports your lifestyle. You\'re living within your means!';
        break;
      case 'ON TRACK':
        badgeColor = const Color(0xFFE68A00);
        badgeIcon = Icons.trending_up_outlined;
        emoji = '🟡';
        desc = 'You\'re close! A small income bump or slight spending trim will get you there.';
        break;
      default:
        badgeColor = const Color(0xFFE65100);
        badgeIcon = Icons.explore_outlined;
        emoji = '🟠';
        desc = 'Your spending habits need a higher income to be sustainable. Consider adjustments.';
    }

    return ScaleTransition(
      scale: _revealScale,
      child: Container(
        width: double.infinity, padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: badgeColor.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: badgeColor.withValues(alpha: 0.2)),
        ),
        child: Column(children: [
          Container(
            width: 56, height: 56,
            decoration: BoxDecoration(color: badgeColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(28)),
            child: Icon(badgeIcon, size: 28, color: badgeColor),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(color: badgeColor, borderRadius: BorderRadius.circular(20)),
            child: Text('$emoji ${_status!}', style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1.5, color: Colors.white)),
          ),
          const SizedBox(height: 8),
          Text(_surplusDeficit >= 0 ? '+${_fmt(_surplusDeficit)} surplus' : '${_fmt(_surplusDeficit)} deficit',
            style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w600, color: badgeColor)),
          const SizedBox(height: 4),
          Text(desc, textAlign: TextAlign.center, style: GoogleFonts.dmSans(fontSize: 13, color: AppTheme.textMedium, height: 1.4)),
        ]),
      ),
    );
  }

  Widget _buildBreakdown() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppTheme.borderLight.withValues(alpha: 0.3)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('MONTHLY BREAKDOWN', style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 2.0, color: AppTheme.accentGold)),
        const SizedBox(height: 4),
        Text('Your spending converted to monthly equivalents', style: GoogleFonts.dmSans(fontSize: 12, color: AppTheme.textLight)),
        const SizedBox(height: 16),
        _bRow('👕 Clothing', _fmt(_clothingMonthly), 'annual ÷ 12'),
        const SizedBox(height: 10),
        _bRow('✈️ Travel', _fmt(_travelMonthly), 'annual ÷ 12'),
        const SizedBox(height: 10),
        _bRow('🍕 Lifestyle', _fmt(_lifestyleMonthly), 'as entered'),
        const SizedBox(height: 10),
        _bRow('📱 Gadgets', _fmt(_gadgetsMonthly), 'value ÷ 36 months'),
        const SizedBox(height: 10),
        Divider(color: AppTheme.borderLight.withValues(alpha: 0.3)),
        const SizedBox(height: 10),
        _bRow('Total Monthly Wants', _fmt(_totalMonthlyWants), '≈ 38% of income', isBold: true),
        const SizedBox(height: 20),
        _buildUpgradeButton(),
      ]),
    );
  }

  Widget _bRow(String label, String value, String note, {bool isBold = false}) {
    return Row(children: [
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: GoogleFonts.dmSans(fontSize: 13, fontWeight: isBold ? FontWeight.w600 : FontWeight.normal, color: isBold ? AppTheme.primaryNavy : AppTheme.textMedium)),
        if (!isBold) Text(note, style: GoogleFonts.dmSans(fontSize: 10, color: AppTheme.textLight)),
      ])),
      Text(value, style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.primaryNavy)),
    ]);
  }

  Widget _buildUpgradeButton() {
    final authService = Provider.of<AuthService>(context);
    if (!authService.isAuthenticated) return const SizedBox.shrink();
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () {
          if (!authService.hasCredits) {
            Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PaymentScreen()));
          } else {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => MainAppScreen(onLogout: () => authService.signOut(), initialIndex: 1)),
              (route) => false,
            );
          }
        },
        icon: const Icon(Icons.auto_awesome_outlined, size: 18),
        label: const Text('UPGRADE TO FULL REPORT'),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppTheme.accentGold,
          side: const BorderSide(color: AppTheme.accentGold),
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }

  Widget _buildRetirementCTA() {
    return InkWell(
      onTap: () {
        if (widget.onNavigateToRetirement != null) {
          widget.onNavigateToRetirement!(_totalMonthlyWants);
        } else {
          Navigator.of(context).pushNamed('/retirement-calc', arguments: {'monthly_expense': _totalMonthlyWants});
        }
      },
      borderRadius: BorderRadius.circular(4),
      child: Container(
        width: double.infinity, padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [AppTheme.accentGold.withValues(alpha: 0.08), AppTheme.accentGold.withValues(alpha: 0.03)]),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: AppTheme.accentGold.withValues(alpha: 0.3)),
        ),
        child: Row(children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(color: AppTheme.accentGold.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)),
            child: const Icon(Icons.trending_up_rounded, size: 20, color: AppTheme.accentGold),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Use this for your Retirement Plan', style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.primaryNavy)),
            Text('Pre-fill with your monthly wants →', style: GoogleFonts.dmSans(fontSize: 12, color: AppTheme.accentGold)),
          ])),
          const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: AppTheme.accentGold),
        ]),
      ),
    );
  }
}
