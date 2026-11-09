import 'dart:math' as math;

import 'package:flutter/material.dart' hide Element;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/audio/procedural_sfx_engine.dart';
import 'core/theme/design_tokens.dart';
import 'presentation/screens/altar/altar_evolution_screen.dart';
import 'presentation/screens/barracks/barracks_screen.dart';
import 'presentation/screens/sanctuary/sanctuary_screen.dart';
import 'presentation/screens/summon/summon_portal_screen.dart';

/// Clave del Navigator raíz: el guardián de errores la usa para volver
/// a la raíz (Santuario) desde cualquier pila rota.
final GlobalKey<NavigatorState> brimstoneNavigatorKey =
    GlobalKey<NavigatorState>();

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
  // Guardián: jamás pantalla gris en Release/Web. Un error de render
  // muestra una tarjeta oscura con el detalle técnico y salida al Santuario.
  ErrorWidget.builder = (FlutterErrorDetails details) => Directionality(
        textDirection: TextDirection.ltr,
        child: ColoredBox(
          color: const Color(0xFF14090D),
          child: Center(
            child: Container(
              margin: const EdgeInsets.all(24),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF1A0A0F),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFB16EFF), width: 2),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('ERROR DE RENDICIÓN',
                      style: TextStyle(
                          color: Color(0xFFB16EFF),
                          fontSize: 16,
                          fontWeight: FontWeight.w900)),
                  const SizedBox(height: 10),
                  Flexible(
                    child: SingleChildScrollView(
                      child: Text(
                        details.exception.toString(),
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 11),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Material(
                    color: Colors.transparent,
                    child: ElevatedButton(
                      onPressed: () {
                        final nav = brimstoneNavigatorKey.currentState;
                        if (nav != null) {
                          nav.popUntil((route) => route.isFirst);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFB16EFF),
                        foregroundColor: Colors.black,
                      ),
                      child: const Text('Volver al Santuario'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
  runApp(const ProviderScope(child: BrimstoneApp()));
}

class BrimstoneApp extends StatelessWidget {
  const BrimstoneApp({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = _buildBrimstoneTheme();
    return MaterialApp(
      title: 'Brimstone: The Summoning',
      theme: theme,
      builder: (context, child) => Material(
        color: BrimstoneTokens.bgAbyss,
        child: WebArcadeFrame(child: child ?? const SizedBox.shrink()),
      ),
      navigatorKey: brimstoneNavigatorKey,
      home: const HomeShell(),
      debugShowCheckedModeBanner: false,
    );
  }

  ThemeData _buildBrimstoneTheme() {
    final base = ThemeData.dark();
    return base.copyWith(
      scaffoldBackgroundColor: BrimstoneTokens.bgAbyss,
      cardColor: BrimstoneTokens.surfaceBase,
      canvasColor: BrimstoneTokens.surfaceBase,
      dialogTheme: DialogThemeData(
        backgroundColor: BrimstoneTokens.surfaceElevated,
        surfaceTintColor: Colors.transparent,
      ),
      shadowColor: Colors.black,
      dividerColor: BrimstoneAccents.goldMuted.withValues(alpha: 0.3),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: BrimstoneTokens.surfaceElevated,
        contentTextStyle: BrimstoneTypography.bodyMD.copyWith(
          color: BrimstoneTokens.textPrimary,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(BrimstoneRadii.radiusMD),
        ),
        behavior: SnackBarBehavior.floating,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: BrimstoneTokens.surfaceBase,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleTextStyle: BrimstoneTypography.headingLG,
        iconTheme: IconThemeData(color: BrimstoneTokens.goldPrimary),
        actionsIconTheme: IconThemeData(color: BrimstoneTokens.goldPrimary),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: BrimstoneTokens.surfaceBase,
        selectedItemColor: BrimstoneTokens.goldPrimary,
        unselectedItemColor: BrimstoneTokens.textMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: BrimstoneTokens.surfaceBase,
        indicatorColor: BrimstoneTokens.goldPrimary.withValues(alpha: 0.22),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return BrimstoneTypography.labelSM.copyWith(
              color: BrimstoneTokens.goldPrimary,
            );
          }
          return BrimstoneTypography.labelSM.copyWith(
            color: BrimstoneTokens.textMuted,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: BrimstoneTokens.goldPrimary);
          }
          return IconThemeData(color: BrimstoneTokens.textMuted);
        }),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: BrimstoneTokens.goldPrimary,
          foregroundColor: BrimstoneTokens.textOnGold,
          disabledBackgroundColor:
              BrimstoneTokens.goldMuted.withValues(alpha: 0.3),
          disabledForegroundColor: BrimstoneTokens.textMuted,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(BrimstoneRadii.radiusMD),
            side: BorderSide(color: BrimstoneTokens.goldPrimary, width: 1.5),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: BrimstoneSpacing.spaceLG,
            vertical: BrimstoneSpacing.spaceSM,
          ),
          textStyle: BrimstoneTypography.buttonPrimary,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: BrimstoneTokens.goldPrimary,
          disabledForegroundColor: BrimstoneTokens.textMuted,
          side: BorderSide(color: BrimstoneTokens.goldMuted, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(BrimstoneRadii.radiusMD),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: BrimstoneSpacing.spaceLG,
            vertical: BrimstoneSpacing.spaceSM,
          ),
          textStyle: BrimstoneTypography.buttonSecondary,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: BrimstoneTokens.textSecondary,
          disabledForegroundColor: BrimstoneTokens.textMuted,
          textStyle: BrimstoneTypography.buttonGhost,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: BrimstoneTokens.surfaceInteractive,
        hintStyle: BrimstoneTypography.bodySM.copyWith(
          color: BrimstoneTokens.textMuted,
        ),
        labelStyle: BrimstoneTypography.bodySM.copyWith(
          color: BrimstoneTokens.textSecondary,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(BrimstoneRadii.radiusSM),
          borderSide: BorderSide(color: BrimstoneTokens.goldMuted),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(BrimstoneRadii.radiusSM),
          borderSide: BorderSide(color: BrimstoneTokens.goldMuted),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(BrimstoneRadii.radiusSM),
          borderSide: BorderSide(color: BrimstoneTokens.goldBright, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(BrimstoneRadii.radiusSM),
          borderSide: BorderSide(color: BrimstoneTokens.danger),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: BrimstoneSpacing.spaceMD,
          vertical: BrimstoneSpacing.spaceSM,
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: BrimstoneTokens.surfaceInteractive,
        disabledColor:
            BrimstoneTokens.surfaceInteractive.withValues(alpha: 0.5),
        selectedColor: BrimstoneTokens.goldPrimary.withValues(alpha: 0.2),
        secondarySelectedColor:
            BrimstoneTokens.goldPrimary.withValues(alpha: 0.3),
        padding: const EdgeInsets.symmetric(
          horizontal: BrimstoneSpacing.spaceSM,
          vertical: BrimstoneSpacing.spaceXS,
        ),
        labelStyle: BrimstoneTypography.bodySM.copyWith(
          color: BrimstoneTokens.textPrimary,
        ),
        secondaryLabelStyle: BrimstoneTypography.bodySM.copyWith(
          color: BrimstoneTokens.textOnGold,
        ),
        side: BorderSide(color: BrimstoneTokens.goldMuted),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(BrimstoneRadii.radiusSM),
        ),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: BrimstoneTokens.goldPrimary,
        unselectedLabelColor: BrimstoneTokens.textMuted,
        indicatorColor: BrimstoneTokens.goldPrimary,
        indicatorSize: TabBarIndicatorSize.tab,
        labelStyle: BrimstoneTypography.labelMD,
        unselectedLabelStyle: BrimstoneTypography.labelMD,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: BrimstoneTokens.surfaceElevated,
          borderRadius: BorderRadius.circular(BrimstoneRadii.radiusSM),
          border: Border.all(color: BrimstoneTokens.goldMuted),
        ),
        textStyle: BrimstoneTypography.bodyXS.copyWith(
          color: BrimstoneTokens.textPrimary,
        ),
        preferBelow: false,
        verticalOffset: 24,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: BrimstoneTokens.surfaceElevated,
        surfaceTintColor: Colors.transparent,
        elevation: 24,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(BrimstoneRadii.radiusLG),
          ),
          side: BorderSide(color: BrimstoneTokens.goldMuted, width: 1.5),
        ),
        modalBackgroundColor: BrimstoneSurfaces.surfaceOverlay,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: BrimstoneTokens.goldPrimary,
        linearTrackColor: BrimstoneTokens.goldMuted.withValues(alpha: 0.3),
        circularTrackColor: BrimstoneTokens.goldMuted.withValues(alpha: 0.3),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: BrimstoneTokens.goldPrimary,
        inactiveTrackColor: BrimstoneTokens.goldMuted.withValues(alpha: 0.3),
        thumbColor: BrimstoneTokens.goldPrimary,
        overlayColor: BrimstoneTokens.goldPrimary.withValues(alpha: 0.2),
        valueIndicatorColor: BrimstoneTokens.goldPrimary,
        valueIndicatorTextStyle: BrimstoneTypography.numericMonoSM,
      ),
    );
  }
}

/// Route transition helper: Fade + Scale over abyss background.
Route<T> brimstoneRoute<T>(Widget page) {
  return PageRouteBuilder<T>(
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionDuration: BrimstoneMotion.route,
    reverseTransitionDuration: BrimstoneMotion.route,
    opaque: true,
    barrierColor: BrimstoneTokens.bgAbyss,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.97, end: 1.0).animate(
            CurvedAnimation(parent: animation, curve: BrimstoneMotion.standard),
          ),
          child: child,
        ),
      );
    },
  );
}

/// Marco arcade vertical para pantallas anchas (navegador de PC).
///
/// - `<= 560px` (móvil/portrait): el juego ocupa el 100% del viewport.
/// - `> 560px` (web de escritorio): se centra un gabinete de 440×920 con borde
///   metálico gótico, paneles laterales horizontales elegantes con bordes dorados.
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
            gradient: BrimstoneGradients.abyssBg,
          ),
          child: Row(
            children: [
              if (showPanels) const Expanded(child: _SidePanelLeft()),
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
              if (showPanels) const Expanded(child: _SidePanelRight()),
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
        borderRadius: BorderRadius.circular(BrimstoneRadii.radiusLG),
        border: BrimstoneBorders.bold,
        boxShadow: BrimstoneShadows.level3,
      ),
      child: child,
    );
  }
}

/// Panel lateral izquierdo: título del juego horizontal con borde dorado fino.
class _SidePanelLeft extends StatelessWidget {
  const _SidePanelLeft();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin:
            const EdgeInsets.symmetric(horizontal: BrimstoneSpacing.spaceLG),
        padding: const EdgeInsets.symmetric(
          horizontal: BrimstoneSpacing.spaceLG,
          vertical: BrimstoneSpacing.spaceSM,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(BrimstoneRadii.radiusSM),
          border: BrimstoneBorders.standard,
          gradient: BrimstoneGradients.cardBase,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.local_fire_department,
              color: BrimstoneElements.igneous,
              size: 20,
            ),
            const SizedBox(width: BrimstoneSpacing.spaceSM),
            Flexible(
              child: Text(
                'BRIMSTONE: THE SUMMONING',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: BrimstoneTypography.headingSM.copyWith(
                  color: BrimstoneAccents.voidPurple,
                  letterSpacing: 3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Panel lateral derecho: pistas de control horizontales con bordes dorados.
class _SidePanelRight extends StatelessWidget {
  const _SidePanelRight();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _SideHint(
            icon: Icons.touch_app,
            text: 'CLICK + ARRASTRAR · Fusionar',
          ),
          const SizedBox(height: BrimstoneSpacing.spaceSM),
          _SideHint(
            icon: Icons.swipe_up,
            text: 'DESLIZAR ↑ · Lanzar esfera',
          ),
          const SizedBox(height: BrimstoneSpacing.spaceSM),
          _SideHint(
            icon: Icons.center_focus_strong,
            text: 'CLICK EN DIANA · Bullseye',
          ),
          const SizedBox(height: BrimstoneSpacing.spaceSM),
          _SideHint(
            icon: Icons.gesture,
            text: 'DESLIZAR FUERA · Counter-Flick',
          ),
        ],
      ),
    );
  }
}

class _SideHint extends StatelessWidget {
  const _SideHint({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: BrimstoneSpacing.spaceMD,
        vertical: BrimstoneSpacing.spaceXS,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(BrimstoneRadii.radiusSM),
        border: BrimstoneBorders.standard,
        gradient: BrimstoneGradients.cardBase,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: BrimstoneTokens.goldPrimary),
          const SizedBox(width: BrimstoneSpacing.spaceXS),
          Text(
            text,
            style: BrimstoneTypography.bodyXS.copyWith(
              color: BrimstoneTokens.textSecondary,
            ),
          ),
        ],
      ),
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
      backgroundColor: BrimstoneTokens.bgAbyss,
      body: IndexedStack(index: _tab, children: _screens),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: BrimstoneTokens.surfaceBase,
          border: Border(
            top: BorderSide(
              color: BrimstoneTokens.goldPrimary,
              width: 1.5,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 10,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: NavigationBar(
          backgroundColor: BrimstoneTokens.surfaceBase,
          indicatorColor: BrimstoneTokens.goldPrimary.withValues(alpha: 0.22),
          selectedIndex: _tab,
          onDestinationSelected: (i) => setState(() => _tab = i),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: 'Santuario',
            ),
            NavigationDestination(
              icon: Icon(Icons.shield_outlined),
              selectedIcon: Icon(Icons.shield),
              label: 'Cuartel',
            ),
            NavigationDestination(
              icon: Icon(Icons.auto_fix_high_outlined),
              selectedIcon: Icon(Icons.auto_fix_high),
              label: 'Altar',
            ),
            NavigationDestination(
              icon: Icon(Icons.auto_awesome_outlined),
              selectedIcon: Icon(Icons.auto_awesome),
              label: 'Portal',
            ),
          ],
        ),
      ),
    );
  }
}
