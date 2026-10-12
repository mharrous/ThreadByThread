shader_type spatial;
render_mode cull_back;

// Ovillo de lana procedural: hebras enrolladas cruzadas, fibra suave y borde cálido.
// Un único shader sirve para todos los colores (material compartido por tipo).

uniform vec4 base_color : source_color = vec4(0.84, 0.27, 0.24, 1.0);
uniform float thread_density = 26.0;
uniform float roughness_value : hint_range(0.0, 1.0) = 0.95;

// Por instancia: no rompe el batching ni crea materiales nuevos.
instance uniform float highlight : hint_range(0.0, 1.0) = 0.0;
instance uniform float variation : hint_range(0.0, 100.0) = 0.0;

varying vec3 local_pos;

void vertex() {
	local_pos = VERTEX;
}

void fragment() {
	vec3 n = normalize(local_pos);
	vec3 axis_a = normalize(vec3(0.8 + sin(variation), 0.5, 0.3));
	vec3 axis_b = normalize(vec3(-0.4, 0.9, 0.7 + cos(variation)));
	float wind_a = sin(dot(n, axis_a) * thread_density + variation);
	float wind_b = sin(dot(n, axis_b) * thread_density * 0.85 + variation * 1.7);
	float strands = 0.5 + 0.5 * (wind_a * 0.6 + wind_b * 0.4);
	float fibre = fract(sin(dot(floor(n * thread_density * 3.0), vec3(12.9898, 78.233, 37.719))) * 43758.5453);
	float shade = mix(0.74, 1.08, strands) + (fibre - 0.5) * 0.07;

	ALBEDO = base_color.rgb * shade;
	ROUGHNESS = roughness_value;
	SPECULAR = 0.15;
	RIM = 0.35;
	RIM_TINT = 0.6;
	EMISSION = base_color.rgb * highlight * 0.32 + vec3(highlight * 0.06);
}
