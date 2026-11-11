import 'package:flutter/foundation.dart';

/// Localización reactiva Español / Inglés (Etapa III, Pilar 9).
///
/// El toggle ES/EN vive en TitleSplashScreen y SettingsModal, se persiste en
/// SQLite v10 (`app_settings`) y se aplica **instantáneamente** en pestañas,
/// encabezados, modos de juego, combate y botones principales.
enum AppLanguage { es, en }

extension AppLanguageMeta on AppLanguage {
  String get code => this == AppLanguage.es ? 'es' : 'en';
  String get label => this == AppLanguage.es ? 'Español' : 'English';

  static AppLanguage fromCode(String? code) =>
      code == 'en' ? AppLanguage.en : AppLanguage.es;
}

/// Notificador global del idioma: cualquier pantalla puede escucharlo para
/// reconstruirse al instante cuando el usuario conmuta ES/EN.
final ValueNotifier<AppLanguage> appLanguageNotifier =
    ValueNotifier<AppLanguage>(AppLanguage.es);

/// Idioma activo (atajo de lectura).
AppLanguage get currentLanguage => appLanguageNotifier.value;

/// Cambia el idioma en caliente y notifica a todos los listeners.
void setAppLanguage(AppLanguage lang) {
  if (appLanguageNotifier.value != lang) {
    appLanguageNotifier.value = lang;
  }
}

/// Claves de la UI cubiertas por el diccionario bilingüe.
class AppStrings {
  const AppStrings._();

  static const Map<String, String> _es = {
    'sanctuary.title': 'Santuario',
    'sanctuary.tab.story': 'Historia',
    'sanctuary.tab.tower': 'Torre',
    'sanctuary.tab.arena': 'Arena',
    'sanctuary.tab.order': 'Orden',
    'sanctuary.tab.story.sub': 'Actos I–II',
    'sanctuary.tab.tower.sub': 'Torre & Cámaras',
    'sanctuary.tab.arena.sub': 'Coliseo & Raids',
    'sanctuary.tab.order.sub': 'Orden & Expediciones',
    'play.rift': 'Descender a la Grieta',
    'play.endless': 'Abismo sin Fin',
    'play.story': 'Modo Historia',
    'play.nightmare': 'Pesadilla',
    'play.normal': 'Normal',
    'combat.victory': '¡VICTORIA!',
    'combat.defeat': 'DERROTA',
    'combat.summary': 'Resumen de Batalla',
    'combat.mvp': '★ MVP',
    'combat.damageContribution': 'Aporte de daño',
    'combat.counterFlick': 'Contraesquirla',
    'combat.artifact': 'Artefacto',
    'combat.artifactReady': 'Artefacto listo',
    'combat.artifactCooldown': 'Recarga',
    'hud.boss': 'JEFE',
    'hud.hp': 'HP',
    'hud.mana': 'Maná',
    'hud.overdrive': 'Overdrive',
    'tower.title': 'Torre de Obsidiana',
    'tower.subtitle': '50 Sellos de Ascenso',
    'tower.floor': 'Piso',
    'tower.bestFloor': 'Mejor piso',
    'tower.sweep': 'Barrido Rápido Diario',
    'tower.sweepClaimed': 'Barrido ya cobrado hoy',
    'tower.climb': 'Escalar la Torre',
    'tower.guardian': 'Guardián',
    'expeditions.title': 'Expediciones Abisales',
    'expeditions.send': 'Enviar',
    'expeditions.claim': 'Reclamar',
    'expeditions.away': 'En ruta',
    'expeditions.ready': '¡De vuelta!',
    'expeditions.bench': 'Suplentes disponibles',
    'guild.title': 'Orden del Pacto',
    'guild.swear': 'Juramento',
    'guild.contribute': 'Contribuir',
    'guild.shop': 'Tienda de Insignias',
    'guild.level': 'Nivel de la Orden',
    'guild.badges': 'Insignias',
    'settings.title': 'Ajustes',
    'settings.language': 'Idioma',
    'settings.audio': 'Audio',
    'settings.backup': 'Backup',
    'profile.title': 'Perfil de Invocador',
    'profile.battleLog': 'Historial de Batallas',
    'battle.log': 'Historial de Batallas',
    'battle.last15': 'Últimas 15 batallas',
    'common.close': 'Cerrar',
    'common.cancel': 'Cancelar',
    'common.confirm': 'Confirmar',
    'common.gold': 'Oro',
    'common.shards': 'Esquirlas',
    'common.energy': 'Energía',
    'common.level': 'Nivel',
    'common.barracks': 'Cuartel',
    'common.altar': 'Altar',
    'common.summon': 'Invocar',
    'common.chapters': 'Capítulos',
    'common.rewards': 'Recompensas',
    'common.defeat': 'Derrota',
  };

  static const Map<String, String> _en = {
    'sanctuary.title': 'Sanctuary',
    'sanctuary.tab.story': 'Story',
    'sanctuary.tab.tower': 'Tower',
    'sanctuary.tab.arena': 'Arena',
    'sanctuary.tab.order': 'Order',
    'sanctuary.tab.story.sub': 'Acts I–II',
    'sanctuary.tab.tower.sub': 'Tower & Chambers',
    'sanctuary.tab.arena.sub': 'Colosseum & Raids',
    'sanctuary.tab.order.sub': 'Order & Expeditions',
    'play.rift': 'Descend into the Rift',
    'play.endless': 'Endless Abyss',
    'play.story': 'Story Mode',
    'play.nightmare': 'Nightmare',
    'play.normal': 'Normal',
    'combat.victory': 'VICTORY!',
    'combat.defeat': 'DEFEAT',
    'combat.summary': 'Battle Summary',
    'combat.mvp': '★ MVP',
    'combat.damageContribution': 'Damage contribution',
    'combat.counterFlick': 'Counter-Flick',
    'combat.artifact': 'Artifact',
    'combat.artifactReady': 'Artifact ready',
    'combat.artifactCooldown': 'Cooldown',
    'hud.boss': 'BOSS',
    'hud.hp': 'HP',
    'hud.mana': 'Mana',
    'hud.overdrive': 'Overdrive',
    'tower.title': 'Obsidian Tower',
    'tower.subtitle': '50 Seals of Ascension',
    'tower.floor': 'Floor',
    'tower.bestFloor': 'Best floor',
    'tower.sweep': 'Daily Quick Sweep',
    'tower.sweepClaimed': 'Sweep already claimed today',
    'tower.climb': 'Climb the Tower',
    'tower.guardian': 'Guardian',
    'expeditions.title': 'Abyssal Expeditions',
    'expeditions.send': 'Send',
    'expeditions.claim': 'Claim',
    'expeditions.away': 'On route',
    'expeditions.ready': 'Returned!',
    'expeditions.bench': 'Available reserves',
    'guild.title': 'Order of the Covenant',
    'guild.swear': 'Oath',
    'guild.contribute': 'Contribute',
    'guild.shop': 'Badge Shop',
    'guild.level': 'Order Level',
    'guild.badges': 'Badges',
    'settings.title': 'Settings',
    'settings.language': 'Language',
    'settings.audio': 'Audio',
    'settings.backup': 'Backup',
    'profile.title': 'Summoner Profile',
    'profile.battleLog': 'Battle History',
    'battle.log': 'Battle History',
    'battle.last15': 'Last 15 battles',
    'common.close': 'Close',
    'common.cancel': 'Cancel',
    'common.confirm': 'Confirm',
    'common.gold': 'Gold',
    'common.shards': 'Shards',
    'common.energy': 'Energy',
    'common.level': 'Level',
    'common.barracks': 'Barracks',
    'common.altar': 'Altar',
    'common.summon': 'Summon',
    'common.chapters': 'Chapters',
    'common.rewards': 'Rewards',
    'common.defeat': 'Defeat',
  };

  /// Traduce [key] al idioma activo; si no existe devuelve la clave ES.
  static String t(String key, [AppLanguage? lang]) {
    final l = lang ?? currentLanguage;
    final dict = l == AppLanguage.en ? _en : _es;
    return dict[key] ?? _es[key] ?? key;
  }

  /// Cantidad de claves cubiertas (paridad ES/EN garantizada).
  static int get keyCount => _es.length;

  /// Las tablas ES y EN cubren exactamente las mismas claves.
  static bool get hasParity =>
      _es.length == _en.length && _es.keys.every(_en.containsKey);
}
