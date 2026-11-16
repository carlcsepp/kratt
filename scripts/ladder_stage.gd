extends Control
## Draws the last night: a ladder of loaves going up, the kratt climbing it and,
## if the ladder is tall enough, a fireball streaking across the sky.

const PAPER := Color(0.945, 0.925, 0.875)
const ORANGE := Color(0.91, 0.35, 0.05)
const HAY := Color(0.86, 0.80, 0.62)
const BREAD := Color(0.72, 0.53, 0.32)
const BUILD_TIME := 3.0
const CLIMB_TIME := 2.0
const END_TIME := 2.5

var loaves := 0
var loaves_needed := 8
var success := false
var playing := false
var finished := false
var t := 0.0
var _stars: Array = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for i in 50:
		_stars.append(Vector2(rng.randf_range(0, size.x), rng.randf_range(0, size.y * 0.6)))


func start() -> void:
	playing = true
	finished = false
	t = 0.0


func step(delta: float) -> void:
	if not playing:
		return
	t += delta
	if t >= BUILD_TIME + CLIMB_TIME + END_TIME:
		finished = true
	queue_redraw()


func _process(delta: float) -> void:
	step(delta)


func _draw() -> void:
	for star in _stars:
		draw_circle(star, 1.5, Color(PAPER, 0.7))
	var ground := size.y - 20.0
	draw_line(Vector2(0, ground), Vector2(size.x, ground), PAPER, 2.0)
	var cx := size.x * 0.5
	var loaf_h := (ground - 30.0) / float(loaves_needed)
	var built: int = loaves_needed if success else mini(loaves, loaves_needed)
	var shown := 0
	if playing:
		shown = int(clampf(t / BUILD_TIME, 0.0, 1.0) * built)
	for i in shown:
		var y := ground - (i + 1) * loaf_h
		draw_rect(Rect2(cx - 32, y + 2, 64, loaf_h - 4), BREAD)
		draw_rect(Rect2(cx - 32, y + 2, 64, loaf_h - 4), PAPER, false, 1.5)
	var climb := clampf((t - BUILD_TIME) / CLIMB_TIME, 0.0, 1.0) if playing else 0.0
	var top_y := ground - built * loaf_h
	var feet_y := lerpf(ground, top_y, climb)
	var fire := success and playing and t > BUILD_TIME + CLIMB_TIME
	if not fire:
		_draw_kratt(Vector2(cx + 52, feet_y), playing and t > BUILD_TIME + CLIMB_TIME)
	else:
		var k := clampf((t - BUILD_TIME - CLIMB_TIME) / END_TIME, 0.0, 1.0)
		var start := Vector2(cx + 52, top_y)
		var p := start.lerp(Vector2(size.x + 60, -60), k)
		draw_line(start, p, Color(ORANGE, 0.45), 8.0)
		draw_circle(p, 20.0 + 6.0 * sin(t * 20.0), ORANGE)
		draw_circle(p, 8.0, PAPER)


func _draw_kratt(feet: Vector2, angry: bool) -> void:
	draw_line(feet + Vector2(-5, -10), feet + Vector2(-7, 0), PAPER, 3.0)
	draw_line(feet + Vector2(5, -10), feet + Vector2(7, 0), PAPER, 3.0)
	draw_rect(Rect2(feet.x - 11, feet.y - 34, 22, 26), HAY)
	draw_circle(feet + Vector2(0, -40), 10.0, Color(0.2, 0.18, 0.16))
	var eye := ORANGE if angry else PAPER
	draw_circle(feet + Vector2(-4, -42), 2.0, eye)
	draw_circle(feet + Vector2(4, -42), 2.0, eye)
