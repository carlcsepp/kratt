extends Control
## The day timeline in the top bar: dawn to dusk, a marker for now and one for the visitor.

const PAPER := Color(0.945, 0.925, 0.875)
const ORANGE := Color(0.91, 0.35, 0.05)

var now := 0.0           # 0..1 through the day
var visit_at := -1.0     # 0..1, or -1 for no visitor
var visit_text := ""


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var font := get_theme_default_font()
	var w := size.x
	var y := 16.0
	draw_line(Vector2(0, y), Vector2(w, y), Color(PAPER, 0.4), 2.0)
	draw_line(Vector2(0, y), Vector2(w * now, y), PAPER, 4.0)
	for i in range(5):
		var x := w * i / 4.0
		draw_line(Vector2(x, y - 5), Vector2(x, y + 5), PAPER, 2.0)
	# hide the end labels when the visitor's label would sit on top of them
	if visit_at < 0.0 or visit_at > 0.2:
		draw_string(font, Vector2(0, y + 22), "dawn", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, PAPER)
	if visit_at < 0.0 or visit_at < 0.75:
		draw_string(font, Vector2(w - 90, y + 22), "dusk: rent", HORIZONTAL_ALIGNMENT_RIGHT, 90, 12, PAPER)
	if visit_at >= 0.0:
		var vx := w * visit_at
		draw_circle(Vector2(vx, y), 7.0, ORANGE)
		draw_string(font, Vector2(vx - 70, y + 22), visit_text, HORIZONTAL_ALIGNMENT_CENTER, 140, 12, ORANGE)
	var nx := w * now
	draw_colored_polygon(PackedVector2Array([
		Vector2(nx - 6, y - 14), Vector2(nx + 6, y - 14), Vector2(nx, y - 4)]), PAPER)
