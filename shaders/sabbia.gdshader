// Esagoni di pietra coperti di sabbia: rumore in coordinate del mondo (le tessere non si ripetono),
// increspature del vento e piccole luccicanze. Funziona anche nel renderer di compatibilità (web).
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform vec4 colore_pietra : source_color = vec4(0.55, 0.49, 0.40, 1.0);
uniform vec4 colore_sabbia : source_color = vec4(0.74, 0.62, 0.43, 1.0);
uniform float quanta_sabbia : hint_range(0.0, 1.0) = 0.45;
uniform float increspature : hint_range(0.0, 1.0) = 0.35;
uniform float tinta : hint_range(-1.0, 1.0) = 0.0;

varying vec3 pw;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}
float fbm(vec2 p) {
	float v = 0.0, a = 0.5;
	for (int k = 0; k < 4; k++) { v += a * noise(p); p *= 2.07; a *= 0.5; }
	return v;
}

void vertex() {
	pw = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 q = pw.xz;
	float macchie = fbm(q * 0.6);
	float sabbia = smoothstep(1.0 - quanta_sabbia - 0.15, 1.0 - quanta_sabbia + 0.15, macchie + (NORMAL.y > 0.8 ? 0.0 : -0.4));
	// increspature del vento, ondulate dal rumore
	float onde = sin(q.x * 7.0 + q.y * 2.5 + fbm(q * 1.3) * 6.0) * 0.5 + 0.5;
	float grana = noise(q * 40.0);
	vec3 pietra = colore_pietra.rgb * (0.8 + 0.35 * fbm(q * 3.0)) * (1.0 + tinta * 0.12);
	vec3 sab = colore_sabbia.rgb * (0.9 + 0.12 * onde * increspature + 0.08 * grana);
	ALBEDO = mix(pietra, sab, sabbia);
	ROUGHNESS = mix(0.95, 0.85, sabbia);
	SPECULAR = 0.25;
	// rilievo: le increspature e la grana piegano un poco la normale
	float dx = sin((q.x + 0.02) * 7.0 + q.y * 2.5) - sin(q.x * 7.0 + q.y * 2.5);
	NORMAL_MAP = normalize(vec3(0.5 - dx * increspature * sabbia * 2.0, 0.5 + (grana - 0.5) * 0.15, 1.0)) * 0.5 + 0.5;
	NORMAL_MAP_DEPTH = 0.6;
}
