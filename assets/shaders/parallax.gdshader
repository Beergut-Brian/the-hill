// Parallax that works in every view of a ScreenDirector (each split view borrows the same world,
// so a Parallax2D node cannot know which camera it is drawn for). Put this on a Sprite2D (region on,
// texture repeat on) or a Polygon2D placed in world space. Each view shifts the whole item toward
// its own camera: factor 1 = moves with the world, 0 = stuck to the screen.
// `anchor` is the local point where the item lines up with the world (usually the camera's rest
// point, e.g. the middle of the play area at ground level).
shader_type canvas_item;

uniform vec2 factor = vec2(0.5, 0.5);
uniform vec2 anchor = vec2(0.0, 0.0);

void vertex() {
	// The local position under the centre of this view.
	mat4 to_clip = SCREEN_MATRIX * CANVAS_MATRIX * MODEL_MATRIX;
	vec2 cam = (inverse(to_clip) * vec4(0.0, 0.0, 0.0, 1.0)).xy;
	VERTEX += (cam - anchor) * (vec2(1.0) - factor);
}
