import 'dart:math' as math;

import 'package:flutter/material.dart' hide Element;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/audio/procedural_sfx_engine.dart';
import 'presentation/screens/altar/altar_evolution_screen.dart';
import 'presentation/screens/barracks/barracks_screen.dart';
import 'presentation/screens/sanctuary/sanctuary_screen.dart';
import 'presentation/screens/summon/summon_portal_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Color(0xFF0B0914),
      statusBarIconBrightness: Brightness.light,
    ),
  );
  // Los WAV procedurales se sintetizan una sola vez, tras el primer frame.
  WidgetsBinding.instance.addPostFrameCallback((_) {
    ProceduralSfxEngine.prewarmCache();
  });
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
      home: const WebArcadeFrame(child: HomeShell()),
      debugShowCheckedModeBanner: false,
    );
  }
}

/// Marco arcade vertical para pantallas anchas (navegador de PC).
///
/// - `<= 560px` (móvil/portrait): el juego ocupa el 100% del viewport.
/// - `> 560px` (web de escritorio): se centra un gabinete de 440×920 con borde
///   metálico gótico, el título en vertical a la izquierda y las pistas de
///   control con ratón a la derecha.
class WebArcadeFrame extends StatelessWidget {
  const WebArcadeFrame({
    super.key,
    required this.child,
    this.frameWidth = 440,
    this.frameHeight = 920,
  });

  /// Ancho a partir del cual se muestra el gabinete arcade.
  static const double breakpoint = 560;

  /// Ancho mínimo para mostrar los paneles laterales de título/controles.
  static const double sidePanelBreakpoint = 900;

  static const Key frameKey = Key('web-arcade-frame');

  final Widget child;
  final double frameWidth;
  final double frameHeight;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth <= breakpoint) return child;
        final width = math.min(
          frameWidth,
          math.max(breakpoint, constraints.maxWidth - 48),
        );
        final height = math.min(
          frameHeight,
          math.max(480.0, constraints.maxHeight - 24),
        );
        final showPanels = constraints.maxWidth >= sidePanelBreakpoint;
        return DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF07050B), Color(0xFF150A12), Color(0xFF07050B)],
            ),
          ),
          child: Row(
            children: [
              if (showPanels) const Expanded(child: _VerticalBanner()),
              SizedBox(
                width: width,
                child: Center(
                  child: _GothicBezel(
                    width: width,
                    height: height,
                    child: MediaQuery(
                      data: MediaQuery.of(context).copyWith(
                        size: Size(width, height),
                        padding: EdgeInsets.zero,
                        viewPadding: EdgeInsets.zero,
                        viewInsets: EdgeInsets.zero,
                      ),
                      child: child,
                    ),
                  ),
                ),
              ),
              if (showPanels) const Expanded(child: _ControlHints()),
            ],
          ),
        );
      },
    );
  }
}

class _GothicBezel extends StatelessWidget {
  const _GothicBezel({
    required this.width,
    required this.height,
    required this.child,
  });

  final double width;
  final double height;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: WebArcadeFrame.frameKey,
      width: width,
      height: height,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF4A2630), width: 3),
        boxShadow: const [
          BoxShadow(color: Color(0xCC000000), blurRadius: 40, spreadRadius: 6),
          BoxShadow(color: Color(0x33FF5A26), blurRadius: 24, spreadRadius: 1),
        ],
      ),
      child: child,
    );
  }
}

class _VerticalBanner extends StatelessWidget {
  const _VerticalBanner();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: RotatedBox(
        quarterTurns: 3,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.local_fire_department, color: Color(0xFFFF5A26)),
              SizedBox(width: 10),
              Text(
                'BRIMSTONE: THE SUMMONING',
                maxLines: 1,
                style: TextStyle(
                  color: Color(0xFFB16EFF),
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 6,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ControlHints extends StatelessWidget {
  const _ControlHints();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: RotatedBox(
        quarterTurns: 1,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              _Hint(
                  icon: Icons.touch_app, text: 'CLICK + ARRASTRAR · Fusionar'),
              SizedBox(height: 8),
              _Hint(icon: Icons.swipe_up, text: 'DESLIZAR ↑ · Lanzar esfera'),
              SizedBox(height: 8),
              _Hint(icon: Icons.ads_click, text: 'CLICK EN DIANA · Bullseye'),
              SizedBox(height: 8),
              _Hint(
                  icon: Icons.gesture, text: 'DESLIZAR FUERA · Counter-Flick'),
            ],
          ),
        ),
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: const Color(0xFFFFC93C)),
        const SizedBox(width: 8),
        Text(
          text,
          style: const TextStyle(color: Colors.white54, fontSize: 12),
        ),
      ],
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
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF0B0814),
          border: Border(
            top: BorderSide(
              color: Color(0xFFD4AF37),
              width: 1.5,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Color(0x55000000),
              blurRadius: 10,
              offset: Offset(0, -3),
            ),
          ],
        ),
        child: NavigationBar(
          backgroundColor: const Color(0xFF0B0814),
          indicatorColor: const Color(0xFFD4AF37).withValues(alpha: 0.22),
          selectedIndex: _tab,
          onDestinationSelected: (i) => setState(() => _tab = i),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined, color: Colors.white54),
              selectedIcon: Icon(Icons.home, color: Color(0xFFFFD700)),
              label: 'Santuario',
            ),
            NavigationDestination(
              icon: Icon(Icons.shield_outlined, color: Colors.white54),
              selectedIcon: Icon(Icons.shield, color: Color(0xFFFFD700)),
              label: 'Cuartel',
            ),
            NavigationDestination(
              icon: Icon(Icons.auto_fix_high_outlined, color: Colors.white54),
              selectedIcon: Icon(Icons.auto_fix_high, color: Color(0xFFFFD700)),
              label: 'Altar',
            ),
            NavigationDestination(
              icon: Icon(Icons.auto_awesome_outlined, color: Colors.white54),
              selectedIcon: Icon(Icons.auto_awesome, color: Color(0xFFFFD700)),
              label: 'Portal',
            ),
          ],
        ),
      ),
    );
  }
}
