extends Control
## Title screen with a short how-to.


func _ready() -> void:
	$StartButton.pressed.connect(_on_start)
	$StartButton.grab_focus()


func _on_start() -> void:
	Run.new_run()
	get_tree().change_scene_to_file("res://scenes/day.tscn")
