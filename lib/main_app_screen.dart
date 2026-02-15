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



  // ---------------------------------------------------------------------------
  // Profile popup (replaces drawer)
  // ---------------------------------------------------------------------------

  void _showProfilePopup(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);
    final RenderBox button = context.findRenderObject() as RenderBox;
    final RenderBox overlay =
        Navigator.of(context).overlay!.context.findRenderObject() as RenderBox;
    final offset = button.localToGlobal(Offset.zero, ancestor: overlay);

    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        offset.dx + button.size.width - 260,
        offset.dy + button.size.height + 4,
        overlay.size.width - offset.dx - button.size.width,
        0,
      ),
      constraints: const BoxConstraints(minWidth: 260, maxWidth: 300),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      color: Colors.white,
      elevation: 8,
      items: [
        // User info header (non-selectable)
        PopupMenuItem<String>(
          enabled: false,
          padding: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Row(
              children: [
                // Avatar
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppTheme.accentGold,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: authService.photoUrl != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(22),
                          child: Image.network(
                            authService.photoUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.person,
                              size: 24,
                              color: AppTheme.primaryNavy,
                            ),
                          ),
                        )
                      : const Icon(
                          Icons.person,
                          size: 24,
                          color: AppTheme.primaryNavy,
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        authService.displayName ?? 'User',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primaryNavy,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        authService.email ?? '',
                        style: const TextStyle(
                          color: AppTheme.textLight,
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // Divider
        const PopupMenuItem<String>(
          enabled: false,
          height: 1,
          padding: EdgeInsets.zero,
          child: Divider(height: 1),
        ),

        // Credits
        PopupMenuItem<String>(
          enabled: false,
          padding: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppTheme.accentGold.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.stars_rounded,
                    size: 18,
                    color: AppTheme.accentGold,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Report Credits',
                        style: TextStyle(
                          color: AppTheme.textLight,
                          fontSize: 11,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${authService.reportCredits} remaining',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primaryNavy,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // Divider
        const PopupMenuItem<String>(
          enabled: false,
          height: 1,
          padding: EdgeInsets.zero,
          child: Divider(height: 1),
        ),

        // Logout
        PopupMenuItem<String>(
          value: 'logout',
          padding: EdgeInsets.zero,
          child: const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(
              children: [
                Icon(
                  Icons.logout_rounded,
                  size: 20,
                  color: AppTheme.errorRed,
                ),
                SizedBox(width: 12),
                Text(
                  'Logout',
                  style: TextStyle(
                    color: AppTheme.errorRed,
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ).then((value) {
      if (value == 'logout') {
        widget.onLogout();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);

    return Scaffold(
      backgroundColor: AppTheme.backgroundCream,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            Text(
              'Meerkat',
              style: Theme.of(context).appBarTheme.titleTextStyle,
            ),
          ],
        ),
        backgroundColor: AppTheme.primaryNavy,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          // Profile button
          Builder(
            builder: (buttonContext) {
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () => _showProfilePopup(buttonContext),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Credits badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppTheme.accentGold.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.stars_rounded,
                                size: 14,
                                color: AppTheme.accentGold,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${authService.reportCredits}',
                                style: const TextStyle(
                                  color: AppTheme.accentGold,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Avatar
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: AppTheme.accentGold,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.3),
                              width: 1.5,
                            ),
                          ),
                          child: authService.photoUrl != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: Image.network(
                                    authService.photoUrl!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => const Icon(
                                      Icons.person,
                                      size: 18,
                                      color: AppTheme.primaryNavy,
                                    ),
                                  ),
                                )
                              : const Icon(
                                  Icons.person,
                                  size: 18,
                                  color: AppTheme.primaryNavy,
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: _screens()[_selectedIndex],
    );
  }
}
