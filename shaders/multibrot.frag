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
uniform float uPower;

out vec4 fragColor;

vec3 palette(float t) {
  t = fract(t + uNeuro * 0.12);
  vec3 a = uColor1 * 0.5 + 0.5;
  vec3 b = uColor2 * 0.5 + 0.5;
  vec3 c = uColor3 * 0.5 + 0.5;
  float s = t * 3.0;
  if (s < 1.0) return mix(a, b, s);
  if (s < 2.0) return mix(b, c, s - 1.0);
  return mix(c, a, s - 2.0);
}

void main() {
  vec2 fragCoord = FlutterFragCoord().xy;
  vec2 uv = (fragCoord - uSize * 0.5) / min(uSize.x, uSize.y);

  vec2 c = uv / uZoom + uCenter;

  vec2 z = vec2(0.0);
  float i;
  float maxIter = uIterMax;
  float power = uPower;

  for (i = 0.0; i < 256.0; i += 1.0) {
    if (i >= maxIter) break;
    float r = length(z);
    if (r > 4.0) break;

    float theta = atan(z.y, z.x);
    float rn = pow(r, power);
    float tn = theta * power;

    z = vec2(rn * cos(tn), rn * sin(tn)) + c;
  }

  if (i >= maxIter) {
    float pulse = uBreath * 0.04;
    fragColor = vec4(vec3(pulse), 1.0);
  } else {
    float smoothI = i - log2(log2(dot(z, z))) + 4.0;
    float t = fract(smoothI / maxIter + uTime * 0.018);

    vec3 col = palette(t);
    col *= 1.0 + uBreath * 0.18 * sin(uTime * 1.8);

    fragColor = vec4(col, 1.0);
  }
}
