extends Control
## Placeholder pastor: black coat, white collar tabs, a wide hat and a book.

const INK := Color(0.08, 0.07, 0.06)
const PAPER := Color(0.945, 0.925, 0.875)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var w := size.x
	var h := size.y
	var cx := w * 0.5
	draw_set_transform(Vector2(cx, h - 3.0), 0.0, Vector2(1.0, 0.25))
	draw_circle(Vector2.ZERO, w * 0.45, Color(0, 0, 0, 0.18))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_colored_polygon(PackedVector2Array([
		Vector2(cx - 12, h * 0.34), Vector2(cx + 12, h * 0.34),
		Vector2(cx + 18, h - 4), Vector2(cx - 18, h - 4)]), INK)
	draw_rect(Rect2(cx - 4, h * 0.34, 3, 10), PAPER)
	draw_rect(Rect2(cx + 1, h * 0.34, 3, 10), PAPER)
	draw_circle(Vector2(cx, h * 0.25), 9.0, PAPER)
	draw_arc(Vector2(cx, h * 0.25), 9.0, 0.0, TAU, 24, INK, 1.5)
	draw_circle(Vector2(cx - 4, h * 0.25), 1.4, INK)
	draw_rect(Rect2(cx - 8, h * 0.05, 16, 9), INK)
	draw_line(Vector2(cx - 18, h * 0.15), Vector2(cx + 18, h * 0.15), INK, 4.0)
	draw_rect(Rect2(cx - 22, h * 0.5, 9, 12), INK)
	draw_line(Vector2(cx - 14, h * 0.51), Vector2(cx - 14, h * 0.5 + 11), PAPER, 1.0)
