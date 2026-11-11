#version 460 core
#include <flutter/runtime_effect.glsl>

// ──────────────────────────────────────────────────────────────────────────
// BRIMSTONE — mythic_aura.frag (LEVIATHAN EDITION)
// Prismática brillante para cartas 5★ y bordes OVERDRIVE: bandas espectrales
// rotando sobre un halo incandescente. NUNCA oscurece el fondo: solo emite
// luz aditiva sobre el rectángulo objetivo.
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

float noise(vec2 p) {
  vec2 i = floor(p);
  vec2 f = fract(p);
  vec2 u = f * f * (3.0 - 2.0 * f);
  return mix(
    mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
    mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x),
    u.y
  );
}

// Bandas prismáticas: 5 colores del espectro girando lentamente.
vec3 prismaticBand(vec2 uv, float t) {
  float angle = atan(uv.y - 0.5, uv.x - 0.5) + t * 0.9;
  float band = fract(angle / 6.2831853 * 5.0 + t * 0.15);
  vec3 c0 = vec3(1.00, 0.28, 0.55);
  vec3 c1 = vec3(1.00, 0.72, 0.24);
  vec3 c2 = vec3(0.45, 1.00, 0.62);
  vec3 c3 = vec3(0.36, 0.72, 1.00);
  vec3 c4 = vec3(0.70, 0.43, 1.00);
  if (band < 0.2) return mix(c0, c1, band / 0.2);
  if (band < 0.4) return mix(c1, c2, (band - 0.2) / 0.2);
  if (band < 0.6) return mix(c2, c3, (band - 0.4) / 0.2);
  if (band < 0.8) return mix(c3, c4, (band - 0.6) / 0.2);
  return mix(c4, c0, (band - 0.8) / 0.2);
}

void main() {
  vec2 uv = FlutterFragCoord().xy / uSize;
  vec2 p = uv - 0.5;
  float r = length(p) * 2.0;

  // Halo exterior: emisión intensa cerca del borde.
  float rim = smoothstep(0.45, 1.0, r);
  // Corona interior con shimmer.
  float shimmer = noise(uv * 9.0 + vec2(uTime * 1.7, -uTime * 1.1));
  float corona = smoothstep(0.15, 0.75, r) * (0.75 + 0.25 * shimmer);

  vec3 band = prismaticBand(uv, uTime);
  vec3 col = band * (rim * 1.25 + corona * 0.55);
  // Refuerzo del tinte elemental (mezcla, nunca reemplaza el prisma).
  col = mix(col, col * uTint.rgb * 1.35, 0.35);
  col += uTint.rgb * 0.30 * rim;

  float alpha = (rim * 0.95 + corona * 0.45) * uTint.a;
  fragColor = vec4(col * uTint.a, clamp(alpha, 0.0, 1.0));
}
