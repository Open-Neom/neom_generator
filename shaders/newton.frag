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

vec2 cmul(vec2 a, vec2 b) {
  return vec2(a.x * b.x - a.y * b.y, a.x * b.y + a.y * b.x);
}

vec2 cdiv(vec2 a, vec2 b) {
  float d = dot(b, b);
  return vec2(a.x * b.x + a.y * b.y, a.y * b.x - a.x * b.y) / d;
}

void main() {
  vec2 fragCoord = FlutterFragCoord().xy;
  vec2 uv = (fragCoord - uSize * 0.5) / min(uSize.x, uSize.y);

  vec2 z = uv / uZoom + uCenter;

  vec2 root1 = vec2(1.0, 0.0);
  vec2 root2 = vec2(-0.5, 0.866025);
  vec2 root3 = vec2(-0.5, -0.866025);

  float i;
  float maxIter = uIterMax;
  int rootIndex = 0;
  float tolerance = 1e-4;

  for (i = 0.0; i < 128.0; i += 1.0) {
    if (i >= maxIter) break;

    vec2 z2 = cmul(z, z);
    vec2 z3 = cmul(z2, z);
    vec2 fz = z3 - vec2(1.0, 0.0);
    vec2 fpz = 3.0 * z2;

    if (dot(fpz, fpz) < 1e-10) break;
    z = z - cdiv(fz, fpz);

    if (distance(z, root1) < tolerance) { rootIndex = 1; break; }
    if (distance(z, root2) < tolerance) { rootIndex = 2; break; }
    if (distance(z, root3) < tolerance) { rootIndex = 3; break; }
  }

  float shade = 1.0 - i / maxIter;
  shade = pow(shade, 0.6);

  vec3 col;
  if (rootIndex == 1) col = uColor1 * shade;
  else if (rootIndex == 2) col = uColor2 * shade;
  else if (rootIndex == 3) col = uColor3 * shade;
  else col = vec3(0.0);

  col *= 1.0 + uBreath * 0.15 * sin(uTime * 1.2);
  col = mix(col, col.gbr, uNeuro * 0.1);

  fragColor = vec4(col, 1.0);
}
