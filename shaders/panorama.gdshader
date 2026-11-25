// Fondale vicino: il panorama equirettangolare su una sfera attorno all'arena, ingrandito.
// La città compare due volte nel giro (specchiata, senza giunture) e la fascia dell'orizzonte
// è allargata in verticale, così sembra più vicina e più grande.
shader_type spatial;
render_mode unshaded, cull_front, fog_disabled, depth_draw_never, shadows_disabled;

uniform sampler2D panorama : source_color, filter_linear_mipmap, repeat_disable;
uniform vec3 centro = vec3(0.0);
uniform float ripetizioni = 2.0;
uniform float zoom_verticale = 1.8;
uniform float orizzonte = 0.47;   // dove sta l'orizzonte nell'immagine (0 in alto, 1 in basso)
uniform float luce = 0.9;

varying vec3 pw;

void vertex() {
	pw = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 d = normalize(pw - centro);
	float lon = atan(d.x, -d.z) / (2.0 * PI) + 0.5;
	float m = mod(lon * ripetizioni, 2.0);
	float u = m < 1.0 ? m : 2.0 - m;
	float lat = acos(clamp(d.y, -1.0, 1.0)) / PI;          // 0 in alto, 0.5 all'orizzonte
	float v = orizzonte + (lat - 0.5) / zoom_verticale;
	ALBEDO = texture(panorama, vec2(u, clamp(v, 0.0, 1.0))).rgb * luce;
}
