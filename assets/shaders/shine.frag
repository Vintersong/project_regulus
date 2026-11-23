#version 460 core

#include <flutter/runtime_effect.glsl>

// Golden-card foil over the revealed plate.
//
// Fills whatever it is drawn onto with a procedural stand-in plate (engraved
// rings, rays and hatching) and a holographic sheen. The caller draws it only
// over captured ground, by filling a path of the claimed cells, so the shader
// needs no mask. That is deliberate: on Windows (Impeller/OpenGL) a shader
// with a texture sampler can fail to link and blank the whole window
// (flutter/flutter#190809). The sheen is anchored to uLight, so it slides as
// the player moves, like tilting a card.

uniform vec2 uSize;       // playfield size in logical px
uniform float uTime;      // seconds
uniform vec2 uLight;      // light position, 0..1 across the field
uniform vec2 uOrigin;     // where the playfield starts in shader space
uniform float uScale;     // shader-space px per logical px (1 if local space)
uniform vec3 uPlate;      // the layer's metal colour
uniform vec3 uInk;        // the layer's engraving colour

out vec4 fragColor;

float hash21(vec2 p) {
  p = fract(p * vec2(123.34, 456.21));
  p += dot(p, p + 45.32);
  return fract(p.x * p.y);
}

void main() {
  vec2 px = (FlutterFragCoord().xy - uOrigin) / uScale;
  vec2 uv = px / uSize;

  // --- stand-in plate: engraved line work --------------------------------
  vec2 p = (uv - 0.5) * vec2(uSize.x / uSize.y, 1.0);
  float r = length(p);
  float ang = atan(p.y, p.x);

  float rings = abs(fract(r * 16.0) - 0.5);
  float ringLine = 1.0 - smoothstep(0.03, 0.09, rings);

  float rays = abs(fract(ang * 12.0 / 6.28318) - 0.5);
  float rayLine = (1.0 - smoothstep(0.02, 0.06, rays)) * smoothstep(0.1, 0.3, r);

  float hatch = abs(fract((uv.x + uv.y) * 90.0) - 0.5);
  float hatchLine = (1.0 - smoothstep(0.1, 0.25, hatch)) * 0.35;

  float line = clamp(ringLine * 0.9 + rayLine * 0.6 + hatchLine, 0.0, 1.0);
  vec3 base = uPlate;
  vec3 ink = uInk;
  vec3 col = mix(base, ink, line * 0.55);

  // --- foil sheen ---------------------------------------------------------
  // Distance along a diagonal from the light, and a slow ambient sweep.
  float d = dot(uv - uLight, normalize(vec2(1.0, 0.6)));
  float band = exp(-pow(d * 5.0, 2.0));
  float sweep = exp(-pow((fract(uv.x * 0.6 + uv.y * 0.4 - uTime * 0.12) - 0.5) * 5.0, 2.0));
  float sheen = band * 0.6 + sweep * 0.35;

  // Rainbow shift across the band, blended toward gold.
  vec3 irid = 0.5 + 0.5 * cos(6.28318 * (vec3(0.0, 0.33, 0.67) + d * 2.0 + uTime * 0.1));
  vec3 gold = vec3(1.0, 0.82, 0.42);
  // Strongest on the engraved lines, so the foil seems to sit in the metal.
  col += mix(gold, irid, 0.45) * sheen * (0.3 + 0.7 * line);

  // --- sparkles -----------------------------------------------------------
  float h = hash21(floor(px / 6.0));
  float twinkle = step(0.985, h) * (0.5 + 0.5 * sin(uTime * 5.0 + h * 40.0));
  col += vec3(1.0, 0.95, 0.8) * twinkle * (0.4 + sheen);

  fragColor = vec4(col, 1.0);
}
