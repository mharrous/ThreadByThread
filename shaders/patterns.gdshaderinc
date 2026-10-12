// Dibujos procedurales de telas y cintas (compartidos por fabric.gdshader y ribbon.gdshader).
// q = coordenadas del dibujo (1 unidad = una celda). Devuelve el color; `coverage` < 0.5
// marca huecos (encaje) que el shader puede recortar.

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

vec3 pattern_color(int pattern, vec2 q, vec3 a, vec3 b, vec3 c, out float coverage) {
	coverage = 1.0;
	vec3 col = a;
	if (pattern == 1) {                       // rayas
		float s = step(0.5, fract(q.x * 0.5));
		col = mix(a, b, s);
	} else if (pattern == 2) {                // vichy
		float sx = step(0.5, fract(q.x * 0.5));
		float sy = step(0.5, fract(q.y * 0.5));
		float n = sx + sy;
		col = n > 1.5 ? c : (n > 0.5 ? b : a);
	} else if (pattern == 3) {                // lunares
		vec2 g = q * 0.5;
		g.x += step(1.0, mod(g.y, 2.0)) * 0.5;   // filas desplazadas
		vec2 f = fract(g) - 0.5;
		col = mix(a, b, smoothstep(0.30, 0.25, length(f)));
	} else if (pattern == 4) {                // flores
		vec2 g = q * 0.5;
		vec2 id = floor(g);
		vec2 f = fract(g) - 0.5;
		float ang = atan(f.y, f.x) + hash21(id) * 6.28;
		float r = length(f);
		float petal = 0.17 + 0.11 * cos(5.0 * ang);
		float flower = smoothstep(petal + 0.02, petal - 0.01, r);
		float centre = smoothstep(0.075, 0.055, r);
		col = mix(a, b, flower);
		col = mix(col, c, centre);
	} else if (pattern == 5) {                // tartán
		float u = fract(q.x * 0.25);
		float v = fract(q.y * 0.25);
		float su = step(0.20, u) * step(u, 0.46);
		float sv = step(0.20, v) * step(v, 0.46);
		float lu = step(0.62, u) * step(u, 0.68);
		float lv = step(0.62, v) * step(v, 0.68);
		col = mix(a, b, max(su, sv));
		col = mix(col, c, max(lu, lv));
		col = mix(col, col * 0.7, su * sv);
	} else if (pattern == 6) {                // vaquero (sarga diagonal)
		float t = fract((q.x + q.y) * 3.0);
		col = mix(a, b, 0.35 * step(0.5, t));
	} else if (pattern == 7) {                // terciopelo
		col = a;
	} else if (pattern == 8) {                // pana
		float rib = 0.5 + 0.5 * sin(q.x * 18.0);
		col = mix(a * 0.78, a * 1.08, rib);
	} else if (pattern == 9) {                // encaje (con huecos)
		vec2 g = q * 0.5;
		vec2 f = fract(g) - 0.5;
		float ang = atan(f.y, f.x);
		float r = length(f);
		float petal = 0.30 + 0.10 * cos(6.0 * ang);
		float ring = smoothstep(petal + 0.03, petal, r) - smoothstep(petal - 0.10, petal - 0.13, r);
		float dot_ = smoothstep(0.09, 0.06, r);
		float web = max(ring, dot_);
		float edge = smoothstep(0.88, 0.92, fract(q.y * 0.25 + 0.0)) ;
		coverage = clamp(max(web, edge), 0.0, 1.0);
		col = a;
	}
	return col;
}
