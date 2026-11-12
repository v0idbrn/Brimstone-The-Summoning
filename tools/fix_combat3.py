#!/usr/bin/env python3
# -*- coding: utf-8 -*-

with open('lib/presentation/screens/combat/combat_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Find the exact _buildOrbsTray method
start = content.find('  Widget _buildOrbsTray() {')
if start >= 0:
    end = content.find('  Widget _buildOrbSlot3D(', start)
    if end >= 0:
        old_method = content[start:end]
        print('Found method, length:', len(old_method))
        # Print first 200 chars
        print(repr(old_method[:200]))
        
        new_method = '''  Widget _buildOrbsTray() {
    return Container(
      // HellFire: Runic Stone Base for orb tray - carved stone with metal separators
      decoration: BoxDecoration(
        gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [const Color(0xFF1A0A0F), const Color(0xFF0C0608)]),
        border: Border(
          top: BorderSide(
              color: _chapterColor().withValues(alpha: 0.5), width: 2),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Player HP bar
          Padding(
            padding: const EdgeInsets.fromLTRB(
              BrimstoneSpacing.spaceMD,
              BrimstoneSpacing.spaceSM,
              BrimstoneSpacing.spaceMD,
              BrimstoneSpacing.spaceXS,
            ),
            child: Row(children: [
              Icon(
                Icons.favorite,
                color: BrimstoneAccents.crimsonGlow,
                size: 18,
              ),
              const SizedBox(width: BrimstoneSpacing.spaceXS),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(children: [
                      Text(
                        'HP ',
                        style: BrimstoneTypography.bodyXS.copyWith(
                          color: BrimstoneTokens.textSecondary,
                        ),
                      ),
                      Flexible(
                        child: Text(
                          '${engine.playerHp.toInt()} / ${engine.playerMaxHp.toInt()}',
                          style: BrimstoneTypography.numericMonoSM,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ]),
                    const SizedBox(height: 2),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: Container(
                        height: 5,
                        color: BrimstoneTokens.surfaceInteractive,
                        child: FractionallySizedBox(
                          widthFactor: engine.hpFraction.clamp(0.0, 1.0),
                          alignment: Alignment.centerLeft,
                          child: Container(
                              decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                      colors: engine.isLowHp
                                          ? [
                                              BrimstoneTokens.success,
                                              BrimstoneAccents.info,
                                            ]
                                          : [
                                              BrimstoneTokens.success,
                                              BrimstoneAccents.info,
                                            ]))),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // 5to botón táctico: artefacto del Invocador (junto a la barra de HP).
              if (_equippedArtifact != null) ...[
                const SizedBox(width: BrimstoneSpacing.spaceSM),
                AnimatedBuilder(
                  animation: _fxClock,
                  builder: (context, _) => CombatArtifactButton(
                    artifact: _equippedArtifact,
                    cooldownRemaining:
                        _engine?.artifactCooldownRemaining ?? 0.0,
                    onTap: _useEquippedArtifact,
                  ),
                ),
              ],
              // Auto-merge button compact next to HP
              if (_canAutoMerge()) ...[
                const SizedBox(width: BrimstoneSpacing.spaceXS),
                _buildAutoMergeButton(),
              ],
            ]),
          ),
          // Orbs tray - 5 slots in a Row with Expanded
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final trayHeight = constraints.maxHeight;
                  final orbSize = (trayHeight * 0.75).clamp(40.0, 56.0);

                  return Row(
                    children: List.generate(5, (i) {
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                          child: _buildOrbSlot3D(i, orbSize, trayHeight),
                        ),
                      );
                    }),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool _canAutoMerge() {
    for (var i = 0; i < engine.tray.length; i++) {
      if (engine.tray[i] == null) continue;
      for (var j = i + 1; j < engine.tray.length; j++) {
        if (engine.tray[j] == null) continue;
        final orbA = engine.tray[i]!;
        final orbB = engine.tray[j]!;
        final compatible = (orbA.element == orbB.element ||
                orbA.prismatic ||
                orbB.prismatic) &&
            orbA.level == orbB.level &&
            orbA.level != OrbLevel.three;
        if (compatible) return true;
      }
    }
    return false;
  }

  Widget _buildOrbSlot3D('''

        content = content[:start] + new_method + content[end:]
        with open('lib/presentation/screens/combat/combat_screen.dart', 'w', encoding='utf-8') as f:
            f.write(content)
        print('Replaced _buildOrbsTray successfully')
    else:
        print('Could not find end of method')
else:
    print('Could not find start of method')