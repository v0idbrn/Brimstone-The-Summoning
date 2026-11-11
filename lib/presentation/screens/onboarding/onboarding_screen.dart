import 'package:flutter/material.dart' hide Element;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/audio/procedural_sfx_engine.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../presentation/graphics/painted_backdrop.dart';
import '../../../presentation/widgets/brimstone_button.dart';

/// Pantalla de onboarding interactivo "El Despertar del Invocador" (Pilar 3).
///
/// 3 pasos con foco luminoso (Spotlight Coachmark):
/// 1. "Fusioná dos esferas iguales o pulsá [Espacio]"
/// 2. "Deslizá hacia arriba o hacé clic en el Bullseye dorado del enemigo"
/// 3. "¡Maná lleno! Tocá tu carta (o pulsá [1]) para desatar su poder"
///
/// Otorga +300 Esquirlas al completarse. Se puede saltar en 1 clic.
/// Desactivado automáticamente en tests salvo test dedicado.
class OnboardingScreen extends ConsumerStatefulWidget {
  final VoidCallback onComplete;

  const OnboardingScreen({super.key, required this.onComplete});

  static const String prefsKey = 'tutorial_completed_v1';
  static bool _completed = false;

  static Future<bool> isCompleted() async => _completed;

  static Future<void> markCompleted() async => _completed = true;

  static Future<void> reset() async => _completed = false;

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen>
    with TickerProviderStateMixin {
  int _step = 0;
  late final AnimationController _pulseCtrl;
  late final AnimationController _spotlightCtrl;

  static const _steps = [
    _OnboardingStep(
      titleKey: 'onboarding.step1.title',
      descKey: 'onboarding.step1.desc',
      highlightZone: _HighlightZone.orbsTray,
      keyHint: '[ESPACIO] / Arrastrar',
    ),
    _OnboardingStep(
      titleKey: 'onboarding.step2.title',
      descKey: 'onboarding.step2.desc',
      highlightZone: _HighlightZone.bullseye,
      keyHint: '[CLICK / Deslizar ↑]',
    ),
    _OnboardingStep(
      titleKey: 'onboarding.step3.title',
      descKey: 'onboarding.step3.desc',
      highlightZone: _HighlightZone.squadCards,
      keyHint: '[1-4] / Click carta',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _spotlightCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _spotlightCtrl.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_step < _steps.length - 1) {
      _spotlightCtrl.reset();
      _spotlightCtrl.forward();
      setState(() => _step++);
      ProceduralSfxEngine.playOrbSpawn();
    } else {
      _complete();
    }
  }

  void _skip() {
    _complete();
  }

  Future<void> _complete() async {
    await OnboardingScreen.markCompleted();
    ProceduralSfxEngine.playLevelUp();
    if (mounted) widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    final step = _steps[_step];
    final isDesktop = MediaQuery.of(context).size.width > 560;

    return Scaffold(
      backgroundColor: const Color(0xFF0C0608),
      body: PaintedBackdrop(
        asset: 'sanctuary',
        tint: BrimstoneAccents.voidPurple,
        darkness: 0.35,
        child: Stack(
          children: [
            // Background combat preview (dimmed)
            Positioned.fill(
              child: IgnorePointer(
                child: _CombatPreview(
                  step: _step,
                  pulseAnim: _pulseCtrl,
                ),
              ),
            ),
            // Dark overlay with spotlight hole
            Positioned.fill(
              child: CustomPaint(
                painter: _SpotlightPainter(
                  progress: _spotlightCtrl.value,
                  zone: step.highlightZone,
                  isDesktop: isDesktop,
                ),
              ),
            ),
            // Step content
            SafeArea(
              child: Column(
                children: [
                  // Skip button
                  Align(
                    alignment: Alignment.topRight,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: TextButton(
                        onPressed: _skip,
                        child: Text(
                          AppStrings.t('onboarding.skip'),
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Progress dots
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        _steps.length,
                        (i) => AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: i == _step ? 24 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: i <= _step
                                ? const Color(0xFFB16EFF)
                                : Colors.white24,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const Spacer(),
                  // Step title & description
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      children: [
                        Text(
                          AppStrings.t(step.titleKey),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Color(0xFFB16EFF),
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          AppStrings.t(step.descKey),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 15,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Key hint badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color:
                                const Color(0xFFB16EFF).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: const Color(0xFFB16EFF)
                                  .withValues(alpha: 0.5),
                            ),
                          ),
                          child: Text(
                            step.keyHint,
                            style: const TextStyle(
                              color: Color(0xFFB16EFF),
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                  // Continue button
                  BrimstoneButton(
                    width: isDesktop ? 280 : double.infinity,
                    height: 56,
                    icon: _step == _steps.length - 1
                        ? Icons.check
                        : Icons.arrow_forward,
                    label: _step == _steps.length - 1
                        ? AppStrings.t('onboarding.complete')
                        : AppStrings.t('onboarding.next'),
                    onPressed: _nextStep,
                  ),
                  const SizedBox(height: 40),
                  // Welcome chest preview (on last step)
                  if (_step == _steps.length - 1) _WelcomeChestPreview(),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _HighlightZone { orbsTray, bullseye, squadCards }

class _OnboardingStep {
  final String titleKey;
  final String descKey;
  final _HighlightZone highlightZone;
  final String keyHint;

  const _OnboardingStep({
    required this.titleKey,
    required this.descKey,
    required this.highlightZone,
    required this.keyHint,
  });
}

class _SpotlightPainter extends CustomPainter {
  final double progress;
  final _HighlightZone zone;
  final bool isDesktop;

  _SpotlightPainter({
    required this.progress,
    required this.zone,
    required this.isDesktop,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withValues(alpha: 0.85 * progress);
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);

    // Calculate spotlight center based on zone
    Offset center;
    double radius;

    switch (zone) {
      case _HighlightZone.orbsTray:
        // Bottom area - orbs tray
        center = Offset(size.width / 2, size.height - 100);
        radius = isDesktop ? 180 : 140;
        break;
      case _HighlightZone.bullseye:
        // Upper area - bullseye target
        center = Offset(size.width / 2, size.height * 0.35);
        radius = isDesktop ? 160 : 130;
        break;
      case _HighlightZone.squadCards:
        // Lower-middle - squad cards
        center = Offset(size.width / 2, size.height - 240);
        radius = isDesktop ? 200 : 160;
        break;
    }

    // Animate radius
    radius = radius * (0.5 + 0.5 * progress);

    // Draw dark overlay with hole
    final path = Path()
      ..addRect(rect)
      ..addOval(Rect.fromCircle(center: center, radius: radius));
    canvas.drawPath(path, paint);

    // Pulsing ring at spotlight edge
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = const Color(0xFFB16EFF).withValues(alpha: 0.8 * progress);
    canvas.drawCircle(center, radius + 10 * progress, ringPaint);
  }

  @override
  bool shouldRepaint(covariant _SpotlightPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.zone != zone ||
      oldDelegate.isDesktop != isDesktop;
}

class _CombatPreview extends StatelessWidget {
  final int step;
  final Animation<double> pulseAnim;

  const _CombatPreview({
    required this.step,
    required this.pulseAnim,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulseAnim,
      builder: (context, _) => Opacity(
        opacity: 0.3,
        child: Stack(
          children: [
            // Arena background
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      const Color(0xFF1A0A0F),
                      const Color(0xFF0C0608),
                    ],
                  ),
                ),
              ),
            ),
            // Boss silhouette
            Positioned(
              top: MediaQuery.of(context).size.height * 0.15,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(colors: [
                      const Color(0xFFFF5A26).withValues(alpha: 0.3),
                      const Color(0xFF8B0000).withValues(alpha: 0.1),
                    ]),
                    border: Border.all(
                      color: const Color(0xFFFF5A26).withValues(alpha: 0.5),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFF5A26).withValues(alpha: 0.2),
                        blurRadius: 30,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Icon(
                      Icons.local_fire_department,
                      size: 80,
                      color: const Color(0xFFFF5A26).withValues(alpha: 0.5),
                    ),
                  ),
                ),
              ),
            ),
            // Orbs tray (step 0 highlight)
            if (step == 0)
              Positioned(
                bottom: 80,
                left: 0,
                right: 0,
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children:
                        List.generate(5, (i) => _AnimatedOrb(i, pulseAnim)),
                  ),
                ),
              ),
            // Bullseye indicator (step 1)
            if (step == 1)
              Positioned(
                top: MediaQuery.of(context).size.height * 0.35,
                left: 0,
                right: 0,
                child: Center(
                  child: _BullseyeIndicator(pulseAnim),
                ),
              ),
            // Squad cards (step 2)
            if (step == 2)
              Positioned(
                bottom: 200,
                left: 0,
                right: 0,
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(
                      4,
                      (i) => Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: _AnimatedCard(i, pulseAnim),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _AnimatedOrb extends StatelessWidget {
  final int index;
  final Animation<double> anim;

  const _AnimatedOrb(this.index, this.anim);

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: anim,
      builder: (context, _) => Transform.scale(
        scale: 1.0 + 0.1 * (anim.value + index * 0.2) % 1.0,
        child: Container(
          width: 50,
          height: 50,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(colors: [
              Colors.white.withValues(alpha: 0.9),
              const Color(0xFFFF5A26),
              const Color(0xFF8B0000),
            ]),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFF5A26).withValues(alpha: 0.5),
                blurRadius: 10,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Center(
            child: Text(
              '${(index % 3) + 1}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BullseyeIndicator extends StatelessWidget {
  final Animation<double> anim;

  const _BullseyeIndicator(this.anim);

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: anim,
      builder: (context, _) => Transform.scale(
        scale: 0.8 + 0.2 * anim.value,
        child: Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: const Color(0xFFFFD700).withValues(alpha: 0.8),
              width: 3,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFFD700).withValues(alpha: 0.4),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Center(
            child: Icon(
              Icons.center_focus_strong,
              size: 50,
              color: const Color(0xFFFFD700).withValues(alpha: 0.8),
            ),
          ),
        ),
      ),
    );
  }
}

class _AnimatedCard extends StatelessWidget {
  final int index;
  final Animation<double> anim;

  const _AnimatedCard(this.index, this.anim);

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: anim,
      builder: (context, _) => Transform.translate(
        offset: Offset(0, 10 * (anim.value + index * 0.25) % 1.0 - 5),
        child: Container(
          width: 80,
          height: 110,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(colors: [
              const Color(0xFF1A0A0F),
              const Color(0xFF0C0608),
            ]),
            border: Border.all(
              color: const Color(0xFFB16EFF).withValues(alpha: 0.5),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFB16EFF).withValues(alpha: 0.2),
                blurRadius: 15,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                [
                  Icons.local_fire_department,
                  Icons.ac_unit,
                  Icons.landscape,
                  Icons.dark_mode
                ][index % 4],
                size: 32,
                color: const Color(0xFFB16EFF),
              ),
              const SizedBox(height: 4),
              Text(
                '${index + 1}',
                style: const TextStyle(
                  color: Color(0xFFB16EFF),
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WelcomeChestPreview extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFFFFD700),
                const Color(0xFFFF5A26),
                const Color(0xFF8B0000),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFFD700).withValues(alpha: 0.4),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: const Center(
            child: Icon(
              Icons.card_giftcard,
              size: 40,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          '+300 Esquirlas de Bienvenida',
          style: const TextStyle(
            color: Color(0xFFFFC93C),
            fontSize: 14,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}
