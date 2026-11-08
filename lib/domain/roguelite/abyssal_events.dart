/// Encuentros narrativos de la Grieta ("Encuentros del Abismo").
///
/// Cada evento ofrece tres caminos y altera de verdad el estado de la
/// incursión: vida, oro, esquirlas, maná inicial o reliquias. Dominio puro:
/// sin Flutter, sin Flame y sin acceso a SQLite.
library;

/// Una de las tres decisiones de un [AbyssalEvent].
class AbyssalEventOption {
  /// Texto mostrado en el modal.
  final String label;

  /// Variación de vida en puntos porcentuales del máximo (negativo = daño).
  final int hpDelta;

  /// Variación de oro de la incursión.
  final int goldDelta;

  /// Variación de esquirlas de la incursión.
  final int shardsDelta;

  /// Fracción de maná extra con la que arranca el próximo combate (-1.0 a 1.0).
  final double manaDelta;

  /// Reliquia abisal otorgada (null si la opción no entrega ninguna).
  final String? relicId;

  const AbyssalEventOption({
    required this.label,
    this.hpDelta = 0,
    this.goldDelta = 0,
    this.shardsDelta = 0,
    this.manaDelta = 0.0,
    this.relicId,
  });

  /// Etiqueta compacta de efectos para la UI (por ejemplo "+6 oro · -8% HP").
  String get effectSummary {
    final parts = <String>[];
    if (hpDelta != 0) parts.add('${hpDelta > 0 ? '+' : ''}$hpDelta% HP');
    if (goldDelta != 0) parts.add('${goldDelta > 0 ? '+' : ''}$goldDelta oro');
    if (shardsDelta != 0) {
      parts.add('${shardsDelta > 0 ? '+' : ''}$shardsDelta esquirlas');
    }
    if (manaDelta != 0) {
      parts
          .add('${manaDelta > 0 ? '+' : ''}${(manaDelta * 100).round()}% maná');
    }
    if (relicId != null) parts.add('Reliquia');
    return parts.isEmpty ? 'Sin efecto' : parts.join(' · ');
  }
}

/// Un encuentro misterioso de la Grieta.
class AbyssalEvent {
  final String id;
  final String title;
  final String description;
  final List<AbyssalEventOption> options;

  const AbyssalEvent({
    required this.id,
    required this.title,
    required this.description,
    required this.options,
  });
}

/// Resultado puro de aplicar una opción sobre el estado de la incursión.
class AbyssalEventOutcome {
  final double playerHp;
  final int gold;
  final int shards;
  final double startManaFraction;
  final List<String> relicIds;
  final int hpLost;
  final String? relicId;

  const AbyssalEventOutcome({
    required this.playerHp,
    required this.gold,
    required this.shards,
    required this.startManaFraction,
    required this.relicIds,
    required this.hpLost,
    this.relicId,
  });
}

/// Aplica [option] sobre el estado actual de una incursión y devuelve el
/// estado resultante. Función pura: no muta los argumentos.
AbyssalEventOutcome applyAbyssalOption({
  required AbyssalEventOption option,
  required double playerHp,
  required double playerMaxHp,
  required int gold,
  required int shards,
  required double startManaFraction,
  required List<String> relicIds,
}) {
  final hpDelta = playerMaxHp * option.hpDelta / 100.0;
  final nextHp = (playerHp + hpDelta).clamp(0.0, playerMaxHp).toDouble();
  final nextMana =
      (startManaFraction + option.manaDelta).clamp(0.0, 1.0).toDouble();
  final nextRelics = <String>[...relicIds];
  final relic = option.relicId;
  if (relic != null && !nextRelics.contains(relic)) {
    nextRelics.add(relic);
  }
  return AbyssalEventOutcome(
    playerHp: nextHp,
    gold: (gold + option.goldDelta).clamp(0, 999999).toInt(),
    shards: (shards + option.shardsDelta).clamp(0, 999999).toInt(),
    startManaFraction: nextMana,
    relicIds: List<String>.unmodifiable(nextRelics),
    hpLost: hpDelta < 0 ? -hpDelta.round() : 0,
    relicId: relic,
  );
}

/// El catálogo de los 10 Encuentros del Abismo.
class AbyssalEvents {
  static const List<AbyssalEvent> all = [
    AbyssalEvent(
      id: 'mirror_of_blood',
      title: 'El Espejo de Sangre',
      description:
          'Un cristal de obsidiana refleja un invocador que no eres tú. '
          'Su mano se extiende desde el vidrio, ofreciendo un trato.',
      options: [
        AbyssalEventOption(
          label: 'Aceptar la mano del reflejo',
          hpDelta: -10,
          goldDelta: 40,
          manaDelta: 0.10,
          relicId: 'sombra_perdida',
        ),
        AbyssalEventOption(
          label: 'Romper el espejo de un golpe',
          hpDelta: -18,
          shardsDelta: 6,
          relicId: 'cadenas_sello',
        ),
        AbyssalEventOption(
          label: 'Apartar la mirada y seguir',
          shardsDelta: 3,
        ),
      ],
    ),
    AbyssalEvent(
      id: 'blind_gambler',
      title: 'El Apostador Ciego',
      description: 'Un encapuchado sin ojos baraja cartas de hueso. '
          '"Una tirada, invocador. El Abismo siempre cobra."',
      options: [
        AbyssalEventOption(
          label: 'Apostar al as de ceniza',
          goldDelta: 35,
          hpDelta: -8,
          relicId: 'grimorio_antiguo',
        ),
        AbyssalEventOption(
          label: 'Apostar los dados de sangre',
          hpDelta: -15,
          shardsDelta: 8,
          manaDelta: -0.15,
          relicId: 'tunica_vacio',
        ),
        AbyssalEventOption(
          label: 'Retirarse de la mesa',
          shardsDelta: 4,
        ),
      ],
    ),
    AbyssalEvent(
      id: 'corrupted_fountain',
      title: 'La Fuente Corrupta',
      description:
          'El agua brota negra y tibia. Las letras talladas dicen que beber '
          'otorga poder, pero nadie recuerda el precio.',
      options: [
        AbyssalEventOption(
          label: 'Beber hasta saciarte',
          manaDelta: 0.55,
          goldDelta: 15,
          relicId: 'reloj_ceniza',
        ),
        AbyssalEventOption(
          label: 'Beber un sorbo prudente',
          hpDelta: -10,
          manaDelta: 0.25,
          shardsDelta: 2,
        ),
        AbyssalEventOption(
          label: 'Arrojar una moneda y marcharte',
          goldDelta: -20,
          relicId: 'ceniza_volatil',
        ),
      ],
    ),
    AbyssalEvent(
      id: 'ancient_seal',
      title: 'El Sello Antiguo',
      description: 'Un sello de basalto vibra en el suelo de la grieta. '
          'Algo duerme debajo y respira al mismo ritmo que tú.',
      options: [
        AbyssalEventOption(
          label: 'Sostener la runa central',
          hpDelta: -9,
          goldDelta: 30,
          relicId: 'martillo_titan',
        ),
        AbyssalEventOption(
          label: 'Quebrar el sello',
          hpDelta: -20,
          shardsDelta: 9,
          relicId: 'corazon_phoenix',
        ),
        AbyssalEventOption(
          label: 'Recoger los fragmentos sueltos',
          shardsDelta: 5,
        ),
      ],
    ),
    AbyssalEvent(
      id: 'blighted_forge',
      title: 'La Forja Maldita',
      description: 'Un yunque abandonado sigue golpeando por sí solo. '
          'Cada martillazo escupe chispas que dibujan un rostro.',
      options: [
        AbyssalEventOption(
          label: 'Templar tu arma en la forja',
          hpDelta: -6,
          goldDelta: 25,
          relicId: 'llama_eterna',
        ),
        AbyssalEventOption(
          label: 'Alimentar la forja con tu sangre',
          hpDelta: -16,
          shardsDelta: 7,
          relicId: 'sombra_perdida',
        ),
        AbyssalEventOption(
          label: 'Robar el carbón encendido',
          goldDelta: 10,
          relicId: 'ceniza_volatil',
        ),
      ],
    ),
    AbyssalEvent(
      id: 'errant_merchant',
      title: 'El Mercader Errante',
      description: 'Una armadura vacía empuja un carro de reliquias. '
          'No tiene rostro, pero sabe exactamente lo que necesitas.',
      options: [
        AbyssalEventOption(
          label: 'Comprar el amuleto agrietado',
          goldDelta: -30,
          hpDelta: 12,
          relicId: 'colmillo_vampirico',
        ),
        AbyssalEventOption(
          label: 'Pagar con un recuerdo de sangre',
          hpDelta: -14,
          relicId: 'tunica_vacio',
        ),
        AbyssalEventOption(
          label: 'Dejar que siga su camino',
          shardsDelta: 4,
        ),
      ],
    ),
    AbyssalEvent(
      id: 'obsidian_chalice',
      title: 'El Cáliz de Obsidiana',
      description: 'Un cáliz negro rebosa un líquido que no refleja la luz. '
          'Dicen que beberlo acelera el maná y corrompe el alma.',
      options: [
        AbyssalEventOption(
          label: 'Beber el cáliz entero',
          manaDelta: 0.70,
          hpDelta: -5,
          shardsDelta: 5,
          relicId: 'reloj_ceniza',
        ),
        AbyssalEventOption(
          label: 'Mojar sólo los labios',
          manaDelta: 0.20,
          relicId: 'prisma_caos',
        ),
        AbyssalEventOption(
          label: 'Volcarlo sobre la roca',
          goldDelta: 15,
          hpDelta: -2,
        ),
      ],
    ),
    AbyssalEvent(
      id: 'void_whispers',
      title: 'Susurros del Vacío',
      description: 'Las paredes respiran nombres. Uno de ellos es el tuyo, '
          'pronunciado por una voz que aún no ha nacido.',
      options: [
        AbyssalEventOption(
          label: 'Escuchar hasta el final',
          hpDelta: -6,
          goldDelta: 25,
          shardsDelta: 6,
          relicId: 'llama_eterna',
        ),
        AbyssalEventOption(
          label: 'Responder al susurro',
          hpDelta: -13,
          manaDelta: 0.30,
          relicId: 'cadenas_sello',
        ),
        AbyssalEventOption(
          label: 'Tapar tus oídos y correr',
          shardsDelta: 3,
        ),
      ],
    ),
    AbyssalEvent(
      id: 'fallen_guardian',
      title: 'El Guardián Caído',
      description: 'Un coloso de piedra yace partido en dos. '
          'Su juramento sigue intacto, esperando a alguien que lo herede.',
      options: [
        AbyssalEventOption(
          label: 'Absolver al guardián',
          hpDelta: -7,
          goldDelta: 35,
          relicId: 'martillo_titan',
        ),
        AbyssalEventOption(
          label: 'Saquear su armadura',
          hpDelta: -15,
          goldDelta: -10,
          shardsDelta: 8,
          relicId: 'grimorio_antiguo',
        ),
        AbyssalEventOption(
          label: 'Rezar por su descanso',
          shardsDelta: 5,
          manaDelta: 0.10,
        ),
      ],
    ),
    AbyssalEvent(
      id: 'cinder_pact',
      title: 'Pacto de Ceniza',
      description:
          'Una figura de ceniza te extiende un contrato escrito con tu propia '
          'letra. La firma ya está puesta.',
      options: [
        AbyssalEventOption(
          label: 'Firmar y cobrar el adelanto',
          hpDelta: -8,
          goldDelta: 60,
          shardsDelta: 6,
          relicId: 'prisma_caos',
        ),
        AbyssalEventOption(
          label: 'Quemar el contrato',
          hpDelta: -12,
          shardsDelta: 10,
          manaDelta: 0.15,
        ),
        AbyssalEventOption(
          label: 'Escapar entre las cenizas',
          shardsDelta: 3,
        ),
      ],
    ),
  ];

  /// Busca un evento por id. Lanza [ArgumentError] si no existe.
  static AbyssalEvent byId(String id) => all.firstWhere(
        (e) => e.id == id,
        orElse: () => throw ArgumentError('Evento abisal desconocido: $id'),
      );
}
