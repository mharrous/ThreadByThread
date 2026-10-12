shader_type spatial;
render_mode cull_back;

// Hilo enrollado en un carrete (eje local Y): vueltas helicoidales con relieve,
// fibra fina y, para los hilos metálicos, brillo de lámina.

uniform vec4 base_color : source_color = vec4(0.8, 0.2, 0.2, 1.0);
// Vueltas de hilo a lo alto del carrete.
uniform float windings = 42.0;
uniform float spool_height = 0.048;
uniform float metallic_sheen : hint_range(0.0, 1.0) = 0.0;
uniform float roughness_value : hint_range(0.0, 1.0) = 0.7;
uniform float bump_strength : hint_range(0.0, 1.0) = 0.6;

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

void fragment() {
	float ang = atan(local_pos.z, local_pos.x);
	float y = local_pos.y / spool_height + 0.5;
	// Vueltas helicoidales: una hebra que sube en espiral alrededor del carrete.
	float phase = (y * windings + ang * 0.16) * 6.28318;
	float strand = 0.5 + 0.5 * sin(phase);
	float fibre = fract(sin(dot(floor(vec2(ang * 40.0, y * windings * 4.0)), vec2(12.9898, 78.233))) * 43758.5453);
	float tint = 1.0 + (fract(variation) - 0.5) * 0.06;
	float shade = (mix(0.70, 1.10, strand) + (fibre - 0.5) * 0.06) * tint;

	// Relieve: el gradiente de las vueltas inclina la normal a lo largo del eje.
	vec3 ln = normalize(normalize(local_nrm) + vec3(0.0, cos(phase), 0.0) * bump_strength * 0.45);
	NORMAL = normalize(ln.x * to_view_x + ln.y * to_view_y + ln.z * to_view_z);

	ALBEDO = base_color.rgb * shade;
	METALLIC = metallic_sheen * (0.55 + 0.45 * strand);
	ROUGHNESS = mix(roughness_value, 0.28, metallic_sheen);
	SPECULAR = 0.15;
	RIM = 0.3 * (1.0 - metallic_sheen);
	RIM_TINT = 0.5;
	EMISSION = base_color.rgb * highlight * 0.32 + vec3(highlight * 0.06);
}
