import 'package:flutter/material.dart' hide Element;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'presentation/screens/altar/altar_evolution_screen.dart';
import 'presentation/screens/barracks/barracks_screen.dart';
import 'presentation/screens/sanctuary/sanctuary_screen.dart';
import 'presentation/screens/summon/summon_portal_screen.dart';

void main() {
  runApp(const ProviderScope(child: BrimstoneApp()));
}

class BrimstoneApp extends StatelessWidget {
  const BrimstoneApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Brimstone: The Summoning',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0C0608),
        snackBarTheme: const SnackBarThemeData(
          backgroundColor: Color(0xFF2A1116),
          contentTextStyle: TextStyle(color: Colors.white),
        ),
      ),
      home: const HomeShell(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tab = 0;

  static const _screens = [
    SanctuaryScreen(),
    BarracksScreen(),
    AltarEvolutionScreen(),
    SummonPortalScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _tab, children: _screens),
      bottomNavigationBar: NavigationBar(
        backgroundColor: const Color(0xFF14090D),
        indicatorColor: const Color(0xFFB16EFF).withValues(alpha: 0.25),
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined, color: Colors.white54),
            selectedIcon: Icon(Icons.home, color: Color(0xFFB16EFF)),
            label: 'Santuario',
          ),
          NavigationDestination(
            icon: Icon(Icons.shield_outlined, color: Colors.white54),
            selectedIcon: Icon(Icons.shield, color: Color(0xFFB16EFF)),
            label: 'Cuartel',
          ),
          NavigationDestination(
            icon: Icon(Icons.auto_fix_high_outlined, color: Colors.white54),
            selectedIcon: Icon(Icons.auto_fix_high, color: Color(0xFFFFC93C)),
            label: 'Altar',
          ),
          NavigationDestination(
            icon: Icon(Icons.auto_awesome_outlined, color: Colors.white54),
            selectedIcon: Icon(Icons.auto_awesome, color: Color(0xFFB16EFF)),
            label: 'Portal',
          ),
        ],
      ),
    );
  }
}
