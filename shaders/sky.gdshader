shader_type sky;

// Cielo de día tranquilo: degradado, disco solar con halo y nubes que se desplazan despacio.
// Las nubes son ruido fractal proyectado sobre un plano alto, sombreado con la dirección del sol.

uniform vec3 sun_dir = vec3(-0.8, 0.53, -0.29);   // hacia el sol (no la dirección de la luz)
uniform vec3 top_color : source_color = vec3(0.26, 0.52, 0.86);
uniform vec3 horizon_color : source_color = vec3(0.78, 0.89, 0.96);
uniform vec3 ground_color : source_color = vec3(0.60, 0.74, 0.48);
uniform float cloud_cover : hint_range(0.0, 1.0) = 0.5;
uniform float cloud_speed = 0.006;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(i), hash21(i + vec2(1.0, 0.0)), f.x),
			mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0, 1.0)), f.x), f.y);
}

float fbm(vec2 p) {
	float a = 0.5;
	float s = 0.0;
	for (int i = 0; i < 5; i++) {
		s += a * value_noise(p);
		p = p * 2.03 + vec2(1.7, 9.2);
		a *= 0.5;
	}
	return s;
}

void sky() {
	vec3 d = normalize(EYEDIR);
	vec3 sun = normalize(sun_dir);
	float h = d.y;

	vec3 col = mix(horizon_color, top_color, pow(clamp(h, 0.0, 1.0), 0.5));
	col = mix(col, ground_color, smoothstep(0.0, -0.12, h));

	float sd = max(dot(d, sun), 0.0);
	col += vec3(1.0, 0.86, 0.62) * (pow(sd, 900.0) * 9.0 + pow(sd, 24.0) * 0.16);

	if (h > 0.0) {
		vec2 uv = d.xz / (h + 0.2) * 1.5 + vec2(TIME * cloud_speed, TIME * cloud_speed * 0.35);
		float n = fbm(uv);
		float density = smoothstep(1.0 - cloud_cover, 1.0 - cloud_cover + 0.3, n);
		// Sombreado: se compara la densidad con la de un punto desplazado hacia el sol.
		float toward_sun = fbm(uv + sun.xz * 0.1);
		float lit = clamp(0.62 + (toward_sun - n) * 3.2, 0.0, 1.0);
		vec3 cloud_col = mix(vec3(0.60, 0.67, 0.78), vec3(1.0, 0.99, 0.96), lit);
		density *= smoothstep(0.0, 0.14, h);
		col = mix(col, cloud_col, density * 0.93);
	}
	COLOR = col;
}
