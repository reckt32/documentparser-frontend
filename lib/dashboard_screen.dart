import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

class DashboardScreen extends StatefulWidget {
  final String backendUrl;
  final int? questionnaireId;

  const DashboardScreen({
    super.key,
    required this.backendUrl,
    required this.questionnaireId,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _isGenerating = false;
  String? _planUrl;
  String _status = '';

  Future<void> _generatePlan() async {
    if (widget.questionnaireId == null) {
      setState(() {
        _status = 'Start questionnaire first.';
      });
      return;
    }
    setState(() {
      _isGenerating = true;
      _status = 'Generating financial plan...';
      _planUrl = null;
    });
    try {
      final resp = await http.post(
        Uri.parse('${widget.backendUrl}/report/generate'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'questionnaire_id': widget.questionnaireId,
          'useLLM': false,
        }),
      );
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        setState(() {
          _planUrl = data['financial_plan_pdf_url'] as String?;
          _status = 'Financial plan generated.';
        });
      } else if (resp.statusCode == 402) {
        setState(() {
          _status = 'No report credits remaining. Please purchase more credits to generate reports.';
        });
      } else {
        setState(() {
          _status = 'Failed: ${resp.statusCode} ${resp.body}';
        });
      }
    } catch (e) {
      setState(() {
        _status = 'Error: $e';
      });
    } finally {
      setState(() {
        _isGenerating = false;
      });
    }
  }

  Future<void> _openPlan() async {
    if (_planUrl == null) return;
    final uri = Uri.parse(_planUrl!);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final hasQid = widget.questionnaireId != null;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Generate Plan Section
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              margin: const EdgeInsets.only(bottom: 20),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Financial Plan',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.deepPurple,
                          ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      hasQid
                          ? 'Questionnaire ID: ${widget.questionnaireId}'
                          : 'Start the questionnaire to enable plan generation.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        ElevatedButton.icon(
                          onPressed: (!hasQid || _isGenerating) ? null : _generatePlan,
                          icon: const Icon(Icons.auto_graph),
                          label: const Text('Generate Financial Plan'),
                        ),
                        const SizedBox(width: 12),
                        if (_planUrl != null)
                          ElevatedButton.icon(
                            onPressed: _openPlan,
                            icon: const Icon(Icons.picture_as_pdf),
                            label: const Text('Open Plan PDF'),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (_status.isNotEmpty)
                      Text(
                        _status,
                        style: TextStyle(
                          color: _status.startsWith('Failed') || _status.startsWith('Error')
                              ? Colors.red
                              : Colors.green,
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // User Profile Section
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              margin: const EdgeInsets.only(bottom: 30),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Row(
                  children: [
                    const CircleAvatar(
                      radius: 40,
                      backgroundColor: Colors.deepPurpleAccent,
                      child: Icon(Icons.person, size: 50, color: Colors.white),
                    ),
                    const SizedBox(width: 20),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Welcome, User!',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.deepPurple,
                              ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          'user@example.com',
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                color: Colors.grey[600],
                              ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Finance Insights Section
            Text(
              'Financial Insights',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.deepPurple,
                  ),
            ),
            const SizedBox(height: 20),
            _buildFinanceCard(
              context,
              icon: Icons.trending_up,
              title: 'Market Trends',
              description: 'Stocks are showing an upward trend this quarter. Consider diversifying your portfolio.',
              color: Colors.green,
            ),
            _buildFinanceCard(
              context,
              icon: Icons.account_balance_wallet,
              title: 'Savings Rate',
              description: 'Your current savings rate is 15%. Aim for 20% to reach your goals faster.',
              color: Colors.blue,
            ),
            _buildFinanceCard(
              context,
              icon: Icons.lightbulb_outline,
              title: 'Investment Tip',
              description: 'Explore low-cost index funds for long-term growth and stability.',
              color: Colors.orange,
            ),
            _buildFinanceCard(
              context,
              icon: Icons.pie_chart,
              title: 'Portfolio Allocation',
              description: 'Your portfolio is 60% equity, 30% debt, and 10% gold. Review for rebalancing.',
              color: Colors.redAccent,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFinanceCard(BuildContext context,
      {required IconData icon, required String title, required String description, required Color color}) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.only(bottom: 15),
      child: Padding(
        padding: const EdgeInsets.all(15.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 30, color: color),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    description,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[700],
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
}
