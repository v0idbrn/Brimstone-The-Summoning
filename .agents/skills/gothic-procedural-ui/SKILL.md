---
name: gothic-procedural-ui
description: Patrones de diseño procedural gótico: CustomPainter, ShaderMask, gradientes, tipografía, marcos, runas, sellos, esferas
version: 1.0.0
---

# Gothic Procedural UI Skill

## Propósito
Patrones de diseño 100% procedurales (sin assets externos) para UI gótica/arcana en Flutter: marcos metálicos, runas de maná, sellos de rareza 1★-4★, esferas elementales animadas, gradientes abisales.

---

## Stack Tecnológico
- **CustomPainter** + **Canvas** para todo renderizado
- **ShaderMask** + **LinearGradient/RadialGradient/SweepGradient** para efectos
- **google_fonts** para tipografía gótica (Cinzel, MedievalSharp, UnifrakturCook)
- **flutter_animate** para animaciones declarativas
- **NO** Image.asset, NO spritesheets en v1

---

## Paleta Gótica Brimstone (ThemeExtension)
`dart
// lib/core/theme/brimstone_theme.dart
class BrimstoneColors extends ThemeExtension<BrimstoneColors> {
  // Abyssal Gradients
  static const abyssalStart = Color(0xFF0A0A1A);  // Negro abisal
  static const abyssalMid = Color(0xFF1A0A2E);    // Purpura profundo
  static const abyssalEnd = Color(0xFF0D0D1A);    // Casi negro
  
  // Elemental Colors
  static const igneous = Color(0xFFFF4500);       // Rojo fuego
  static const abyssalElement = Color(0xFF00FFFF); // Cian hielo
  static const telluric = Color(0xFFDAA520);      // Dorado tierra
  static const voidColor = Color(0xFF8A2BE2);     // Purpura vacio
  
  // Metallic Frames
  static const bronze = Color(0xFFCD7F32);        // 1★ Común
  static const silver = Color(0xFFC0C0C0);        // 2★ Épica
  static const gold = Color(0xFFFFD700);          // 3★ Legendaria
  static const platinum = Color(0xFFE5E4E2);      // 4★ Mítica
  
  // Runes & Glow
  static const manaGlow = Color(0xFFFFFFFF);      // Blanco puro runas
  static const runeInactive = Color(0xFF333344);  // Gris apagado
}
`

---

## Componentes Procedurales Core

### 1. GothicCardFrame (CustomPainter)
`dart
class GothicCardFramePainter extends CustomPainter {
  final Rarity rarity; // 1 a 4 estrellas
  final Element element; // para acento de color
  final double manaProgress; // 0.0 a 1.0 (runas brillantes)
  
  @override
  void paint(Canvas canvas, Size size) {
    // 1. Fondo gradiente abisal (Rect)
    // 2. Marco metálico segun rareza (Path: bordes biselados + esquinas góticas)
    // 3. Filigrana interior (dibujar con Path + stroke fino color metal)
    // 4. Sello de rareza (estrellas) en esquina sup-der
    // 5. Runas de maná en borde inferior (4 runas, brillan segun manaProgress)
    // 6. Orbe elemental central (delegar a ElementalOrbPainter)
    // 7. Nombre carta (TextPainter con fuente gótica)
  }
}
`

### 2. ElementalOrbPainter (CustomPainter - Animado)
`dart
class ElementalOrbPainter extends CustomPainter {
  final Element element;
  final int level; // 1, 2, 3
  final double pulsePhase; // 0.0 a 1.0 (animacion loop)
  
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width/2, size.height/2);
    final baseRadius = size.width * 0.4;
    
    // Nucleo: RadialGradient elemento (centro brillante -> borde oscuro)
    // Nivel 1: pulso suave (sin(2π * pulsePhase) * 0.05)
    // Nivel 2: + anillo exterior rotatorio (SweepGradient)
    // Nivel 3: + partículas orbitando (dibujar 6-8 puntos en circulo)
    // Todos: ShaderMask para brillo  mágico en bordes
  }
}
`

### 3. ManaRunePainter (CustomPainter)
`dart
class ManaRunePainter extends CustomPainter {
  final int runeIndex; // 0-3 (4 runas por carta)
  final bool isActive; // manaProgress > threshold
  final Element element;
  
  @override
  void paint(Canvas canvas, Size size) {
    // Glifo rúnico procedural: Path con curvas bezier predefinidas por elemento
    // Inactivo: color runeInactive, stroke 1px
    // Activo: ShaderMask gradiente elemento + bloom (blur mask filter)
    // Animación: escala 1.0 <-> 1.15 al activarse
  }
}
`

### 4. RaritySealPainter (CustomPainter)
`dart
class RaritySealPainter extends CustomPainter {
  final int stars; // 1 a 4
  final double size;
  
  @override
  void paint(Canvas canvas, Size size) {
    // Sello circular con estrellas pentagonales
    // 1★: Bronce, 1 estrella centrada
    // 2★: Plata, 2 estrellas
    // 3★: Oro, 3 estrellas + filigrana
    // 4★: Platino, 4 estrellas + corona exterior + brillo pulsante
  }
}
`

### 5. AbyssalGradientBackground (Widget)
`dart
class AbyssalBackground extends StatelessWidget {
  final Widget child;
  
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [abyssalStart, abyssalMid, abyssalEnd],
          stops: [0.0, 0.5, 1.0],
        ),
      ),
      child: Stack(
        children: [
          // Partículas flotantes sutiles (CustomPainter animado)
          // Runas de fondo muy tenues (opacidad 0.03)
          child,
        ],
      ),
    );
  }
}
`

---

## Tipografía Gótica (google_fonts)
`dart
// lib/core/theme/gothic_typography.dart
class GothicTypography {
  static TextStyle title = GoogleFonts.cinzel(
    fontSize: 24, fontWeight: FontWeight.w700, color: Colors.white,
    shadows: [Shadow(color: Colors.black87, offset: Offset(1,1), blurRadius: 2)],
  );
  static TextStyle body = GoogleFonts.medievalSharp(
    fontSize: 14, color: Colors.white70, height: 1.4,
  );
  static TextStyle rune = GoogleFonts.unifrakturCook(
    fontSize: 18, color: BrimstoneColors.manaGlow,
  );
  static TextStyle damageNumber = GoogleFonts.cinzel(
    fontSize: 32, fontWeight: FontWeight.w900, color: Colors.amberAccent,
    shadows: [Shadow(color: Colors.deepOrange, offset: Offset(2,2), blurRadius: 4)],
  );
}
`

---

## Pantallas Meta-Juego (5 Screens + CombatHudOverlay)

| Screen | Componentes Procedurales Clave |
|--------|-------------------------------|
| **SanctuaryScreen** (Hub) | AbyssalBackground, GothicCardFrame (4 cartas equipadas), Botones góticos navegar |
| **RiftMapScreen** | Mapa procedural ramificado (CustomPainter nodos/conexiones), Nodos: Combate/Elite/Altar/Jefe |
| **BarracksScreen** | Grid cartas (GothicCardFrame), Filtros elemento/rareza, Detalle carta modal |
| **AltarScreen** | Fusor cartas: 2 cartas misma base + esencias -> evolución 1★→4★, Preview marco nuevo |
| **SummonPortalScreen** | Animación invocación: vórtice ShaderMask + partículas + reveal carta (GothicCardFrame) |
| **CombatHudOverlay** | MergeTray (5 ElementalOrbPainter), 4 Cartas mana (runas), BossReticle (aura visual) |

---

## Botones y Controles Góticos
`dart
class GothicButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final Element? elementAccent;
  
  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (bounds) => LinearGradient(
        colors: [elementColor?.withOpacity(0.8) ?? Colors.grey, 
                 elementColor?.withOpacity(0.4) ?? Colors.grey.shade700],
      ).createShader(bounds),
      blendMode: BlendMode.srcATop,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              border: Border.all(color: elementColor ?? Colors.grey, width: 2),
              borderRadius: BorderRadius.circular(8),
              gradient: LinearGradient(
                colors: [Colors.black87, Colors.black54],
                begin: Alignment.topLeft, end: Alignment.bottomRight,
              ),
            ),
            child: Text(label, style: GothicTypography.body),
          ),
        ),
      ),
    );
  }
}
`

---

## Animaciones Procedurales (flutter_animate)
- **Carta reveal**: adeIn + scale (0.8->1.0) + shimmer ShaderMask
- **Fusión orbes**: scale (1.0->1.3->1.0) + otate + partículas burst
- **Reacción elemental**: shake (screen) + adeIn partículas color reacción + 	int diana
- **Evolución carta**: lip 3D + scale + nuevo marco shimmer loop
- **Invocación**: vórtice otate 360° + scale 0->1 + adeIn carta

---

## Prohibiciones Estrictas
- ❌ NO Image.asset, NO spritesheets, NO assets externales en v1
- ❌ NO Container/BoxDecoration para formas complejas -> CustomPainter
- ❌ NO hardcodear colores -> usar BrimstoneColors / ThemeExtension
- ❌ NO animaciones imperativas -> flutter_animate declarativo
- ❌ NO lógica de juego en painters -> solo renderizado puro

---

## Tests Requeridos (widget-golden-and-a11y-testing)
- gothic_card_frame_golden_test.dart: 4 rarezas, 4 elementos, mana 0%/50%/100%
- elemental_orb_animation_test.dart: 3 niveles, pulse phase loop
- arity_seal_golden_test.dart: 1★ a 4★ visual correcto
- byssal_background_test.dart: gradiente + particulas no crashea
- gothic_button_a11y_test.dart: semantics label, contraste 4.5:1, touch target 44px
