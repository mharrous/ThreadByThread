shader_type spatial;
render_mode cull_disabled;

// Cinta enrollada en un carrete (eje local Y): satén con brillo, orillos y dibujos
// (liso, raya central, vichy, lunares, flores, encaje). Mismo sistema de dibujos que la tela.

#include "res://shaders/patterns.gdshaderinc"

uniform vec4 color_a : source_color = vec4(0.8, 0.15, 0.2, 1.0);
uniform vec4 color_b : source_color = vec4(1.0, 0.9, 0.7, 1.0);
uniform vec4 color_c : source_color = vec4(0.5, 0.1, 0.1, 1.0);
uniform int pattern = 0;
uniform float pattern_scale = 1.0;
uniform float metallic_sheen : hint_range(0.0, 1.0) = 0.0;
uniform float roughness_value : hint_range(0.0, 1.0) = 0.32;
// Alto de la cinta (para dibujar los orillos).
uniform float ribbon_height = 0.024;

instance uniform float highlight : hint_range(0.0, 1.0) = 0.0;
instance uniform float variation : hint_range(0.0, 100.0) = 0.0;

varying vec3 local_pos;

void vertex() {
	local_pos = VERTEX;
}

void fragment() {
	float ang = atan(local_pos.z, local_pos.x);
	// Coordenadas: x = a lo largo de la cinta (alrededor), y = a lo ancho.
	vec2 p = vec2(ang * 0.031, local_pos.y);
	vec2 q = p / (0.02 / pattern_scale);
	float coverage;
	vec3 col;
	if (pattern == 1) {                      // raya central
		float across = abs(local_pos.y) / (ribbon_height * 0.5);
		col = mix(color_b.rgb, color_a.rgb, smoothstep(0.35, 0.40, across));
	} else {
		col = pattern_color(pattern, q, color_a.rgb, color_b.rgb, color_c.rgb, coverage);
	}
	// Orillos: línea fina más clara en los bordes de la cinta.
	float edge = abs(local_pos.y) / (ribbon_height * 0.5);
	col = mix(col, col * 1.25, smoothstep(0.82, 0.9, edge) * 0.6);
	// Estrías muy finas del tejido de satén (en la dirección de la cinta).
	float fine = 0.5 + 0.5 * sin(local_pos.y * 2400.0);
	col *= 0.95 + 0.05 * fine;
	col *= 1.0 + (fract(variation) - 0.5) * 0.05;

	ALBEDO = col;
	ROUGHNESS = roughness_value;
	METALLIC = metallic_sheen;
	SPECULAR = 0.6;
	RIM = 0.4;
	RIM_TINT = 0.5;
	if (pattern == 9) {
		ALPHA = coverage;
		ALPHA_SCISSOR_THRESHOLD = 0.5;
	}
	EMISSION = col * highlight * 0.3 + vec3(highlight * 0.05);
}
