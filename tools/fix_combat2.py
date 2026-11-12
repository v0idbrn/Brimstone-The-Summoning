#!/usr/bin/env python3
# -*- coding: utf-8 -*-

with open('lib/presentation/screens/combat/combat_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Replace _buildOrbsTray method entirely
old_tray = '''  Widget _buildOrbsTray() {
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
              // 5to bot\u00f3n t\u00e1ctico: artefacto del Invocador (junto a la barra de HP).
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

  Widget _buildOrbSlot3D('''

new_tray = '''  Widget _buildOrbsTray() {
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
              // 5to bot\u00f3n t\u00e1ctico: artefacto del Invocador (junto a la barra de HP).
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

if old_tray in content:
    content = content.replace(old_tray, new_tray)
    print('Replaced _buildOrbsTray')
else:
    print('_buildOrbsTray NOT found')

# 2. Replace _buildOrbSlot3D to use custom gradients instead of PlasmaOrb
old_slot = '''  Widget _buildOrbSlot3D(
      int index, double slotWidth, double orbSize, double trayHeight) {
    final orb = engine.tray[index];
    final cx = index * slotWidth + slotWidth / 2;
    final cy = trayHeight / 2;

    if (orb == null) {
      return Positioned(
        left: cx - 14,
        top: cy - 14,
        child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF1A0A0F),
                border: Border.all(color: const Color(0xFF2A151A), width: 1)),
            child: Center(
                child: Icon(Icons.add,
                    size: 16, color: Colors.white.withValues(alpha: 0.2)))),
      );
    }

    final color = _elementColor(orb.element);
    final accent = _elementAccent(orb.element);
    final level = orb.level.index + 1;
    final isDragging = _draggedSlot == index;

    // HellFire: Orbital aura for Lv.2/3 orbs
    final hasOrbitalAura = level >= 2;

    return Positioned(
      left: cx - orbSize / 2,
      top: cy - orbSize / 2,
      child: AnimatedScale(
        scale: isDragging ? 0.0 : 1.0,
        duration: const Duration(milliseconds: 50),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // HellFire: Orbital aura ring for Lv.2/3
            if (hasOrbitalAura)
              AnimatedBuilder(
                animation: _mergePulseCtrl,
                builder: (context, _) {
                  final pulse = _mergePulseCtrl.value;
                  final auraRadius =
                      orbSize / 2 + 6 + 4 * math.sin(pulse * 2 * math.pi);
                  return Container(
                    width: auraRadius * 2,
                    height: auraRadius * 2,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: level == 2
                            ? const Color(0xFFFFD700).withValues(
                                alpha:
                                    0.4 + 0.2 * math.sin(pulse * 2 * math.pi))
                            : const Color(0xFFFF5A26).withValues(
                                alpha:
                                    0.4 + 0.2 * math.sin(pulse * 2 * math.pi)),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: level == 2
                              ? const Color(0xFFFFD700).withValues(alpha: 0.15)
                              : const Color(0xFFFF5A26).withValues(alpha: 0.15),
                          blurRadius: 8 + 4 * math.sin(pulse * 2 * math.pi),
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  );
                },
              ),
            GestureDetector(
              onTap: () {}, // Prevent tap from bubbling
              child: Container(
                width: orbSize,
                height: orbSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                      center: Alignment(-0.35, -0.38),
                      radius: 0.95,
                      colors: [
                        Colors.white.withValues(alpha: 0.95),
                        accent,
                        color,
                        Color.lerp(color, Colors.black, 0.75)!
                      ],
                      stops: const [
                        0.0,
                        0.22,
                        0.62,
                        1.0
                      ]),
                  boxShadow: [
                    BoxShadow(
                        color: color.withValues(alpha: 0.5),
                        blurRadius: 8,
                        spreadRadius: 1),
                    BoxShadow(
                        color: color.withValues(alpha: 0.28),
                        blurRadius: 12,
                        spreadRadius: 2)
                  ],
                  border: Border.all(
                      color: accent.withValues(alpha: 0.85), width: 1.8),
                ),
                child: Stack(alignment: Alignment.center, children: [
                  // GPU plasma core: fluid turbulence + incandescent centre.
                  Positioned.fill(
                    child: ClipOval(
                      child: PlasmaOrb(
                        color: color,
                        glow: accent,
                        intensity: 0.95,
                      ),
                    ),
                  ),
                  // Specular highlight
                  Positioned(
                      left: orbSize * 0.18,
                      top: orbSize * 0.15,
                      child: Container(
                          width: orbSize * 0.28,
                          height: orbSize * 0.28,
                          decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(colors: [
                                Colors.white,
                                Colors.white.withValues(alpha: 0.0)
                              ])))),
                  // Element icon
                  _buildElementIcon(orb.element, orbSize * 0.42),
                  // Level badge
                  Positioned(
                      bottom: -6,
                      child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.78),
                              borderRadius: BorderRadius.circular(3),
                              border: Border.all(
                                  color: level == 1
                                      ? const Color(0xFFC0C0C0)
                                      : level == 2
                                          ? const Color(0xFFFFD700)
                                          : const Color(0xFFFF5A26),
                                  width: 0.9)),
                          child: Text('Nv.$level',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.5)))),
                  // Prismatic indicator
                  if (orb.prismatic)
                    Positioned(
                        top: 2,
                        right: 2,
                        child: Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: const LinearGradient(colors: [
                                  Color(0xFFFFD700),
                                  Color(0xFFB16EFF)
                                ])))),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }'''

new_slot = '''  Widget _buildOrbSlot3D(
      int index, double orbSize, double trayHeight) {
    final orb = engine.tray[index];
    final cy = trayHeight / 2;

    if (orb == null) {
      return Center(
        child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF1A0A0F),
                border: Border.all(color: const Color(0xFF2A151A), width: 1)),
            child: Center(
                child: Icon(Icons.add,
                    size: 16, color: Colors.white.withValues(alpha: 0.2)))),
      );
    }

    final color = _elementColor(orb.element);
    final accent = _elementAccent(orb.element);
    final level = orb.level.index + 1;
    final isDragging = _draggedSlot == index;

    // HellFire: Orbital aura for Lv.2/3 orbs
    final hasOrbitalAura = level >= 2;

    return AnimatedScale(
      scale: isDragging ? 0.0 : 1.0,
      duration: const Duration(milliseconds: 50),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // HellFire: Orbital aura ring for Lv.2/3
          if (hasOrbitalAura)
            AnimatedBuilder(
              animation: _mergePulseCtrl,
              builder: (context, _) {
                final pulse = _mergePulseCtrl.value;
                final auraRadius =
                    orbSize / 2 + 6 + 4 * math.sin(pulse * 2 * math.pi);
                return Container(
                  width: auraRadius * 2,
                  height: auraRadius * 2,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: level == 2
                          ? const Color(0xFFFFD700).withValues(
                              alpha:
                                  0.4 + 0.2 * math.sin(pulse * 2 * math.pi))
                          : const Color(0xFFFF5A26).withValues(
                              alpha:
                                  0.4 + 0.2 * math.sin(pulse * 2 * math.pi)),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: level == 2
                            ? const Color(0xFFFFD700).withValues(alpha: 0.15)
                            : const Color(0xFFFF5A26).withValues(alpha: 0.15),
                        blurRadius: 8 + 4 * math.sin(pulse * 2 * math.pi),
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
              ),
          GestureDetector(
            onTap: () {}, // Prevent tap from bubbling
            child: Container(
              width: orbSize,
              height: orbSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                // Custom radial gradient per element (no PlasmaOrb shader)
                gradient: _orbGradient(orb.element, color, accent),
                boxShadow: [
                  BoxShadow(
                      color: color.withValues(alpha: 0.5),
                      blurRadius: 8,
                      spreadRadius: 1),
                  BoxShadow(
                      color: color.withValues(alpha: 0.28),
                      blurRadius: 12,
                      spreadRadius: 2)
                ],
                border: Border.all(
                    color: accent.withValues(alpha: 0.85), width: 1.8),
              ),
              child: Stack(alignment: Alignment.center, children: [
                // Specular highlight
                Positioned(
                    left: orbSize * 0.18,
                    top: orbSize * 0.15,
                    child: Container(
                        width: orbSize * 0.28,
                        height: orbSize * 0.28,
                        decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(colors: [
                              Colors.white,
                              Colors.white.withValues(alpha: 0.0)
                            ])))),
                // Element icon
                _buildElementIcon(orb.element, orbSize * 0.42),
                // Level badge
                Positioned(
                    bottom: -6,
                    child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.78),
                            borderRadius: BorderRadius.circular(3),
                            border: Border.all(
                                color: level == 1
                                    ? const Color(0xFFC0C0C0)
                                    : level == 2
                                        ? const Color(0xFFFFD700)
                                        : const Color(0xFFFF5A26),
                                width: 0.9)),
                        child: Text('Nv.$level',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 8.5,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5)))),
                // Prismatic indicator
                if (orb.prismatic)
                  Positioned(
                      top: 2,
                      right: 2,
                      child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(colors: [
                                Color(0xFFFFD700),
                                Color(0xFFB16EFF)
                              ])))),
              ]),
            ),
          ],
        ),
      );
  }

  // Custom radial gradient per element (replaces PlasmaOrb shader)
  RadialGradient _orbGradient(Element element, Color color, Color accent) {
    switch (element) {
      case Element.igneous:
        return const RadialGradient(
          center: Alignment(-0.35, -0.38),
          radius: 0.95,
          colors: [
            Color(0xFFFF6D00),
            Color(0xFFB71C1C),
            Color(0xFF3E0000),
          ],
          stops: [0.0, 0.55, 1.0],
        );
      case Element.abyssal:
        return const RadialGradient(
          center: Alignment(-0.35, -0.38),
          radius: 0.95,
          colors: [
            Color(0xFF00E5FF),
            Color(0xFF01579B),
            Color(0xFF001933),
          ],
          stops: [0.0, 0.55, 1.0],
        );
      case Element.telluric:
        return const RadialGradient(
          center: Alignment(-0.35, -0.38),
          radius: 0.95,
          colors: [
            Color(0xFF76FF03),
            Color(0xFF2E7D32),
            Color(0xFF0D260F),
          ],
          stops: [0.0, 0.55, 1.0],
        );
      case Element.empty:
        return const RadialGradient(
          center: Alignment(-0.35, -0.38),
          radius: 0.95,
          colors: [
            Color(0xFFE040FB),
            Color(0xFF4A148C),
            Color(0xFF16002E),
          ],
          stops: [0.0, 0.55, 1.0],
        );
    }
  }'''

if old_slot in content:
    content = content.replace(old_slot, new_slot)
    print('Replaced _buildOrbSlot3D')
else:
    print('_buildOrbSlot3D NOT found')

with open('lib/presentation/screens/combat/combat_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)
print('Done')