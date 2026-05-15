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

/// Retirement Calculator Screen — Gap analysis with 4 result cards,
/// slider for years-to-retire, and step-up SIP recommendation.
class RetirementCalculatorScreen extends StatefulWidget {
  /// Pre-filled monthly expense (e.g. from Spend Right golden number).
  final double? initialMonthlyExpense;

  const RetirementCalculatorScreen({super.key, this.initialMonthlyExpense});

  @override
  State<RetirementCalculatorScreen> createState() =>
      _RetirementCalculatorScreenState();
}

class _RetirementCalculatorScreenState extends State<RetirementCalculatorScreen>
    with TickerProviderStateMixin {
  final _expenseCtrl = TextEditingController();
  final _pensionCtrl = TextEditingController();
  final _corpusCtrl = TextEditingController();
  final _sipCtrl = TextEditingController();

  double _yearsToRetire = 25;
  Map<String, dynamic>? _result;
  bool _isLoading = false;
  String? _error;

  // Card animation controllers
  late List<AnimationController> _cardAnimCtrls;
  late List<Animation<double>> _cardAnimations;

  @override
  void initState() {
    super.initState();

    if (widget.initialMonthlyExpense != null) {
      _expenseCtrl.text = widget.initialMonthlyExpense!.toStringAsFixed(0);
    }

    _cardAnimCtrls = List.generate(
      4,
      (i) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 500),
      ),
    );
    _cardAnimations = _cardAnimCtrls.map((ctrl) {
      return CurvedAnimation(parent: ctrl, curve: Curves.easeOutBack);
    }).toList();
  }

  @override
  void dispose() {
    _expenseCtrl.dispose();
    _pensionCtrl.dispose();
    _corpusCtrl.dispose();
    _sipCtrl.dispose();
    for (final c in _cardAnimCtrls) {
      c.dispose();
    }
    super.dispose();
  }

  void _animateCards() async {
    for (final c in _cardAnimCtrls) {
      c.reset();
    }
    for (int i = 0; i < _cardAnimCtrls.length; i++) {
      await Future.delayed(Duration(milliseconds: 120 * i));
      if (mounted) _cardAnimCtrls[i].forward();
    }
  }

  String _formatIndian(double amount) {
    final isNegative = amount < 0;
    final abs = amount.abs();
    final prefix = isNegative ? '-' : '';
    if (abs >= 10000000) {
      return '$prefix₹${(abs / 10000000).toStringAsFixed(2)} Cr';
    } else if (abs >= 100000) {
      return '$prefix₹${(abs / 100000).toStringAsFixed(2)} L';
    } else if (abs >= 1000) {
      return '$prefix₹${(abs / 1000).toStringAsFixed(1)}K';
    }
    return '$prefix₹${abs.toStringAsFixed(0)}';
  }

  Future<void> _calculate() async {
    final expense = double.tryParse(_expenseCtrl.text.replaceAll(',', ''));
    if (expense == null || expense <= 0) {
      setState(() => _error = 'Please enter a valid monthly expense.');
      return;
    }

    final corpus =
        double.tryParse(_corpusCtrl.text.replaceAll(',', '')) ?? 0;
    final sip = double.tryParse(_sipCtrl.text.replaceAll(',', '')) ?? 0;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final token = await authService.getIdToken();
      final headers = {
        'Content-Type': 'application/json',
      };
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }

      final resp = await http.post(
        Uri.parse('$kBackendUrl/api/free/retirement-calc'),
        headers: headers,
        body: jsonEncode({
          'monthly_expense': expense,
          'years_to_retire': _yearsToRetire,
          'existing_corpus': corpus,
          'ongoing_sip': sip,
          'expected_pension': double.tryParse(_pensionCtrl.text.replaceAll(',', '')) ?? 0,
        }),
      );

      if (resp.statusCode == 200) {
        try {
          final data = jsonDecode(resp.body) as Map<String, dynamic>;
          setState(() {
            _result = data;
            _isLoading = false;
          });
          _animateCards();
        } catch (e) {
          setState(() {
            _error = 'Invalid response format (200 but not JSON).';
            _isLoading = false;
          });
        }
      } else {
        String errorMessage = 'Calculation failed (${resp.statusCode}).';
        try {
          final err = jsonDecode(resp.body);
          errorMessage = err['error'] ?? errorMessage;
        } catch (_) {
          // If body is HTML, show a snippet
          if (resp.body.contains('<html') || resp.body.contains('<!DOCTYPE')) {
            errorMessage = 'Server error (${resp.statusCode}). Please contact support.';
            print('HTML Error detected: ${resp.body.substring(0, math.min(resp.body.length, 200))}');
          }
        }
        setState(() {
          _error = errorMessage;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Connection error. Please check your internet.';
        print('Connection error detail: $e');
        _isLoading = false;
      });
    }
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
          'Retirement Calculator',
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
                  // Monthly Expense Input
                  _buildPremiumInput(
                    context,
                    label: 'MONTHLY EXPENSE',
                    hint: 'Current household expense',
                    controller: _expenseCtrl,
                    icon: Icons.receipt_long_outlined,
                    isPrimary: true,
                  ),
                  const SizedBox(height: 20),

                  // Expected Pension Input
                  _buildPremiumInput(
                    context,
                    label: 'EXPECTED PENSION',
                    hint: 'Guaranteed monthly income',
                    controller: _pensionCtrl,
                    icon: Icons.account_balance_wallet_outlined,
                  ),
                  const SizedBox(height: 20),

                  // Years to Retire Slider
                  _buildYearsSlider(context),
                  const SizedBox(height: 20),

                  // Existing Corpus Input
                  _buildPremiumInput(
                    context,
                    label: 'EXISTING CORPUS',
                    hint: 'Current investment value',
                    controller: _corpusCtrl,
                    icon: Icons.account_balance_outlined,
                  ),
                  const SizedBox(height: 16),

                  // Current SIP Input
                  _buildPremiumInput(
                    context,
                    label: 'CURRENT MONTHLY SIP',
                    hint: 'Ongoing SIP amount',
                    controller: _sipCtrl,
                    icon: Icons.auto_graph_outlined,
                  ),
                  const SizedBox(height: 28),

                  // Calculate Button
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
                              'CALCULATE GAP',
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

                  // Result Cards
                  if (_result != null) ...[
                    const SizedBox(height: 32),
                    _buildResultCards(context),
                    const SizedBox(height: 24),
                    _buildAssumptionsFooter(context),
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
            'How Much Do\nYou Really Need?',
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
            'See exactly how much corpus you need to retire comfortably, and the SIP to get there.',
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

  Widget _buildPremiumInput(
    BuildContext context, {
    required String label,
    required String hint,
    required TextEditingController controller,
    required IconData icon,
    bool isPrimary = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: isPrimary
              ? AppTheme.accentGold.withValues(alpha: 0.4)
              : AppTheme.borderLight.withValues(alpha: 0.4),
          width: isPrimary ? 2 : 1,
        ),
        boxShadow: isPrimary
            ? [
                BoxShadow(
                  color: AppTheme.accentGold.withValues(alpha: 0.06),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
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
              color: isPrimary
                  ? AppTheme.accentGold.withValues(alpha: 0.12)
                  : AppTheme.primaryNavy.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              icon,
              size: 20,
              color: isPrimary ? AppTheme.accentGold : AppTheme.primaryNavy,
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
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.0,
                    color: isPrimary ? AppTheme.accentGold : AppTheme.textLight,
                  ),
                ),
                const SizedBox(height: 4),
                TextField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[\d,.]')),
                  ],
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
    );
  }

  Widget _buildYearsSlider(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: AppTheme.borderLight.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'YEARS TO RETIRE',
                style: GoogleFonts.dmSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.0,
                  color: AppTheme.textLight,
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primaryNavy,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_yearsToRetire.toInt()} yrs',
                  style: GoogleFonts.dmSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: AppTheme.accentGold,
              inactiveTrackColor: AppTheme.borderLight.withValues(alpha: 0.3),
              thumbColor: AppTheme.primaryNavy,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
              overlayColor: AppTheme.accentGold.withValues(alpha: 0.12),
              trackHeight: 4,
            ),
            child: Slider(
              value: _yearsToRetire,
              min: 1,
              max: 40,
              divisions: 39,
              onChanged: (v) => setState(() => _yearsToRetire = v),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '1 yr',
                style: GoogleFonts.dmSans(
                  fontSize: 11,
                  color: AppTheme.textLight,
                ),
              ),
              Text(
                '40 yrs',
                style: GoogleFonts.dmSans(
                  fontSize: 11,
                  color: AppTheme.textLight,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildResultCards(BuildContext context) {
    final target = (_result!['target_corpus'] as num).toDouble();
    final fvExisting = (_result!['fv_existing_corpus'] as num).toDouble();
    final gap = (_result!['gap'] as num).toDouble();
    final requiredSip = (_result!['required_step_up_sip'] as num).toDouble();

    final cards = [
      _ResultCardData(
        title: 'Target Corpus',
        value: _formatIndian(target),
        subtitle: 'Required at retirement',
        icon: Icons.flag_outlined,
        color: AppTheme.primaryNavy,
      ),
      _ResultCardData(
        title: 'FV of Existing',
        value: _formatIndian(fvExisting),
        subtitle: 'What your investments grow to',
        icon: Icons.trending_up_outlined,
        color: AppTheme.tertiarySage,
      ),
      _ResultCardData(
        title: 'The Gap',
        value: _formatIndian(gap),
        subtitle: gap > 0 ? 'Shortfall to bridge' : 'You\'re covered!',
        icon: gap > 0 ? Icons.warning_amber_outlined : Icons.check_circle_outline,
        color: gap > 0 ? AppTheme.errorRed : AppTheme.successGreen,
      ),
      _ResultCardData(
        title: 'Required Starting SIP',
        value: _formatIndian(requiredSip),
        subtitle: '10% annual step-up',
        icon: Icons.rocket_launch_outlined,
        color: AppTheme.accentGold,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'YOUR RETIREMENT ANALYSIS',
          style: GoogleFonts.dmSans(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 2.0,
            color: AppTheme.accentGold,
          ),
        ),
        const SizedBox(height: 4),
        AppTheme.goldAccentBar(width: 40, height: 2),
        const SizedBox(height: 20),
        ...List.generate(cards.length, (i) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: FadeTransition(
              opacity: _cardAnimations[i],
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.3),
                  end: Offset.zero,
                ).animate(_cardAnimations[i]),
                child: _buildResultCard(context, cards[i]),
              ),
            ),
          );
        }),
        const SizedBox(height: 24),
        _buildUpgradeButton(context),
      ],
    );
  }

  Widget _buildUpgradeButton(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    if (!authService.isAuthenticated) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () {
          if (!authService.hasCredits) {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const PaymentScreen()),
            );
          } else {
            // Navigate to MainAppScreen and start questionnaire (index 1 is upload)
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(
                builder: (_) => MainAppScreen(
                  onLogout: () => authService.signOut(),
                  initialIndex: 1,
                ),
              ),
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

  Widget _buildResultCard(BuildContext context, _ResultCardData data) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        border: Border(
          left: BorderSide(color: data.color, width: 4),
          top: BorderSide(
            color: AppTheme.borderLight.withValues(alpha: 0.3),
          ),
          right: BorderSide(
            color: AppTheme.borderLight.withValues(alpha: 0.3),
          ),
          bottom: BorderSide(
            color: AppTheme.borderLight.withValues(alpha: 0.3),
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: data.color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Icon(data.icon, size: 24, color: data.color),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.title,
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textLight,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  data.value,
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: data.color,
                  ),
                ),
                Text(
                  data.subtitle,
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    color: AppTheme.textLight,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAssumptionsFooter(BuildContext context) {
    final assumptions = _result!['assumptions'] as Map<String, dynamic>?;
    if (assumptions == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primaryNavy.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: AppTheme.borderLight.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ASSUMPTIONS',
            style: GoogleFonts.dmSans(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.5,
              color: AppTheme.textLight,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 16,
            runSpacing: 6,
            children: [
              _assumptionChip('Inflation', '${assumptions['inflation_pct']}%'),
              _assumptionChip('Return', '${assumptions['return_pct']}%'),
              _assumptionChip('Step-up', '${assumptions['step_up_pct']}%'),
              _assumptionChip(
                  'Withdrawal', '${assumptions['withdrawal_rate_pct']}%'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _assumptionChip(String label, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label: ',
          style: GoogleFonts.dmSans(
            fontSize: 11,
            color: AppTheme.textLight,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.dmSans(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppTheme.primaryNavy,
          ),
        ),
      ],
    );
  }
}

class _ResultCardData {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;

  _ResultCardData({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
  });
}
