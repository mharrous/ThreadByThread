shader_type spatial;
render_mode cull_disabled;

// Tela procedural: 10 dibujos (liso, rayas, vichy, lunares, flores, tartán, vaquero,
// terciopelo, pana, encaje), trama tejida con relieve y brillo de tejido en el borde.
// El dibujo se calcula en espacio del modelo, así un único shader sirve para cualquier tela.

#include "res://shaders/patterns.gdshaderinc"

uniform vec4 color_a : source_color = vec4(0.9, 0.85, 0.75, 1.0);
uniform vec4 color_b : source_color = vec4(0.8, 0.3, 0.3, 1.0);
uniform vec4 color_c : source_color = vec4(0.6, 0.15, 0.15, 1.0);
uniform int pattern = 0;
uniform float pattern_scale = 1.0;
// 0 = plano en XZ (telas dobladas), 1 = cilíndrico alrededor de Z (rollos), 2 = plano en XY.
uniform int mapping = 0;
uniform float roughness_value : hint_range(0.0, 1.0) = 0.92;
uniform float sheen : hint_range(0.0, 1.0) = 0.5;
uniform float bump_strength : hint_range(0.0, 1.0) = 0.5;

instance uniform float highlight : hint_range(0.0, 1.0) = 0.0;
instance uniform float variation : hint_range(0.0, 100.0) = 0.0;

varying vec3 local_pos;
varying vec3 local_nrm;
varying vec3 to_view_x;
varying vec3 to_view_y;
varying vec3 to_view_z;

void vertex() {
	local_pos = VERTEX;
	local_nrm = NORMAL;
	to_view_x = MODELVIEW_NORMAL_MATRIX * vec3(1.0, 0.0, 0.0);
	to_view_y = MODELVIEW_NORMAL_MATRIX * vec3(0.0, 1.0, 0.0);
	to_view_z = MODELVIEW_NORMAL_MATRIX * vec3(0.0, 0.0, 1.0);
}

vec2 pattern_space(vec3 p) {
	if (mapping == 1) {
		return vec2(atan(p.y, p.x) * 0.055, p.z);
	} else if (mapping == 2) {
		return p.xy;
	}
	return p.xz;
}

void fragment() {
	vec2 p = pattern_space(local_pos);
	vec2 q = p / (0.04 / pattern_scale);
	float coverage;
	vec3 col = pattern_color(pattern, q, color_a.rgb, color_b.rgb, color_c.rgb, coverage);

	// Trama: hilos cruzados.
	float w = 900.0;
	float weave_x = sin(p.x * w);
	float weave_y = sin(p.y * w);
	float weave = 0.5 + 0.25 * weave_x * weave_y + 0.25 * (weave_x + weave_y) * 0.5;
	float tint = 1.0 + (fract(variation) - 0.5) * 0.06;
	col *= (0.92 + 0.12 * weave) * tint;

	// Relieve de la trama (en espacio del modelo).
	vec3 g;
	if (mapping == 1) {
		vec3 tangent = normalize(vec3(-local_pos.y, local_pos.x, 0.0) + vec3(0.0001));
		g = tangent * cos(p.x * w) * weave_y + vec3(0.0, 0.0, 1.0) * cos(p.y * w) * weave_x;
	} else if (mapping == 2) {
		g = vec3(cos(p.x * w) * weave_y, cos(p.y * w) * weave_x, 0.0);
	} else {
		g = vec3(cos(p.x * w) * weave_y, 0.0, cos(p.y * w) * weave_x);
	}
	vec3 ln = normalize(normalize(local_nrm) - g * bump_strength * 0.05);
	NORMAL = normalize(ln.x * to_view_x + ln.y * to_view_y + ln.z * to_view_z);

	ALBEDO = col;
	ROUGHNESS = roughness_value;
	SPECULAR = 0.2;
	RIM = sheen * (pattern == 7 ? 1.0 : 0.45);
	RIM_TINT = 0.7;
	if (pattern == 9) {
		ALPHA = coverage;
		ALPHA_SCISSOR_THRESHOLD = 0.5;
	}
	EMISSION = col * highlight * 0.3 + vec3(highlight * 0.05);
}
