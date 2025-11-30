import 'package:flutter/material.dart';
import 'package:frontend/dashboard_screen.dart';
import 'package:frontend/upload_screen.dart';
import 'package:frontend/questionnaire_screen.dart';
import 'package:frontend/constants.dart';

class MainAppScreen extends StatefulWidget {
  final VoidCallback onLogout;

  const MainAppScreen({super.key, required this.onLogout});

  @override
  State<MainAppScreen> createState() => _MainAppScreenState();
}

class _MainAppScreenState extends State<MainAppScreen> {
  int _selectedIndex = 0; // 0: Questionnaire, 1: Dashboard, 2: Doc Upload
  int? _questionnaireId;

  List<Widget> _screens() {
    return [
      QuestionnaireScreen(
        backendUrl: kBackendUrl,
        questionnaireId: _questionnaireId,
        onQuestionnaireStarted: (id) {
          setState(() {
            _questionnaireId = id;
            _selectedIndex = 1; // go to Dashboard after start
          });
        },
      ),
      DashboardScreen(
        backendUrl: kBackendUrl,
        questionnaireId: _questionnaireId,
      ),
      UploadScreen(
        questionnaireId: _questionnaireId,
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
      appBar: AppBar(
        title: const Text('Document Parser'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            DrawerHeader(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.white,
                    child: Icon(Icons.person, size: 40, color: Colors.deepPurple),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'User Name', // Placeholder for user name
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white),
                  ),
                  Text(
                    'user@example.com', // Placeholder for user email
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white70),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.assignment),
              title: const Text('Questionnaire'),
              selected: _selectedIndex == 0,
              onTap: () {
                _onItemTapped(0);
                Navigator.pop(context); // Close the drawer
              },
            ),
            ListTile(
              leading: const Icon(Icons.dashboard),
              title: const Text('Dashboard'),
              selected: _selectedIndex == 1,
              onTap: () {
                _onItemTapped(1);
                Navigator.pop(context); // Close the drawer
              },
            ),
            ListTile(
              leading: const Icon(Icons.upload_file),
              title: const Text('Doc Upload'),
              selected: _selectedIndex == 2,
              onTap: () {
                _onItemTapped(2);
                Navigator.pop(context); // Close the drawer
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Logout'),
              onTap: () {
                Navigator.pop(context); // Close the drawer
                widget.onLogout(); // Call the logout callback
              },
            ),
          ],
        ),
      ),
      body: _screens()[_selectedIndex],
    );
  }
}
