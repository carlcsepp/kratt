extends Button
## A screen tab (Barn / Farmstead). Hovering it while dragging a card switches the screen,
## so you can drop the card on a spot over there.

@export var map_id := "barn"

var day: Node = null


func _can_drop_data(_at_position: Vector2, _data: Variant) -> bool:
	if day != null:
		day.show_map(map_id)
	return false
