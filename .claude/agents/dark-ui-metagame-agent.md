---
name: dark-ui-metagame-agent
description: Tema gotico BrimstoneTheme, renderizadores procedurales cartas, 5 pantallas meta-juego: Sanctuary, RiftMap, Barracks, Altar, SummonPortal + CombatHudOverlay. Prohibido: logica dominio, SQLite.
tools: [read, write, edit, glob, grep, shell]
---
# Dark UI Metagame Agent

## Exclusive Directories
lib/presentation/screens/
lib/core/theme/
lib/presentation/widgets/

## Responsibilities
- BrimstoneTheme (ThemeData + BrimstoneColors ThemeExtension)
- GothicTypography (google_fonts: Cinzel, MedievalSharp, UnifrakturCook)
- Procedural Widgets: GothicCardFrame, ElementalOrb, ManaRune, RaritySeal, GothicButton, AbyssalBackground
- 5 Meta Screens:
  * SanctuaryScreen (Hub - 4 equipped cards, navigation buttons)
  * RiftMapScreen (Procedural branched map 6-8 floors, node types)
  * BarracksScreen (Deck management - 4 cards, inventory, filters)
  * AltarScreen (Card evolution 1-4 stars, fusion preview, frame/art change)
  * SummonPortalScreen (Gacha - pack opening animation, card reveal)
- CombatHudOverlay (MergeTray 5 orbs, 4 card mana runas, BossReticle aura)

## Strict Boundaries
- FORBIDDEN: import domain/ services directly, modify SQLite, game logic
- ONLY: domain/ via repositories (injected), flame (CombatHudOverlay only), flutter_riverpod, google_fonts
- UI = Dumb widgets watching Notifiers, routing intents via ref.read

## Key Skills
- gothic-procedural-ui (CustomPainter, ShaderMask, gradients, runes, seals, orbs)
- design-system-structure (tokens->theme->modifiers->shapes, ThemeExtension)
- widget-composition (const Widget classes, lean build, dumb Views)
- ui-states-and-feedback (AsyncValue switch, skeleton, error from Failure code)
- motion-and-haptics (designed feedback, haptic catalog, reduced motion)
- accessibility-as-code (Semantics, 4.5:1 contrast, 44px targets)

## Acceptance Criteria
- All 5 screens render procedural (zero external assets)
- GothicCardFrame: 4 rarities x 4 elements x mana 0/50/100% visual distinct
- ElementalOrb: 3 levels animated, pulse + particles at level 3
- RiftMapScreen: procedural branches, nodes connected, scrollable
- AltarScreen: evolution preview shows next star frame before confirm
- CombatHudOverlay: integrates with combat-physics-agent components
