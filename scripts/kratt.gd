extends Control
## Placeholder kratt: a hay body with an iron pot for a head, drawn with simple shapes.
## The day scene sets mode, burning, working and progress every frame.

const INK := Color(0.08, 0.07, 0.06)
const PAPER := Color(0.945, 0.925, 0.875)
const ORANGE := Color(0.91, 0.35, 0.05)
const HAY := Color(0.86, 0.80, 0.62)

var mode := "normal"      # "normal" or "scarecrow"
var burning := false      # idle: eyes glow and it twitches while the fuse burns
var working := false
var progress := -1.0      # job progress 0..1, or -1 to hide the bar
var _t := 0.0

@onready var tag: Label = $Tag


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func set_tag(text: String) -> void:
	if tag.text != text:
		tag.text = text


func _draw() -> void:
	var w := size.x
	var h := size.y
	var cx := w * 0.5
	var shake := Vector2.ZERO
	if burning:
		shake = Vector2(sin(_t * 47.0) * 1.5, cos(_t * 31.0))
	elif working:
		shake = Vector2(0.0, -absf(sin(_t * 9.0)) * 3.0)
	# shadow
	draw_set_transform(Vector2(cx, h - 3.0), 0.0, Vector2(1.0, 0.25))
	draw_circle(Vector2.ZERO, w * 0.42, Color(0, 0, 0, 0.18))
	draw_set_transform(shake, 0.0, Vector2.ONE)
	if mode == "scarecrow":
		draw_line(Vector2(cx, h * 0.25), Vector2(cx, h), INK, 4.0)
		draw_line(Vector2(cx - w * 0.55, h * 0.44), Vector2(cx + w * 0.55, h * 0.44), INK, 4.0)
	else:
		draw_line(Vector2(cx - 8, h * 0.82), Vector2(cx - 12, h - 2), INK, 4.0)
		draw_line(Vector2(cx + 8, h * 0.82), Vector2(cx + 12, h - 2), INK, 4.0)
		var swing := sin(_t * 9.0) * 8.0 if working else 0.0
		draw_line(Vector2(cx - 14, h * 0.45), Vector2(cx - 27, h * 0.62 - swing), INK, 3.0)
		draw_line(Vector2(cx + 14, h * 0.45), Vector2(cx + 27, h * 0.62 + swing), INK, 3.0)
	# hay body
	var body := PackedVector2Array([
		Vector2(cx - 12, h * 0.84), Vector2(cx - 20, h * 0.66), Vector2(cx - 21, h * 0.46),
		Vector2(cx - 14, h * 0.32), Vector2(cx + 14, h * 0.32), Vector2(cx + 21, h * 0.46),
		Vector2(cx + 20, h * 0.66), Vector2(cx + 12, h * 0.84)])
	draw_colored_polygon(body, HAY)
	var outline := body.duplicate()
	outline.append(body[0])
	draw_polyline(outline, INK, 2.0)
	for i in range(7):
		var x := cx - 15.0 + i * 5.0
		draw_line(Vector2(x, h * 0.38), Vector2(x + (i % 3) - 1.0, h * 0.8), Color(INK, 0.5), 1.0)
	draw_line(Vector2(cx - 20, h * 0.58), Vector2(cx + 20, h * 0.58), INK, 3.0)
	# iron pot head
	var head_y := h * 0.30
	var dome := PackedVector2Array()
	for i in range(13):
		var a := PI + PI * i / 12.0
		dome.append(Vector2(cx + cos(a) * 16.0, head_y + sin(a) * 18.0))
	draw_colored_polygon(dome, INK)
	draw_line(Vector2(cx - 19, head_y), Vector2(cx + 19, head_y), INK, 4.0)
	var hot := burning or mode == "scarecrow"
	if hot:
		draw_circle(Vector2(cx - 6, head_y - 7), 7.0, Color(ORANGE, 0.3))
		draw_circle(Vector2(cx + 6, head_y - 7), 7.0, Color(ORANGE, 0.3))
	var eye := ORANGE if hot else PAPER
	draw_circle(Vector2(cx - 6, head_y - 7), 2.6, eye)
	draw_circle(Vector2(cx + 6, head_y - 7), 2.6, eye)
	if mode == "scarecrow":
		draw_rect(Rect2(cx - 12, head_y - 30, 24, 12), INK)
		draw_line(Vector2(cx - 24, head_y - 18), Vector2(cx + 24, head_y - 18), INK, 4.0)
	# job progress bar above the head
	if progress >= 0.0:
		draw_rect(Rect2(cx - 26, -10, 52, 7), PAPER)
		draw_rect(Rect2(cx - 26, -10, 52.0 * clampf(progress, 0.0, 1.0), 7), INK)
		draw_rect(Rect2(cx - 26, -10, 52, 7), INK, false, 1.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
