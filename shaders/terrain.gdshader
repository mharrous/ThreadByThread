shader_type spatial;
render_mode cull_disabled;

// Terreno del paisaje: el color base (pradera, orilla, roca, nieve y bruma de distancia) viene
// de los colores de vértice; de cerca se le suma el detalle de la textura de hierba y su relieve.
// El detalle se desvanece con la distancia para que las colinas lejanas se fundan con el cielo.

uniform sampler2D detail_tex : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D detail_nrm : hint_normal, repeat_enable, filter_linear_mipmap_anisotropic;
uniform float tex_scale = 0.3;
uniform float fade_start = 16.0;
uniform float fade_end = 85.0;
uniform float normal_strength = 0.9;

varying vec3 world_pos;

vec3 srgb_to_linear(vec3 c) {
	return mix(pow((c + 0.055) / 1.055, vec3(2.4)), c / 12.92, vec3(lessThan(c, vec3(0.04045))));
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 uv = world_pos.xz * tex_scale;
	vec3 mean_c = max(textureLod(detail_tex, vec2(0.5), 12.0).rgb, vec3(0.05));
	// Dos escalas mezcladas para que la repetición no se note.
	vec3 t = texture(detail_tex, uv).rgb * 0.6 + texture(detail_tex, uv * 0.23 + vec2(0.37, 0.61)).rgb * 0.4;
	float f = smoothstep(fade_start, fade_end, length(VERTEX));
	vec3 detail = mix(mix(vec3(1.0), clamp(t / mean_c, vec3(0.5), vec3(1.6)), 0.55), vec3(1.0), f);
	ALBEDO = srgb_to_linear(COLOR.rgb) * detail;   // los colores de vértice se escriben en sRGB
	ROUGHNESS = 1.0;

	// Relieve: la malla no tiene tangentes, así que se proyecta desde arriba (T = +X del mundo).
	vec3 nt = texture(detail_nrm, uv).xyz * 2.0 - 1.0;
	nt.xy *= normal_strength * (1.0 - f);
	vec3 n = normalize(NORMAL);
	vec3 tan = normalize((VIEW_MATRIX * vec4(1.0, 0.0, 0.0, 0.0)).xyz);
	tan = normalize(tan - dot(tan, n) * n);
	vec3 bit = cross(n, tan);
	NORMAL = normalize(tan * nt.x + bit * nt.y + n * max(nt.z, 0.2));
}
