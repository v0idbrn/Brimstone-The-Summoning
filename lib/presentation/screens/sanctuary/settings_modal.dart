import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/audio/procedural_sfx_engine.dart';
import '../../controllers/meta_controller.dart';

/// Modal de Ajustes: volúmenes de efectos y ambiente, hápticas y silencio.
///
/// Accesible desde el Santuario y desde la pantalla de combate. Los valores se
/// persisten en SQLite (tabla `player_stats`) para sobrevivir reinicios.
class SettingsModal extends ConsumerStatefulWidget {
  const SettingsModal({super.key});

  /// Claves de persistencia en `player_stats`.
  static const String sfxVolumeKey = 'sfxVolume';
  static const String ambientVolumeKey = 'ambientVolume';
  static const String hapticsKey = 'hapticsEnabled';
  static const String mutedKey = 'audioMuted';

  @override
  ConsumerState<SettingsModal> createState() => _SettingsModalState();
}

class _SettingsModalState extends ConsumerState<SettingsModal> {
  double _sfxVolume = 0.8;
  double _ambientVolume = 0.4;
  bool _hapticsEnabled = true;
  bool _muted = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final repo = ref.read(playerRepositoryProvider);
    final raw = await repo.loadRawStats();
    final sfx = raw[SettingsModal.sfxVolumeKey];
    final ambient = raw[SettingsModal.ambientVolumeKey];
    final haptics = raw[SettingsModal.hapticsKey];
    final muted = raw[SettingsModal.mutedKey];
    if (!mounted) return;
    setState(() {
      _sfxVolume = (sfx ?? 80) / 100.0;
      _ambientVolume = (ambient ?? 40) / 100.0;
      _hapticsEnabled = haptics == null ? true : haptics == 1;
      _muted = muted == 1;
      _loading = false;
    });
    ProceduralSfxEngine.restoreSettings(
      sfxVolume: sfx ?? 80,
      ambientVolume: ambient ?? 40,
      hapticsEnabled: _hapticsEnabled,
    );
    ProceduralSfxEngine.setMuted(_muted);
  }

  Future<void> _persist() async {
    final repo = ref.read(playerRepositoryProvider);
    await repo.writeStat(
      SettingsModal.sfxVolumeKey,
      (_sfxVolume * 100).round(),
    );
    await repo.writeStat(
      SettingsModal.ambientVolumeKey,
      (_ambientVolume * 100).round(),
    );
    await repo.writeStat(
      SettingsModal.hapticsKey,
      _hapticsEnabled ? 1 : 0,
    );
    await repo.writeStat(SettingsModal.mutedKey, _muted ? 1 : 0);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF14090D),
      title: const Text(
        'AJUSTES',
        style: TextStyle(
          color: Color(0xFFB16EFF),
          fontWeight: FontWeight.w900,
          letterSpacing: 1.2,
        ),
      ),
      content: _loading
          ? const SizedBox(
              height: 120,
              child: Center(
                child: CircularProgressIndicator(color: Color(0xFFB16EFF)),
              ),
            )
          : SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Silenciar todo',
                      style: TextStyle(color: Colors.white, fontSize: 13),
                    ),
                    value: _muted,
                    activeTrackColor: const Color(0xFFB16EFF),
                    onChanged: (value) {
                      setState(() => _muted = value);
                      ProceduralSfxEngine.setMuted(value);
                      _persist();
                    },
                    secondary: const Icon(
                      Icons.volume_off,
                      color: Colors.white54,
                    ),
                  ),
                  _VolumeSlider(
                    label: 'Volumen de efectos',
                    icon: Icons.volume_up,
                    value: _sfxVolume,
                    onChanged: (value) {
                      setState(() => _sfxVolume = value);
                      ProceduralSfxEngine.setSfxVolume(value);
                    },
                    onChangeEnd: (_) => _persist(),
                  ),
                  _VolumeSlider(
                    label: 'Volumen de ambiente',
                    icon: Icons.hearing,
                    value: _ambientVolume,
                    onChanged: (value) {
                      setState(() => _ambientVolume = value);
                      ProceduralSfxEngine.setAmbientVolume(value);
                    },
                    onChangeEnd: (_) => _persist(),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Respuesta háptica',
                      style: TextStyle(color: Colors.white, fontSize: 13),
                    ),
                    value: _hapticsEnabled,
                    activeTrackColor: const Color(0xFFB16EFF),
                    onChanged: (value) {
                      setState(() => _hapticsEnabled = value);
                      ProceduralSfxEngine.setHapticsEnabled(value);
                      _persist();
                    },
                    secondary: const Icon(
                      Icons.vibration,
                      color: Colors.white54,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'El ambiente del Santuario y el pulso del jefe son loops '
                    'WAV sintetizados en memoria: no requieren assets.',
                    style: TextStyle(color: Colors.white38, fontSize: 10),
                  ),
                ],
              ),
            ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(
            'CERRAR',
            style: TextStyle(
              color: Color(0xFFB16EFF),
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class _VolumeSlider extends StatelessWidget {
  final String label;
  final IconData icon;
  final double value;
  final ValueChanged<double> onChanged;
  final ValueChanged<double>? onChangeEnd;

  const _VolumeSlider({
    required this.label,
    required this.icon,
    required this.value,
    required this.onChanged,
    this.onChangeEnd,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: Colors.white54),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ),
            Text(
              '${(value * 100).round()}%',
              style: const TextStyle(
                color: Color(0xFFFFC93C),
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        Slider(
          value: value,
          onChanged: onChanged,
          onChangeEnd: onChangeEnd,
          activeColor: const Color(0xFFB16EFF),
          inactiveColor: Colors.white12,
        ),
      ],
    );
  }
}
