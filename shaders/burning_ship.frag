#version 460 core

#include <flutter/runtime_effect.glsl>

uniform vec2 uSize;
uniform vec2 uCenter;
uniform float uZoom;
uniform float uTime;
uniform float uIterMax;
uniform vec3 uColor1;
uniform vec3 uColor2;
uniform vec3 uColor3;
uniform float uBreath;
uniform float uNeuro;

out vec4 fragColor;

vec3 palette(float t) {
  t = fract(t + uNeuro * 0.2);
  if (t < 0.33) return mix(uColor1, uColor2, t * 3.0);
  if (t < 0.66) return mix(uColor2, uColor3, (t - 0.33) * 3.0);
  return mix(uColor3, uColor1, (t - 0.66) * 3.0);
}

void main() {
  vec2 fragCoord = FlutterFragCoord().xy;
  vec2 uv = (fragCoord - uSize * 0.5) / min(uSize.x, uSize.y);

  vec2 c = uv / uZoom + uCenter;

  vec2 z = vec2(0.0);
  float i;
  float maxIter = uIterMax;

  for (i = 0.0; i < 256.0; i += 1.0) {
    if (i >= maxIter) break;
    if (dot(z, z) > 4.0) break;
    z = abs(z);
    z = vec2(z.x * z.x - z.y * z.y, 2.0 * z.x * z.y) + c;
  }

  if (i >= maxIter) {
    fragColor = vec4(vec3(uBreath * 0.03), 1.0);
  } else {
    float smoothI = i - log2(log2(dot(z, z))) + 4.0;
    float t = fract(smoothI / maxIter + uTime * 0.025);

    vec3 col = palette(t);
    col *= 1.0 + uBreath * 0.25 * sin(uTime * 3.0);

    fragColor = vec4(col, 1.0);
  }
}
