#version 460 core
#include <flutter/runtime_effect.glsl>

// Arcane Beam — plasma lightning for predictive aim, break chains and awakened
// summon discharges.
//
// Local space: the painter draws a rect of `uSize` and rotates it onto the
// start→end vector, so the beam always travels along +X here.
uniform vec2 uSize;
uniform float uTime;
uniform float uProgress;
uniform vec4 uColor;

out vec4 fragColor;

void main() {
  vec2 frag = FlutterFragCoord().xy;
  vec2 uv = frag / max(uSize, vec2(1.0, 1.0));
  float x = clamp(uv.x, 0.0, 1.0);
  float y = uv.y * 2.0 - 1.0;

  // Ignition: the head races from the caster (0) to the target (1).
  float reach = smoothstep(uProgress + 0.02, uProgress - 0.10, x);
  float head = exp(-pow((x - uProgress) * 26.0, 2.0));

  // High-frequency electrical wobble around the centreline.
  float wobble = sin(x * 42.0 + uTime * 19.0) * 0.085
      + sin(x * 97.0 - uTime * 31.0) * 0.035
      + sin(x * 173.0 + uTime * 57.0) * 0.014;

  float dist = abs(y - wobble);
  float core = exp(-pow(dist * 27.0, 2.0));
  float halo = exp(-pow(dist * 6.0, 2.0));

  // Sporadic filaments crawling along the discharge.
  float crawl = sin(x * 118.0 + uTime * 44.0) * 0.5 + 0.5;
  float filaments = pow(crawl, 7.0);

  vec3 base = uColor.rgb;
  vec3 incandescent = mix(base, vec3(1.0), 0.88);
  vec3 color = base * halo * 0.62
      + incandescent * core
      + base * filaments * 0.30
      + vec3(1.0) * head * 0.85;

  float alpha = clamp((core + halo * 0.72 + head) * reach, 0.0, 1.0);
  float edgeFade = smoothstep(1.0, 0.90, x) * smoothstep(0.0, 0.02, x);
  fragColor = vec4(color * reach * edgeFade, alpha * edgeFade * 0.96);
}
