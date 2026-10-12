shader_type spatial;
render_mode cull_back;

// Lana procedural: hebras enrolladas cruzadas con relieve real (la normal se perturba
// con el gradiente de las hebras), fibra suave y borde esponjoso.
// Un único shader sirve para todos los colores y grosores (material compartido por tipo).

uniform vec4 base_color : source_color = vec4(0.84, 0.27, 0.24, 1.0);
uniform float thread_density = 26.0;
uniform float roughness_value : hint_range(0.0, 1.0) = 0.95;
uniform float bump_strength : hint_range(0.0, 1.0) = 0.5;
uniform float fuzz : hint_range(0.0, 1.0) = 0.6;

// Por instancia: no rompe el batching ni crea materiales nuevos.
instance uniform float highlight : hint_range(0.0, 1.0) = 0.0;
instance uniform float variation : hint_range(0.0, 100.0) = 0.0;

const vec3 AXIS_A = vec3(0.808, 0.505, 0.303);
const vec3 AXIS_B = vec3(-0.331, 0.745, 0.579);

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
	vec3 n = normalize(local_pos);
	float fa = dot(n, AXIS_A) * thread_density;
	float fb = dot(n, AXIS_B) * thread_density * 0.85;
	float strands = 0.5 + 0.5 * (sin(fa) * 0.6 + sin(fb) * 0.4);
	float fibre = fract(sin(dot(floor(n * thread_density * 3.0), vec3(12.9898, 78.233, 37.719))) * 43758.5453);
	float tint = 1.0 + (fract(variation) - 0.5) * 0.09;
	float shade = (mix(0.72, 1.1, strands) + (fibre - 0.5) * 0.07) * tint;

	// Relieve: el gradiente de las hebras inclina la normal en el espacio del modelo.
	vec3 g = AXIS_A * (cos(fa) * 0.6 * thread_density) + AXIS_B * (cos(fb) * 0.4 * thread_density * 0.85);
	vec3 g_tangent = g - n * dot(g, n);
	vec3 ln = normalize(normalize(local_nrm) - g_tangent * bump_strength * 0.022);
	NORMAL = normalize(ln.x * to_view_x + ln.y * to_view_y + ln.z * to_view_z);

	ALBEDO = base_color.rgb * shade;
	ROUGHNESS = roughness_value;
	SPECULAR = 0.12;
	RIM = 0.45 * fuzz;
	RIM_TINT = 0.65;
	EMISSION = base_color.rgb * highlight * 0.32 + vec3(highlight * 0.06);
}
