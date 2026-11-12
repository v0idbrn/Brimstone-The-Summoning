#!/usr/bin/env python3
# -*- coding: utf-8 -*-

with open('lib/presentation/screens/combat/combat_screen.dart', 'rb') as f:
    content = f.read()

old = b"""  Widget _buildOrbsTray() {
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
                                            ])))),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // 5to bot\xc3\xb3n t\xc3\xa1ctico: artefacto del Invocador (junto a la barra de HP).
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
            ]),
          ),
          // Orbs tray - 5 slots, 3D rendering with Runic Stone Base
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final trayWidth = constraints.maxWidth;
                final slotWidth = trayWidth / 5;
                final trayHeight = constraints.maxHeight;
                final orbSize = (trayHeight * 0.75).clamp(40.0, 56.0);

                return Stack(children: [
                  // HellFire: Runic Stone Base background
                  Container(
                    margin:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                        color: const Color(0xFF0A0407),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: _chapterColor().withValues(alpha: 0.6),
                            width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: _chapterColor().withValues(alpha: 0.15),
                            blurRadius: 8,
                            spreadRadius: 1,
                          ),
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.5),
                            blurRadius: 4,
                            offset: const Offset(0, -2),
                          ),
                        ],
                        // Carved stone texture effect via gradient overlay
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            const Color(0xFF14090D),
                            const Color(0xFF0C0608),
                            const Color(0xFF0A0407),
                          ],
                        )),
                  ),
                  // Metal separators between slots (HellFire style)
                  for (var i = 1; i < 5; i++)
                    Positioned(
                        left: i * slotWidth,
                        top: 8,
                        bottom: 8,
                        child: Container(
                            width: 2,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                  colors: [
                                    _chapterColor().withValues(alpha: 0.8),
                                    _chapterColor().withValues(alpha: 0.3),
                                    _chapterColor().withValues(alpha: 0.8),
                                  ]),
                              borderRadius: BorderRadius.circular(1),
                              boxShadow: [
                                BoxShadow(
                                  color: _chapterColor().withValues(alpha: 0.4),
                                  blurRadius: 2,
                                  spreadRadius: 0.5,
                                ),
                              ],
                            ))),
                  // Orbs in slots (3D with orbital auras for Lv.2/3)
                  for (var i = 0; i < 5; i++)
                    _buildOrbSlot3D(i, slotWidth, orbSize, trayHeight),
                  // Dragged orb preview (follows finger globally)
                  if (_draggedSlot != null && _dragCurrentGlobalPos != null)
                    _buildDraggedOrbPreview3D(slotWidth, orbSize),
                  // Green merge rings on compatible targets
                  if (_hoveredMergeSlot != null)
                    _buildMergeRing(
                        _hoveredMergeSlot!, slotWidth, orbSize, trayHeight),
                  // Auto-merge button
                  Positioned(top: 4, right: 12, child: _buildAutoMergeButton()),
                ]);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrbSlot3D("""

new = b"""  Widget _buildOrbsTray() {
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
              // 5to bot\xc3\xb3n t\xc3\xa1ctico: artefacto del Invocador (junto a la barra de HP).
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
        final orbA = engine.tray[i]!
        final orbB = engine.tray[j]!
        final compatible = (orbA.element == orbB.element ||
                orbA.prismatic ||
                orbB.prismatic) &&
            orbA.level == orbB.level &&
            orbA.level != OrbLevel.three
        if (compatible) return True
      }
    }
    return False
  }

  Widget _buildOrbSlot3D("""

if old in content:
    content = content.replace(old, new)
    with open('lib/presentation/screens/combat/combat_screen.dart', 'wb') as f:
        f.write(content)
    print('Replaced successfully')
else:
    print('Old text NOT found')
    # Debug: find the difference
    for i, (o, n) in enumerate(zip(old.split(b'\n'), new.split(b'\n'))):
        if o != n:
            print(f'Line {i} diff:')
            print(f'  old: {o[:120]}')
            print(f'  new: {n[:120]}')
            break