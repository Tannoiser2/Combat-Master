// Acqua della fontana: increspature che si muovono, riflesso morbido e trasparenza leggera.
shader_type spatial;
render_mode blend_mix, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec4 colore : source_color = vec4(0.20, 0.42, 0.50, 0.85);
uniform float velocita = 0.6;

varying vec3 pw;

void vertex() {
	pw = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 q = pw.xz * 4.0;
	float t = TIME * velocita;
	float o1 = sin(q.x * 1.7 + t * 2.0) * cos(q.y * 1.3 - t * 1.6);
	float o2 = sin((q.x + q.y) * 2.3 - t * 2.4);
	float o = (o1 + o2) * 0.5;
	ALBEDO = colore.rgb * (0.85 + 0.15 * o);
	ALPHA = colore.a;
	ROUGHNESS = 0.08;
	METALLIC = 0.0;
	SPECULAR = 0.7;
	NORMAL_MAP = normalize(vec3(0.5 + 0.25 * cos(q.x * 1.7 + t * 2.0), 0.5 + 0.25 * sin(q.y * 1.3 - t * 1.6), 1.0)) * 0.5 + 0.5;
	NORMAL_MAP_DEPTH = 1.0;
}
