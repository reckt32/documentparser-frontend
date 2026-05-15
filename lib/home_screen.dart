import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:frontend/app_theme.dart';
import 'package:frontend/spend_right_screen.dart';
import 'package:frontend/retirement_calculator_screen.dart';
import 'package:frontend/services/auth_service.dart';
import 'package:provider/provider.dart';
import 'package:frontend/payment_screen.dart';

class HomeScreen extends StatelessWidget {
  final VoidCallback onStart;
  final VoidCallback onLoginRequested;

  const HomeScreen({super.key, required this.onStart, required this.onLoginRequested});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Hero section with navy background
          _buildHeroSection(context),
          // Free Financial Tools
          _buildFreeToolsSection(context),
          // Features section
          _buildFeaturesSection(context),
          // CTA section
          _buildCTASection(context),
        ],
      ),
    );
  }

  Widget _buildHeroSection(BuildContext context) {
    return Container(
      color: AppTheme.primaryNavy,
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 80),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Primary logo
          LayoutBuilder(
            builder: (context, constraints) {
              final isSmall = MediaQuery.of(context).size.width < 600;
              return ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: isSmall ? 100 : 120,
                  maxWidth: isSmall ? 260 : 320,
                ),
                child: Image.asset(
                  'assets/primarylogo.png',
                  fit: BoxFit.contain,
                ),
              );
            },
          ),
          const SizedBox(height: 24),
          // Gold accent bar
          AppTheme.goldAccentBar(width: 80, height: 3),
          const SizedBox(height: 32),
          // Large display text with split typography
          Text(
            'Meerkat',
            style: Theme.of(context).textTheme.displayLarge?.copyWith(
                  color: Colors.white,
                  fontSize: 52,
                ),
          ),
          Text(
            'Your Watchful Advisor',
            style: Theme.of(context).textTheme.displayLarge?.copyWith(
                  color: AppTheme.accentGold,
                  fontSize: 52,
                ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: 600,
            child: Text(
              'Upload your financial documents first. We will prefill the questionnaire using extracted data; you can edit if needed.',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 16,
                    height: 1.6,
                  ),
            ),
          ),
          const SizedBox(height: 48),
          // CTA Button
          SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: () {
                final auth = Provider.of<AuthService>(context, listen: false);
                if (!auth.isAuthenticated) {
                  onLoginRequested();
                  return;
                }
                if (!auth.hasCredits) {
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PaymentScreen()));
                  return;
                }
                onStart();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentGold,
                foregroundColor: AppTheme.primaryNavy,
                padding: const EdgeInsets.symmetric(horizontal: 40),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Start Questionnaire'),
                  const SizedBox(width: 12),
                  Container(
                    width: 1,
                    height: 20,
                    color: AppTheme.primaryNavy.withValues(alpha: 0.3),
                  ),
                  const SizedBox(width: 12),
                  const Icon(Icons.arrow_forward, size: 18),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturesSection(BuildContext context) {
    return Container(
      color: AppTheme.backgroundCream,
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 80),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'HOW IT WORKS',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: AppTheme.accentGold,
                  letterSpacing: 2.0,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 24),
          Text(
            'Three Simple Steps',
            style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                  color: AppTheme.primaryNavy,
                ),
          ),
          const SizedBox(height: 48),
          // Feature cards in asymmetric grid
          _buildNumberedFeature(
            context,
            number: '01',
            title: 'Upload Documents',
            description:
                'Upload bank statements, ITR, insurance documents, and mutual fund CAS. Our system securely processes multiple document types.',
          ),
          const SizedBox(height: 32),
          _buildNumberedFeature(
            context,
            number: '02',
            title: 'Review & Complete',
            description:
                'Our technology extracts key information and prefills your financial questionnaire. Review and edit as needed.',
          ),
          const SizedBox(height: 32),
          _buildNumberedFeature(
            context,
            number: '03',
            title: 'Generate Plan',
            description:
                'Receive a comprehensive financial plan based on your complete profile, goals, and risk tolerance.',
          ),
        ],
      ),
    );
  }

  Widget _buildFreeToolsSection(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 60),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'FREE TOOLS',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: AppTheme.accentGold,
                  letterSpacing: 2.0,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 16),
          Text(
            'Financial Health Check',
            style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                  color: AppTheme.primaryNavy,
                ),
          ),
          const SizedBox(height: 8),
          AppTheme.goldAccentBar(width: 60, height: 2),
          const SizedBox(height: 12),
          Text(
            'Start with these complimentary tools — no documents required.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 32),
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 600;
              final cards = [
                _buildToolCard(
                  context,
                  icon: Icons.pie_chart_outline_outlined,
                  title: 'Spend Right',
                  subtitle: 'Discover your Golden Number',
                  description: 'See how your income splits between needs, wants, and savings.',
                  onTap: () {
                    final auth = Provider.of<AuthService>(context, listen: false);
                    if (!auth.isAuthenticated) {
                      onLoginRequested();
                      return;
                    }
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => SpendRightScreen(
                        onNavigateToRetirement: (goldenNumber) {
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute(
                              builder: (_) => RetirementCalculatorScreen(
                                initialMonthlyExpense: goldenNumber,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  );
                },
              ),
                _buildToolCard(
                  context,
                  icon: Icons.show_chart_outlined,
                  title: 'Retirement Calculator',
                  subtitle: 'How much do you really need?',
                  description: 'Gap analysis with step-up SIP to reach your retirement corpus.',
                  onTap: () {
                    final auth = Provider.of<AuthService>(context, listen: false);
                    if (!auth.isAuthenticated) {
                      onLoginRequested();
                      return;
                    }
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const RetirementCalculatorScreen(),
                      ),
                    );
                  },
                ),
              ];

              if (isWide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: cards[0]),
                    const SizedBox(width: 20),
                    Expanded(child: cards[1]),
                  ],
                );
              }
              return Column(
                children: [
                  cards[0],
                  const SizedBox(height: 16),
                  cards[1],
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildToolCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required String description,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppTheme.backgroundCream,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: AppTheme.accentGold.withValues(alpha: 0.2),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppTheme.accentGold.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Icon(icon, size: 28, color: AppTheme.accentGold),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: AppTheme.primaryNavy,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: GoogleFonts.dmSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.accentGold,
                ),
              ),
              const SizedBox(height: 8),
              AppTheme.goldAccentBar(width: 40, height: 2),
              const SizedBox(height: 12),
              Text(
                description,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Text(
                    'Try Free',
                    style: GoogleFonts.dmSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primaryNavy,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(
                    Icons.arrow_forward_rounded,
                    size: 16,
                    color: AppTheme.primaryNavy,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNumberedFeature(
    BuildContext context, {
    required String number,
    required String title,
    required String description,
  }) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(
          color: AppTheme.borderLight.withValues(alpha: 0.3),
          width: 1,
        ),
        borderRadius: BorderRadius.circular(2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Number badge
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              border: Border.all(
                color: AppTheme.accentGold,
                width: 2,
              ),
              borderRadius: BorderRadius.circular(2),
            ),
            child: Center(
              child: Text(
                number,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppTheme.accentGold,
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ),
          ),
          const SizedBox(width: 24),
          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: AppTheme.primaryNavy,
                      ),
                ),
                const SizedBox(height: 12),
                AppTheme.goldAccentBar(width: 60, height: 2),
                const SizedBox(height: 12),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCTASection(BuildContext context) {
    return Container(
      color: AppTheme.backgroundCream,
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 60),
      child: Container(
        padding: const EdgeInsets.all(60),
        decoration: BoxDecoration(
          color: AppTheme.primaryNavy,
          border: Border.all(
            color: AppTheme.accentGold.withValues(alpha: 0.3),
            width: 1,
          ),
          borderRadius: BorderRadius.circular(2),
        ),
        child: Column(
          children: [
            Text(
              'Ready to Begin?',
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    color: Colors.white,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'Start by uploading your financial documents',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: () {
                  final auth = Provider.of<AuthService>(context, listen: false);
                  if (!auth.isAuthenticated) {
                    onLoginRequested();
                    return;
                  }
                  if (!auth.hasCredits) {
                    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PaymentScreen()));
                    return;
                  }
                  onStart();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentGold,
                  foregroundColor: AppTheme.primaryNavy,
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                ),
                child: const Text('Begin Process'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
