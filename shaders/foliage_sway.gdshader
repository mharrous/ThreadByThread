shader_type spatial;
render_mode cull_back;

// Follaje de paisaje: color por instancia (MultiMesh) y balanceo suave con el viento.
// Sin sombras ni lógica: todo ocurre en la GPU.

uniform float sway : hint_range(0.0, 1.0) = 0.3;
uniform float roughness_value : hint_range(0.0, 1.0) = 0.9;

void vertex() {
	vec3 wp = MODEL_MATRIX[3].xyz;
	float t = TIME * 1.1 + wp.x * 0.35 + wp.z * 0.27;
	float h = max(VERTEX.y + 1.6, 0.0);
	VERTEX.x += sin(t) * 0.05 * sway * h;
	VERTEX.z += cos(t * 0.8) * 0.04 * sway * h;
}

void fragment() {
	ALBEDO = COLOR.rgb;
	ROUGHNESS = roughness_value;
}
