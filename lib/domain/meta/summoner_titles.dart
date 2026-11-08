/// Historial global del Invocador y sus 12 Títulos desbloqueables.
///
/// Dominio puro: los títulos sólo dependen de [SummonerStats], que se arma a
/// partir de los contadores persistidos y de las tablas de progreso.
library;

/// Métricas históricas del jugador.
class SummonerStats {
  /// Combates ganados (campaña + grieta + desafíos).
  final int combatsWon;

  /// Jefes abatidos (cualquier modo).
  final int bossesSlain;

  /// Golpe máximo registrado en un solo impacto.
  final int maxHit;

  /// Mejor racha de Bullseyes consecutivos.
  final int bestBullseyeStreak;

  /// Reacciones elementales detonadas.
  final int reactions;

  /// Capítulos de campaña completados (0..5).
  final int chaptersCleared;

  /// Desafíos del Sello superados (0..10).
  final int challengesCleared;

  /// Cartas en la colección (0..20 del catálogo, puede haber duplicados).
  final int cardsOwned;

  /// Récord del Abismo Sin Fin.
  final int endlessRecord;

  /// Counter-Flicks conectados.
  final int counterflicks;

  const SummonerStats({
    this.combatsWon = 0,
    this.bossesSlain = 0,
    this.maxHit = 0,
    this.bestBullseyeStreak = 0,
    this.reactions = 0,
    this.chaptersCleared = 0,
    this.challengesCleared = 0,
    this.cardsOwned = 0,
    this.endlessRecord = 0,
    this.counterflicks = 0,
  });

  static const SummonerStats empty = SummonerStats();

  SummonerStats copyWith({
    int? combatsWon,
    int? bossesSlain,
    int? maxHit,
    int? bestBullseyeStreak,
    int? reactions,
    int? chaptersCleared,
    int? challengesCleared,
    int? cardsOwned,
    int? endlessRecord,
    int? counterflicks,
  }) =>
      SummonerStats(
        combatsWon: combatsWon ?? this.combatsWon,
        bossesSlain: bossesSlain ?? this.bossesSlain,
        maxHit: maxHit ?? this.maxHit,
        bestBullseyeStreak: bestBullseyeStreak ?? this.bestBullseyeStreak,
        reactions: reactions ?? this.reactions,
        chaptersCleared: chaptersCleared ?? this.chaptersCleared,
        challengesCleared: challengesCleared ?? this.challengesCleared,
        cardsOwned: cardsOwned ?? this.cardsOwned,
        endlessRecord: endlessRecord ?? this.endlessRecord,
        counterflicks: counterflicks ?? this.counterflicks,
      );

  Map<String, int> toMap() => {
        'combatsWon': combatsWon,
        'bossesSlain': bossesSlain,
        'maxHit': maxHit,
        'bestBullseyeStreak': bestBullseyeStreak,
        'reactions': reactions,
        'chaptersCleared': chaptersCleared,
        'challengesCleared': challengesCleared,
        'cardsOwned': cardsOwned,
        'endlessRecord': endlessRecord,
        'counterflicks': counterflicks,
      };

  factory SummonerStats.fromMap(Map<String, dynamic> map) {
    int read(String key) {
      final value = map[key];
      if (value is int) return value;
      if (value is num) return value.toInt();
      return 0;
    }

    return SummonerStats(
      combatsWon: read('combatsWon'),
      bossesSlain: read('bossesSlain'),
      maxHit: read('maxHit'),
      bestBullseyeStreak: read('bestBullseyeStreak'),
      reactions: read('reactions'),
      chaptersCleared: read('chaptersCleared'),
      challengesCleared: read('challengesCleared'),
      cardsOwned: read('cardsOwned'),
      endlessRecord: read('endlessRecord'),
      counterflicks: read('counterflicks'),
    );
  }
}

/// Un título equipable bajo el nombre del Invocador.
class SummonerTitle {
  final String id;
  final String name;
  final String requirement;

  const SummonerTitle({
    required this.id,
    required this.name,
    required this.requirement,
  });

  /// Evalúa la condición de desbloqueo contra [stats].
  bool isUnlocked(SummonerStats stats) {
    switch (id) {
      case 'novato':
        return stats.combatsWon >= 1;
      case 'sellador':
        return stats.chaptersCleared >= 2;
      case 'gorgath_slayer':
        return stats.chaptersCleared >= 3;
      case 'nyxara_slayer':
        return stats.chaptersCleared >= 4;
      case 'azathor_slayer':
        return stats.chaptersCleared >= 5;
      case 'deadly_eye':
        return stats.bestBullseyeStreak >= 10;
      case 'executioner':
        return stats.maxHit >= 500;
      case 'alchemist':
        return stats.reactions >= 50;
      case 'card_king':
        return stats.cardsOwned >= 20;
      case 'seal_breaker':
        return stats.challengesCleared >= 5;
      case 'abyss_wanderer':
        return stats.endlessRecord >= 10;
      case 'summoner_god':
        return stats.chaptersCleared >= 5 &&
            stats.challengesCleared >= 10 &&
            stats.cardsOwned >= 20 &&
            stats.endlessRecord >= 20;
      default:
        return false;
    }
  }

  /// Progreso textual hacia el desbloqueo (para la UI del perfil).
  String progressLabel(SummonerStats stats) {
    int progressOf(int current, int target) =>
        current > target ? target : current;
    switch (id) {
      case 'novato':
        return '${progressOf(stats.combatsWon, 1)}/1 combates';
      case 'sellador':
        return '${progressOf(stats.chaptersCleared, 2)}/2 capítulos';
      case 'gorgath_slayer':
        return '${progressOf(stats.chaptersCleared, 3)}/3 capítulos';
      case 'nyxara_slayer':
        return '${progressOf(stats.chaptersCleared, 4)}/4 capítulos';
      case 'azathor_slayer':
        return '${progressOf(stats.chaptersCleared, 5)}/5 capítulos';
      case 'deadly_eye':
        return '${progressOf(stats.bestBullseyeStreak, 10)}/10 racha';
      case 'executioner':
        return '${progressOf(stats.maxHit, 500)}/500 daño';
      case 'alchemist':
        return '${progressOf(stats.reactions, 50)}/50 reacciones';
      case 'card_king':
        return '${progressOf(stats.cardsOwned, 20)}/20 cartas';
      case 'seal_breaker':
        return '${progressOf(stats.challengesCleared, 5)}/5 desafíos';
      case 'abyss_wanderer':
        return '${progressOf(stats.endlessRecord, 10)}/10 oleadas';
      case 'summoner_god':
        return '5 capítulos · 10 desafíos · 20 cartas · 20 oleadas';
      default:
        return '';
    }
  }
}

class SummonerTitles {
  static const List<SummonerTitle> titles = [
    SummonerTitle(
      id: 'novato',
      name: 'Novato del Abismo',
      requirement: 'Gana tu primer combate',
    ),
    SummonerTitle(
      id: 'sellador',
      name: 'Sellador Menor',
      requirement: 'Completa 2 capítulos',
    ),
    SummonerTitle(
      id: 'gorgath_slayer',
      name: 'Asesino de Gorgath',
      requirement: 'Completa el Capítulo III',
    ),
    SummonerTitle(
      id: 'nyxara_slayer',
      name: 'Vencedor de Nyxara',
      requirement: 'Completa el Capítulo IV',
    ),
    SummonerTitle(
      id: 'azathor_slayer',
      name: 'Destructor de Azathor',
      requirement: 'Completa el Capítulo V',
    ),
    SummonerTitle(
      id: 'deadly_eye',
      name: 'Ojo de la Muerte',
      requirement: 'Encadena 10 Bullseyes',
    ),
    SummonerTitle(
      id: 'executioner',
      name: 'Verdugo de Ceniza',
      requirement: 'Inflige 500 de daño en un golpe',
    ),
    SummonerTitle(
      id: 'alchemist',
      name: 'Alquimista Abisal',
      requirement: 'Detona 50 Reacciones',
    ),
    SummonerTitle(
      id: 'card_king',
      name: 'Rey de las Cartas',
      requirement: 'Posee 20 cartas',
    ),
    SummonerTitle(
      id: 'seal_breaker',
      name: 'Quebrantormentas',
      requirement: 'Supera 5 Desafíos del Sello',
    ),
    SummonerTitle(
      id: 'abyss_wanderer',
      name: 'Viajero del Abismo',
      requirement: 'Alcanza la oleada 10',
    ),
    SummonerTitle(
      id: 'summoner_god',
      name: 'Dios Invocador',
      requirement: 'Domina todo el contenido',
    ),
  ];

  static SummonerTitle? byId(String id) {
    for (final t in titles) {
      if (t.id == id) return t;
    }
    return null;
  }

  /// Títulos desbloqueados con [stats], en orden de catálogo.
  static List<SummonerTitle> unlockedFor(SummonerStats stats) => [
        for (final t in titles)
          if (t.isUnlocked(stats)) t
      ];

  /// El título por defecto cuando todavía no se desbloqueó ninguno.
  static const SummonerTitle defaultTitle = SummonerTitle(
    id: 'novato',
    name: 'Novato del Abismo',
    requirement: 'Gana tu primer combate',
  );

  /// Resuelve el título equipado, cayendo al valor por defecto si el id no
  /// existe o no está desbloqueado.
  static SummonerTitle resolve(String? activeId, SummonerStats stats) {
    if (activeId == null) return SummonerTitles.defaultTitle;
    final title = byId(activeId);
    if (title == null) return SummonerTitles.defaultTitle;
    if (title.isUnlocked(stats)) return title;
    return SummonerTitles.defaultTitle;
  }
}
