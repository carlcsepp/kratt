extends Panel
## A place where the kratt works. Drop a task card here if the card names this spot.

const Balance = preload("res://scripts/balance.gd")

const INK := Color(0.08, 0.07, 0.06)
const PAPER := Color(0.945, 0.925, 0.875)
const ORANGE := Color(0.91, 0.35, 0.05)
const GREY := Color(0.55, 0.53, 0.5)

@export var spot_id := ""

var day: Node = null      # set by the day scene
var smashed := false
var hover := false        # a card that fits is being dragged over this spot
var hint := false         # a card that fits this spot is being dragged somewhere

@onready var name_label: Label = $Name
@onready var info_label: Label = $Info


func is_work_spot() -> bool:
	return true


func _ready() -> void:
	mouse_exited.connect(_on_mouse_exited)
	_update_style()


## Where the kratt stands (its feet) while working here, in the map's coordinates.
func work_point() -> Vector2:
	return position + Vector2(size.x - 44.0, size.y - 6.0)


func set_info(text: String) -> void:
	if info_label.text != text:
		info_label.text = text


func set_smashed(value: bool) -> void:
	smashed = value
	_update_style()


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	var ok := false
	if day != null and data is Dictionary and data.get("type", "") == "card":
		ok = day.can_play_card(data["card"], self)
	if ok != hover:
		hover = ok
		_update_style()
	return ok


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	hover = false
	_update_style()
	day.play_card(data["card"], self)


func _on_mouse_exited() -> void:
	if hover:
		hover = false
		_update_style()


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_BEGIN:
		var data: Variant = get_viewport().gui_get_drag_data()
		hint = data is Dictionary and data.get("type", "") == "card" \
			and Balance.JOBS[data["job"]]["spot"] == spot_id
		_update_style()
	elif what == NOTIFICATION_DRAG_END:
		hint = false
		hover = false
		_update_style()


func _update_style() -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = PAPER
	box.border_color = INK
	box.set_border_width_all(2)
	if smashed:
		box.bg_color = Color(0.78, 0.76, 0.72)
		box.border_color = GREY
	elif hover:
		box.border_color = ORANGE
		box.set_border_width_all(6)
	elif hint:
		box.border_color = ORANGE
		box.set_border_width_all(3)
	add_theme_stylebox_override("panel", box)
	if is_node_ready():
		var spot_name: String = Balance.SPOTS[spot_id]["name"] if Balance.SPOTS.has(spot_id) else spot_id
		name_label.text = spot_name + (" (smashed)" if smashed else "")
