#version 460 core
#include <flutter/runtime_effect.glsl>

// ──────────────────────────────────────────────────────────────────────────
// BRIMSTONE — elemental_weather.frag (LEVIATAN EDITION)
// Partículas luminosas de clima elemental (cenizas ascendentes ígneas,
// motas abisales, polvo telúrico, chispas del vacío) flotando sobre la
// escena. SIN oscurecer el fondo: capa aditiva de embers y sparkles.
// uniforms: uSize, uTime, uTint (rgb + intensity)
// ──────────────────────────────────────────────────────────────────────────

uniform vec2 uSize;   // 0,1
uniform float uTime;  // 2
uniform vec4 uTint;   // 3..6

out vec4 fragColor;

float hash(vec2 p) {
  p = fract(p * vec2(233.34, 851.73));
  p += dot(p, p + 23.45);
  return fract(p.x * p.y);
}

// Una partícula: posición cíclica + brillo con estela suave.
float particle(vec2 uv, vec2 seed, float speed, float size) {
  // Cae/asciende con drift lateral; wrap fract para loop infinito.
  float fall = fract(uv.y + seed.y + uTime * speed);
  float drift = sin((uTime + seed.x * 10.0) * 0.7) * 0.08;
  vec2 pos = vec2(
    fract(uv.x + seed.x + drift + fall * seed.x * 0.35),
    fall
  );
  float d = length((uv - pos) * vec2(uSize.x / max(uSize.y, 1.0), 1.0));
  // Glow suave con núcleo brillante.
  return smoothstep(size, 0.0, d) * (0.6 + 0.4 * hash(seed));
}

void main() {
  vec2 uv = FlutterFragCoord().xy / uSize;

  // Dos capas de 12 partículas con velocidades distintas (parallax).
  float acc = 0.0;
  for (int i = 0; i < 12; i++) {
    float fi = float(i);
    vec2 seedA = vec2(hash(vec2(fi, 1.0)), hash(vec2(fi, 2.0)));
    acc += particle(uv, seedA, 0.05 + hash(vec2(fi, 3.0)) * 0.08, 0.012);
  }
  for (int i = 12; i < 20; i++) {
    float fi = float(i);
    vec2 seedB = vec2(hash(vec2(fi, 4.0)), hash(vec2(fi, 5.0)));
    acc += particle(uv, seedB, 0.12 + hash(vec2(fi, 6.0)) * 0.14, 0.008)
        * 1.6; // capa cercana: más rápida y brillante
  }

  vec3 col = uTint.rgb * acc * 1.35;
  // Núcleos blancos incandescentes en las partículas más fuertes.
  col += vec3(1.0) * acc * acc * 0.55;

  fragColor = vec4(col * uTint.a, clamp(acc * uTint.a, 0.0, 1.0));
}
