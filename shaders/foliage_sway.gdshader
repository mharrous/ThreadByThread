shader_type spatial;
render_mode cull_back;

// Follaje de paisaje: color por instancia (MultiMesh), balanceo suave con el viento y un poco de
// variación de tono a pequeña escala para que las copas no parezcan globos lisos.
// Sin sombras ni lógica: todo ocurre en la GPU.

uniform float sway : hint_range(0.0, 1.0) = 0.3;
uniform float roughness_value : hint_range(0.0, 1.0) = 0.9;
uniform float variation : hint_range(0.0, 1.0) = 0.35;

varying vec3 world_pos;
varying vec3 world_normal;

float hash31(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.zyx + 31.32);
	return fract((p.x + p.y) * p.z);
}

float value_noise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(mix(hash31(i), hash31(i + vec3(1, 0, 0)), f.x), mix(hash31(i + vec3(0, 1, 0)), hash31(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(hash31(i + vec3(0, 0, 1)), hash31(i + vec3(1, 0, 1)), f.x), mix(hash31(i + vec3(0, 1, 1)), hash31(i + vec3(1, 1, 1)), f.x), f.y),
		f.z);
}

vec3 srgb_to_linear(vec3 c) {
	return mix(pow((c + 0.055) / 1.055, vec3(2.4)), c / 12.92, vec3(lessThan(c, vec3(0.04045))));
}

void vertex() {
	vec3 wp = MODEL_MATRIX[3].xyz;
	float t = TIME * 1.1 + wp.x * 0.35 + wp.z * 0.27;
	float h = max(VERTEX.y + 1.6, 0.0);
	VERTEX.x += sin(t) * 0.05 * sway * h;
	VERTEX.z += cos(t * 0.8) * 0.04 * sway * h;
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	// Dos escalas de ruido: manchas grandes de luz y sombra y grano de hojas.
	float n = value_noise(world_pos * 1.6) * 0.65 + value_noise(world_pos * 6.5) * 0.35;
	float tone = mix(1.0, 0.7 + n * 0.6, variation);
	// Lo de arriba recibe más luz del cielo; lo de abajo queda más oscuro.
	float sky = 0.8 + 0.28 * clamp(world_normal.y * 0.5 + 0.5, 0.0, 1.0);
	ALBEDO = srgb_to_linear(COLOR.rgb) * tone * sky;   // los colores de instancia se escriben en sRGB
	ROUGHNESS = roughness_value;
}
