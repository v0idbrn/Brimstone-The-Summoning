#version 460 core
#include <flutter/runtime_effect.glsl>

// ──────────────────────────────────────────────────────────────────────────
// BRIMSTONE — foil_card.frag
// Physical collectible foiling: diagonal iridescent sweep + brushed metal
// micro-grain + prismatic edge shimmer. Overlaid additively over the card art
// for 3★ (Imperial Gold) and 4★ (Mythic Obsidian/Crimson) rarities.
// uTint.a carries the rarity intensity (0.35 gold, 0.65 mythic).
// ──────────────────────────────────────────────────────────────────────────

uniform vec2 uSize;    // 0,1
uniform float uTime;   // 2
uniform vec4 uTint;    // 3..6 (rgb hue bias + intensity)

out vec4 fragColor;

const float PI = 3.14159265359;

float hash(vec2 p) {
  p = fract(p * vec2(443.897, 441.423));
  p += dot(p, p + 19.19);
  return fract(p.x * p.y);
}

void main() {
  vec2 frag = FlutterFragCoord().xy;
  vec2 uv = frag / max(uSize, vec2(1.0));

  // ── Diagonal sweep (specular band travelling across the foil) ────────
  float diag = (uv.x + uv.y * 0.72);
  float sweep = fract(diag * 1.15 - uTime * 0.22);
  float band = pow(smoothstep(0.55, 1.0, 1.0 - abs(sweep - 0.5) * 2.0), 2.6);
  float bandSoft = pow(smoothstep(0.0, 1.0, 1.0 - abs(sweep - 0.5) * 2.0), 1.4);

  // ── Iridescent hue rotation driven by angle + position ───────────────
  float hue = fract(diag * 1.6 + uv.y * 0.9 + uTime * 0.06);
  vec3 rainbow = 0.5 + 0.5 * cos(6.28318 * (hue + vec3(0.0, 0.33, 0.67)));

  vec3 tint = clamp(uTint.rgb, 0.0, 1.0);
  vec3 foil = mix(tint, rainbow, 0.55);

  // ── Brushed metal micro-grain along the diagonal ─────────────────────
  float grain = hash(floor(frag * 1.35));
  float brushed = (grain - 0.5) * 0.10;

  // ── Corner glints ────────────────────────────────────────────────────
  vec2 c = uv - 0.5;
  float corner = smoothstep(0.62, 0.0, length(c * vec2(1.15, 1.0)));
  float glint = pow(corner, 5.0) * (0.35 + 0.25 * sin(uTime * 1.7));

  float intensity = uTint.a;
  float luminance = band * 0.85 + bandSoft * 0.28 + glint * 0.55 + brushed;

  // Slight darkening where the foil catches no light (metal anisotropy).
  float alpha = clamp(luminance * intensity, 0.0, 1.0) * 0.92;

  vec3 color = foil * (0.55 + 0.85 * luminance);
  color += vec3(0.10, 0.08, 0.14) * bandSoft;

  fragColor = vec4(color, alpha);
}
