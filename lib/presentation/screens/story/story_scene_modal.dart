import 'package:flutter/material.dart';

/// Modal ilustrado para escenas de historia (Prólogo, Mini-Jefe, Epílogo).
class StorySceneModal extends StatelessWidget {
  final String title;
  final String illustrationAsset;
  final List<String> dialogueLines;
  final VoidCallback onContinue;

  const StorySceneModal({
    super.key,
    required this.title,
    required this.illustrationAsset,
    required this.dialogueLines,
    required this.onContinue,
  });

  static Future<void> show({
    required BuildContext context,
    required String title,
    required String illustrationAsset,
    required List<String> dialogueLines,
    required VoidCallback onContinue,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => StorySceneModal(
        title: title,
        illustrationAsset: illustrationAsset,
        dialogueLines: dialogueLines,
        onContinue: onContinue,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        decoration: BoxDecoration(
          color: const Color(0xFF0C0608),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFB16EFF), width: 2),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFB16EFF).withValues(alpha: 0.3),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header con título
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF1A0A0F), Color(0xFF0C0608)],
                ),
                borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
                border: Border(
                  bottom: BorderSide(color: Color(0xFFB16EFF), width: 1),
                ),
              ),
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFFB16EFF),
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            // Ilustración
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Container(
                      width: double.infinity,
                      height: 220,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: const Color(0xFF2A151A), width: 1),
                        image: DecorationImage(
                          image: AssetImage(illustrationAsset),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Diálogo
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF14090D),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF2A151A)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: dialogueLines
                            .map(
                              (line) => Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Text(
                                  line,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Botón continuar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    onContinue();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFB16EFF),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 4,
                  ),
                  child: const Text(
                    'CONTINUAR',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
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

/// Datos de escenas de historia por capítulo.
class StoryScenes {
  static const Map<int, Map<String, StorySceneData>> chapterScenes = {
    1: {
      'prologue': StorySceneData(
        title: 'PRÓLOGO: LA FORJA DE CENIZA',
        illustration: 'assets/portraits/boss_pyroth.webp',
        dialogue: [
          'Las cenizas del viejo mundo aún arden bajo la Forja.',
          'Pyroth, el Coloso de Ceniza, ha despertado de su letargo.',
          'Su martillo golpea el yunque eterno, forjando cadenas de fuego.',
          'Solo un Invocador puede apagar la llama que todo lo consume.',
        ],
      ),
      'miniboss': StorySceneData(
        title: 'PISO 4: IGNAROK, CARCELERO DE MAGMA',
        illustration: 'assets/portraits/ignis_colossus.webp',
        dialogue: [
          'El calor se intensifica. El aire vibra con cada paso.',
          'Ignarok bloquea el camino, su armadura fluye como lava viva.',
          '"Nadie abandona la Forja", ruge, y el magma responde a su llamada.',
          'Derrotarlo te otorgará una Reliquia de su esencia ardiente.',
        ],
      ),
      'epilogue': StorySceneData(
        title: 'EPÍLOGO: LA LLAMA SE APAGA',
        illustration: 'assets/portraits/boss_pyroth.webp',
        dialogue: [
          'El último golpe resuena. Pyroth cae de rodillas.',
          'Su fuego interno se apaga, dejando solo cenizas frías.',
          'La Forja de Ceniza queda en silencio... por ahora.',
          'El camino a la Fosa de Escarcha se abre ante ti.',
        ],
      ),
    },
    2: {
      'prologue': StorySceneData(
        title: 'PRÓLOGO: LA FOSA DE ESCARCHA',
        illustration: 'assets/portraits/boss_vaelor.webp',
        dialogue: [
          'Donde el fuego muere, el hielo reina supremo.',
          'Vaelor, Señor de la Fosa Helada, observa desde su trono de hielo.',
          'Susurra con voz de ventisca: "El calor es una deuda que se paga con sangre."',
          'El frío te cala los huesos antes de siquiera empezar.',
        ],
      ),
      'miniboss': StorySceneData(
        title: 'PISO 4: CRYON, VERDUGO DEL GLACIAR',
        illustration: 'assets/portraits/abyss_leviathan.webp',
        dialogue: [
          'El suelo cruje bajo tus pies. Es hielo milenario.',
          'Cryon emerge del glaciar, su hoja tallada en escarcha perpetua.',
          '"El Glaciar no perdona", sentencia, y el aire se congela a su paso.',
          'Su Reliquia guarda el secreto del invierno eterno.',
        ],
      ),
      'epilogue': StorySceneData(
        title: 'EPÍLOGO: EL HIELO SE ROMPE',
        illustration: 'assets/portraits/boss_vaelor.webp',
        dialogue: [
          'Vaelor se desvanece en copos de nieve.',
          'Su trono de hielo se agrieta, revelando el camino profundo.',
          'La Fosa ha sido reclamada. El calor vuelve a tus manos.',
          'El Bastión Tectónico aguarda bajo la corteza.',
        ],
      ),
    },
    3: {
      'prologue': StorySceneData(
        title: 'PRÓLOGO: EL BASTIÓN TECTÓNICO',
        illustration: 'assets/portraits/boss_gorgath.webp',
        dialogue: [
          'Bajo la superficie, la tierra recuerda cada paso.',
          'Gorgath, Monarca de Basalto, lleva el peso de mil montañas.',
          'Su voz es un temblor: "La roca aguanta. Los huesos se rompen."',
          'Cada golpe contra él despierta la furia tectónica.',
        ],
      ),
      'miniboss': StorySceneData(
        title: 'PISO 4: KRAG, DEMOLEDOR MONOLÍTICO',
        illustration: 'assets/portraits/terra_behemoth.webp',
        dialogue: [
          'Las paredes tiemblan. El polvo cae del techo.',
          'Krag rompe la roca como si fuera papel, emergiendo imponente.',
          '"La montaña cae sobre ti", declara, y el suelo se abre.',
          'Su Reliquia late con el ritmo del corazón de la tierra.',
        ],
      ),
      'epilogue': StorySceneData(
        title: 'EPÍLOGO: LA TIERRA DESCANSA',
        illustration: 'assets/portraits/boss_gorgath.webp',
        dialogue: [
          'Gorgath se arrodilla, y la tierra deja de temblar.',
          'El Basalto se aquieta. Las grietas se sellan.',
          'El Bastión ha caído. Las sombras se alargan adelante.',
          'El Velo de las Pesadillas te espera en la penumbra.',
        ],
      ),
    },
    4: {
      'prologue': StorySceneData(
        title: 'PRÓLOGO: EL VELO DE LAS PESADILLAS',
        illustration: 'assets/portraits/boss_nyxara.webp',
        dialogue: [
          'Donde la luz no llega, las pesadillas tejen su tela.',
          'Nyxara, Tejedora del Eclipse, baila entre sombras.',
          'Susurra: "No hay escape del vacío. Solo la noche eterna."',
          'La realidad se dobla a su alrededor.',
        ],
      ),
      'miniboss': StorySceneData(
        title: 'PISO 4: MORVATH, TEJEDOR DE SOMBRAS',
        illustration: 'assets/portraits/void_malakor.webp',
        dialogue: [
          'La oscuridad se condensa. Una figura emerge de la nada.',
          'Morvath teje hilos de sombra alrededor de tu cuello.',
          '"El Velo se cierra sobre ti", susurra, y la luz muere.',
          'Su Reliquia contiene un fragmento de noche eterna.',
        ],
      ),
      'epilogue': StorySceneData(
        title: 'EPÍLOGO: EL ECLIPSE TERMINA',
        illustration: 'assets/portraits/boss_nyxara.webp',
        dialogue: [
          'Nyxara se desvanece en la penumbra, su tejido roto.',
          'La primera luz en eones atraviesa el Velo.',
          'Las Pesadillas retroceden. El Trono del Sello Roto aparece.',
          'Azathor te espera. El fin de todo comienza ahora.',
        ],
      ),
    },
    5: {
      'prologue': StorySceneData(
        title: 'PRÓLOGO: EL TRONO DEL SELLO ROTO',
        illustration: 'assets/portraits/boss_azathor.webp',
        dialogue: [
          'El Sello que contenía el Vacío está roto.',
          'Azathor, Gran Arconte del Sello, se alza sobre la realidad fracturada.',
          'Su voz resuena en todas las dimensiones: "El Vacío es absoluto. Nada permanece."',
          'Esta es la batalla final. No hay retorno.',
        ],
      ),
      'miniboss': StorySceneData(
        title: 'PISO 4: MALPHAS, HERALDO DEL TRONO',
        illustration: 'assets/portraits/void_malakor.webp',
        dialogue: [
          'El aire se distorsiona. La realidad parpadea.',
          'Malphas desciende, sus alas rasgando el tejido del mundo.',
          '"El Trono del Sello Roto no conoce señor salvo Azathor."',
          'Su Reliquia es una llave a la nada misma.',
        ],
      ),
      'epilogue': StorySceneData(
        title: 'EPÍLOGO: EL VACÍO SE SELLA',
        illustration: 'assets/portraits/boss_azathor.webp',
        dialogue: [
          'Azathor cae. El Vacío retrocede, sellado una vez más.',
          'La luz retorna a los rincones más oscuros del mundo.',
          'Los Invocadores cantarán tu nombre por eras.',
          'Pero el Abismo es paciente... y siempre regresa.',
        ],
      ),
    },
  };
}

class StorySceneData {
  final String title;
  final String illustration;
  final List<String> dialogue;

  const StorySceneData({
    required this.title,
    required this.illustration,
    required this.dialogue,
  });
}
