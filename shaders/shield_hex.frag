#version 460 core
#include <flutter/runtime_effect.glsl>

// ──────────────────────────────────────────────────────────────────────────
// BRIMSTONE — shield_hex.frag (LEVIATAN EDITION)
// Campo hexagonal cian/violeta brillante para la Barrera Arcana. Las
// celdas hexagonales se AGRIETAN según uDamage (0..1): grietas radiales
// que pierden brillo y dejan ver el fondo sin oscurecerlo nunca.
// uniforms: uSize, uTime, uDamage, uTint (rgb + intensity)
// ──────────────────────────────────────────────────────────────────────────

uniform vec2 uSize;    // 0,1
uniform float uTime;   // 2
uniform float uDamage; // 3  (0 = intacto, 1 = roto)
uniform vec4 uTint;    // 4..7

out vec4 fragColor;

// Hex grid: distancia a las 3 familias de líneas.
float hexLine(vec2 uv, float scale) {
  vec2 p = uv * scale;
  vec2 h = vec2(1.0, 1.7320508);
  vec2 a = mod(p, h) - h * 0.5;
  vec2 b = mod(p + h * 0.5, h) - h * 0.5;
  vec2 g = dot(a, a) < dot(b, b) ? a : b;
  float d = min(
    abs(g.x * 0.8660254 + g.y * 0.5) - 0.077,
    abs(g.y) - 0.077
  );
  return smoothstep(0.035, 0.0, d);
}

float hash(vec2 p) {
  p = fract(p * vec2(233.34, 851.73));
  p += dot(p, p + 23.45);
  return fract(p.x * p.y);
}

void main() {
  vec2 uv = FlutterFragCoord().xy / uSize;
  float pulse = 0.85 + 0.15 * sin(uTime * 3.0);

  // Malla hexagonal: líneas cian con relleno violeta translúcido.
  float lines = hexLine(uv, 11.0);
  float fill = hexLine(uv, 11.0) * 0.0;
  vec2 cell = uv * 11.0;
  float cellNoise = hash(floor(cell));

  // Grietas: crecen con uDamage desde los bordes hacia el centro.
  float cracks = 0.0;
  if (uDamage > 0.01) {
    float r = length(uv - 0.5) * 2.0;
    float crackSeed = hash(floor(cell + 0.5));
    float threshold = 1.0 - uDamage;
    cracks = step(crackSeed, 1.0 - threshold * (1.0 - 0.35 * r))
        * (0.5 + 0.5 * cellNoise);
  }

  // Color: cian núcleo + violeta halo (SIEMPRE luminoso).
  vec3 cyan = vec3(0.25, 0.85, 1.00);
  vec3 violet = vec3(0.70, 0.43, 1.00);
  vec3 col = mix(cyan, violet, 0.35 + 0.3 * cellNoise) * lines * pulse;
  col += violet * 0.22 * pulse;           // relleno translúcido brillante
  col += vec3(1.0) * cracks * 0.9;        // grietas blancas incandescentes

  // Alpha: líneas fuertes + relleno; las celdas agrietadas se apagan.
  float alpha = (lines * 0.9 + 0.28) * pulse * (1.0 - uDamage * 0.35);
  fragColor = vec4(col * uTint.a, clamp(alpha * uTint.a, 0.0, 1.0));
}
