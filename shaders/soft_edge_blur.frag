#version 320 es

// One pass of a separable Gaussian whose radius shrinks with the distance
// from a screen edge, so content blurs progressively as it slides under bars.
// Two passes (horizontal, then vertical) are composed by SoftScrollEdgeEffect.

precision highp float;

#include <flutter/runtime_effect.glsl>

// Set by the engine: size of the backdrop texture in physical pixels.
uniform vec2 u_size;
uniform sampler2D u_texture;

// (1, 0) for the horizontal pass, (0, 1) for the vertical pass.
uniform vec2 u_direction;
// Largest standard deviation, in physical pixels.
uniform float u_max_sigma;
// Distance from the edge that keeps the full blur, in physical pixels.
uniform float u_solid;
// Distance from the edge where the blur reaches zero, in physical pixels.
uniform float u_extent;
// 0 measures from the top edge, 1 from the bottom edge.
uniform float u_from_bottom;

out vec4 frag_color;

// The kernel always spans three standard deviations, so the weights are
// constant and only the tap spacing follows the local radius.
const int kTaps = 16;

void main() {
  vec2 coord = FlutterFragCoord().xy;
  vec2 uv = coord / u_size;
  float y = coord.y;
#ifdef IMPELLER_TARGET_OPENGLES
  uv.y = 1.0 - uv.y;
  y = u_size.y - y;
#endif
  float distance = mix(y, u_size.y - y, u_from_bottom);
  float t = clamp((distance - u_solid) / max(u_extent - u_solid, 1.0), 0.0, 1.0);
  float sigma = u_max_sigma * (1.0 - t * t * (3.0 - 2.0 * t));
  if (sigma < 0.35) {
    frag_color = texture(u_texture, uv);
    return;
  }
  vec2 step_uv = u_direction * (sigma * 3.0 / float(kTaps)) / u_size;
  vec4 sum = vec4(0.0);
  float total = 0.0;
  for (int i = -kTaps; i <= kTaps; i++) {
    float x = float(i) * 3.0 / float(kTaps);
    float weight = exp(-0.5 * x * x);
    sum += texture(u_texture, uv + step_uv * float(i)) * weight;
    total += weight;
  }
  frag_color = sum / total;
}
