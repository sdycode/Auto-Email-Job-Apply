import 'package:flutter/material.dart';

import 'screens/apply_screen.dart';
import 'screens/resumes_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/templates_screen.dart';
import 'services/app_store.dart';

final store = AppStore();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await store.load();
  runApp(const QuickApplyApp());
}

class QuickApplyApp extends StatelessWidget {
  const QuickApplyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) => MaterialApp(
        title: 'Quick Apply',
        debugShowCheckedModeBanner: false,
        theme: _theme(Brightness.light),
        darkTheme: _theme(Brightness.dark),
        themeMode: store.themeMode,
        home: const HomeShell(),
      ),
    );
  }

  static ThemeData _theme(Brightness brightness) => ThemeData(
        colorSchemeSeed: const Color(0xFF0A66C2),
        brightness: brightness,
        useMaterial3: true,
        inputDecorationTheme:
            const InputDecorationTheme(border: OutlineInputBorder()),
      );
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  static const _pages = [
    ApplyScreen(),
    TemplatesScreen(),
    ResumesScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.send_outlined), selectedIcon: Icon(Icons.send), label: 'Apply'),
          NavigationDestination(icon: Icon(Icons.description_outlined), selectedIcon: Icon(Icons.description), label: 'Templates'),
          NavigationDestination(icon: Icon(Icons.attach_file), label: 'Resumes'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }
}
