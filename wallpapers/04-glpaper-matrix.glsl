// Archived glpaper Matrix-rain experiment; not active.
// glpaper supplies these uniforms for each rendered frame.
#ifdef GL_ES
precision mediump float;
#endif

uniform vec2 resolution;
uniform float time;

float hash(float value) {
  return fract(sin(value * 91.3458) * 47453.5453);
}

float hash2(vec2 value) {
  return fract(sin(dot(value, vec2(127.1, 311.7))) * 43758.5453);
}

float glyph(vec2 uv, float seed) {
  vec2 dot = floor(uv * vec2(4.0, 7.0));
  float speck = step(0.56, hash2(dot + vec2(seed, seed * 0.37)));
  float stroke = step(0.82, hash2(vec2(seed * 0.19, dot.x + 9.0)));
  return max(speck, stroke);
}

void main(void) {
  const vec2 cell_size = vec2(14.0, 22.0);
  vec2 pixel = gl_FragCoord.xy;
  float column = floor(pixel.x / cell_size.x);
  float row = floor((resolution.y - pixel.y) / cell_size.y);
  float row_count = ceil(resolution.y / cell_size.y);
  float stream_seed = hash(column + 13.0);
  float speed = 5.5 + hash(column + 37.0) * 11.0;
  float trail_length = 10.0 + floor(hash(column + 71.0) * 22.0);
  float phase = hash(column + 19.0) * (row_count + trail_length);
  float head = mod(time * speed + phase, row_count + trail_length) - trail_length;
  float behind_head = head - row;
  float in_trail = step(0.0, behind_head) * step(behind_head, trail_length);
  float tail = in_trail * (1.0 - behind_head / trail_length);
  float active_column = step(0.18, stream_seed);
  float glyph_seed = floor(time * speed) + row * 17.0 + column * 31.0;
  float ink = glyph(fract(pixel / cell_size), glyph_seed);
  float flicker = 0.75 + 0.25 * hash2(vec2(column, floor(time * 12.0) + row));
  float head_glow = smoothstep(1.5, 0.0, behind_head);
  float intensity = active_column * tail * ink * flicker;
  vec3 background = vec3(0.002, 0.010, 0.004);
  vec3 tail_green = vec3(0.0, 0.88, 0.26) * intensity;
  vec3 bright_head = vec3(0.72, 1.0, 0.82) * head_glow * ink * active_column;
  float vignette = 1.0 - 0.38 * length(pixel / resolution - 0.5);
  gl_FragColor = vec4((background + tail_green + bright_head) * vignette, 1.0);
}

