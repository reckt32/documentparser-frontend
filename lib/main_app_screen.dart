import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:frontend/upload_screen.dart';
import 'package:frontend/questionnaire_screen.dart';
import 'package:frontend/constants.dart';
import 'package:frontend/home_screen.dart';
import 'package:frontend/app_theme.dart';
import 'package:frontend/services/auth_service.dart';

class MainAppScreen extends StatefulWidget {
  final VoidCallback onLogout;

  const MainAppScreen({super.key, required this.onLogout});

  @override
  State<MainAppScreen> createState() => _MainAppScreenState();
}

class _MainAppScreenState extends State<MainAppScreen> {
  // Flow: 0: Home, 1: Doc Upload, 2: Questionnaire
  int _selectedIndex = 0;
  int? _questionnaireId;
  Map<String, dynamic>? _prefillData; // from backend analysis/docInsights

  List<Widget> _screens() {
    print('[MainAppScreen] Building screens with _questionnaireId: $_questionnaireId, _prefillData: $_prefillData');
    return [
      HomeScreen(
        onStart: () {
          setState(() {
            _selectedIndex = 1; // go to Upload first
          });
        },
      ),
      UploadScreen(
        questionnaireId: _questionnaireId,
        // After successful upload (with qid), move to questionnaire with prefill
        onUploaded: (int? qid, Map<String, dynamic>? prefill) {
          print('[MainAppScreen] onUploaded callback received - qid: $qid, prefill: $prefill');
          print('[MainAppScreen] Prefill keys: ${prefill?.keys.toList()}');
          setState(() {
            _questionnaireId = qid ?? _questionnaireId;
            _prefillData = prefill;
            _selectedIndex = 2;
          });
          print('[MainAppScreen] After setState - _questionnaireId: $_questionnaireId, _prefillData: $_prefillData');
        },
      ),
      QuestionnaireScreen(
        backendUrl: kBackendUrl,
        questionnaireId: _questionnaireId,
        prefillData: _prefillData,
        onQuestionnaireStarted: (id) {
          print('[MainAppScreen] onQuestionnaireStarted - id: $id');
          setState(() {
            _questionnaireId = id;
          });
        },
        onCompleted: () {
          // stay on questionnaire after submit
        },
      ),
    ];
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundCream,
      appBar: AppBar(
        title: Row(
          children: [
            Text(
              'Document',
              style: Theme.of(context).appBarTheme.titleTextStyle,
            ),
            const SizedBox(width: 6),
            Text(
              'Parser',
              style: Theme.of(context).appBarTheme.titleTextStyle?.copyWith(
                color: AppTheme.accentGold,
              ),
            ),
          ],
        ),
        backgroundColor: AppTheme.primaryNavy,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      drawer: Builder(
        builder: (context) {
          final authService = Provider.of<AuthService>(context);
          return Drawer(
            backgroundColor: Colors.white,
            child: Column(
              children: <Widget>[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(32),
                  decoration: const BoxDecoration(
                    color: AppTheme.primaryNavy,
                  ),
                  child: SafeArea(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: AppTheme.accentGold,
                            borderRadius: BorderRadius.circular(2),
                          ),
                          child: authService.photoUrl != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(2),
                                  child: Image.network(
                                    authService.photoUrl!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => const Icon(
                                      Icons.person,
                                      size: 32,
                                      color: AppTheme.primaryNavy,
                                    ),
                                  ),
                                )
                              : const Icon(
                                  Icons.person,
                                  size: 32,
                                  color: AppTheme.primaryNavy,
                                ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          authService.displayName ?? 'User',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          authService.email ?? '',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.white.withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 16),
                children: [
                  _buildDrawerItem(
                    context,
                    icon: Icons.home_outlined,
                    title: 'Home',
                    isSelected: _selectedIndex == 0,
                    onTap: () {
                      _onItemTapped(0);
                      Navigator.pop(context);
                    },
                  ),
                  _buildDrawerItem(
                    context,
                    icon: Icons.upload_file_outlined,
                    title: 'Doc Upload',
                    isSelected: _selectedIndex == 1,
                    onTap: () {
                      _onItemTapped(1);
                      Navigator.pop(context);
                    },
                  ),
                  _buildDrawerItem(
                    context,
                    icon: Icons.assignment_outlined,
                    title: 'Questionnaire',
                    isSelected: _selectedIndex == 2,
                    onTap: () {
                      _onItemTapped(2);
                      Navigator.pop(context);
                    },
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Divider(
                      color: AppTheme.borderLight.withValues(alpha: 0.3),
                      height: 1,
                    ),
                  ),
                  _buildDrawerItem(
                    context,
                    icon: Icons.logout_outlined,
                    title: 'Logout',
                    isSelected: false,
                    onTap: () {
                      Navigator.pop(context);
                      widget.onLogout();
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      );
        },
      ),
      body: _screens()[_selectedIndex],
    );
  }

  Widget _buildDrawerItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: isSelected ? AppTheme.accentGold : Colors.transparent,
            width: 3,
          ),
        ),
      ),
      child: ListTile(
        leading: Icon(
          icon,
          color: isSelected ? AppTheme.primaryNavy : AppTheme.textMedium,
          size: 22,
        ),
        title: Text(
          title,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: isSelected ? AppTheme.primaryNavy : AppTheme.textMedium,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        selected: isSelected,
        selectedTileColor: AppTheme.accentGold.withValues(alpha: 0.08),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(2),
        ),
        onTap: onTap,
      ),
    );
  }
}
