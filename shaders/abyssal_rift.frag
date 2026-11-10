#version 460 core
#include <flutter/runtime_effect.glsl>

// ──────────────────────────────────────────────────────────────────────────
// BRIMSTONE — abyssal_rift.frag
// Living dimensional rift: polar swirl + fbm turbulence + elemental corona.
// Used by the combat arena portal plane, the Summon Portal vortex and the
// Altar evolution aura. Falls back to canvas gradients when unavailable.
// ──────────────────────────────────────────────────────────────────────────

uniform vec2 uSize;    // 0,1  render surface size (px)
uniform float uTime;   // 2    seconds since mount
uniform vec4 uTint;    // 3..6 elemental tint (rgb) + intensity (a)

out vec4 fragColor;

const float PI = 3.14159265359;

float hash(vec2 p) {
  p = fract(p * vec2(123.34, 456.21));
  p += dot(p, p + 45.32);
  return fract(p.x * p.y);
}

float noise(vec2 p) {
  vec2 i = floor(p);
  vec2 f = fract(p);
  vec2 u = f * f * (3.0 - 2.0 * f);
  float a = hash(i);
  float b = hash(i + vec2(1.0, 0.0));
  float c = hash(i + vec2(0.0, 1.0));
  float d = hash(i + vec2(1.0, 1.0));
  return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float fbm(vec2 p) {
  float value = 0.0;
  float amplitude = 0.55;
  mat2 rot = mat2(0.80, 0.60, -0.60, 0.80);
  for (int i = 0; i < 5; i++) {
    value += amplitude * noise(p);
    p = rot * p * 2.03 + 11.7;
    amplitude *= 0.52;
  }
  return value;
}

void main() {
  vec2 frag = FlutterFragCoord().xy;
  vec2 uv = frag / max(uSize, vec2(1.0));
  vec2 centered = (uv - 0.5) * vec2(uSize.x / max(uSize.y, 1.0), 1.0);

  float radius = length(centered);
  float angle = atan(centered.y, centered.x);

  // Mask so the effect lives inside an organic ellipse, never a hard square.
  float outer = smoothstep(0.72, 0.18, radius);
  if (outer <= 0.001) {
    fragColor = vec4(0.0);
    return;
  }

  // ── Polar swirl: two counter-rotating ribbons ────────────────────────
  float swirl = angle * 3.0 + uTime * 0.85 - radius * 7.5;
  float counter = -angle * 2.0 - uTime * 1.35 + radius * 4.0;
  float ribbon = 0.5 + 0.5 * sin(swirl);
  float ribbon2 = 0.5 + 0.5 * sin(counter);
  float spiral = pow(ribbon * 0.62 + ribbon2 * 0.38, 2.4);

  // ── Turbulent magma / void matter ────────────────────────────────────
  vec2 flow = centered * 3.4;
  flow += vec2(cos(uTime * 0.3), sin(uTime * 0.27)) * 0.6;
  float turb = fbm(flow + fbm(flow * 1.9 - uTime * 0.12));

  // ── Pulsing heart of the rift ────────────────────────────────────────
  float heart = smoothstep(0.34, 0.0, radius);
  float pulse = 0.72 + 0.28 * sin(uTime * 2.1 - radius * 12.0);

  float energy = clamp(spiral * 0.55 + turb * 0.62 + heart * pulse * 1.15, 0.0, 1.6);

  // ── Corona rings (runic shockwaves travelling outward) ───────────────
  float ringPhase = fract(radius * 1.35 - uTime * 0.32);
  float rings = pow(smoothstep(0.92, 1.0, ringPhase), 3.0) * 0.85;
  energy += rings * smoothstep(0.62, 0.18, radius);

  // ── Color composition: deep abyss -> elemental -> white-hot core ─────
  vec3 deep = vec3(0.035, 0.012, 0.055);
  vec3 tint = clamp(uTint.rgb, 0.0, 1.0);
  vec3 hot = mix(tint, vec3(1.0, 0.94, 0.82), 0.55);

  vec3 color = deep;
  color = mix(color, tint * 0.95, clamp(energy * 0.85, 0.0, 1.0));
  color = mix(color, hot, clamp(heart * pulse * 1.25 + rings, 0.0, 1.0));
  color += vec3(0.05, 0.02, 0.09) * turb;

  // Vignette + intensity.
  float alpha = clamp(outer * (0.55 + energy * 0.75), 0.0, 1.0) * uTint.a;
  color *= 0.85 + 0.55 * outer;

  fragColor = vec4(color, alpha);
}
