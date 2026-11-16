extends PanelContainer
## A task card in the hand. Drag it onto the work spot it names to give the kratt an order.

const Balance = preload("res://scripts/balance.gd")

var job := ""

@onready var title_label: Label = $Margin/VBox/Title
@onready var where_label: Label = $Margin/VBox/Where
@onready var kind_label: Label = $Margin/VBox/Kind
@onready var time_label: Label = $Margin/VBox/Time
@onready var reward_label: Label = $Margin/VBox/Reward
@onready var skill_label: Label = $Margin/VBox/Skill


func setup(job_id: String) -> void:
	job = job_id
	if is_node_ready():
		refresh()


func _ready() -> void:
	refresh()


## Updates the text, e.g. after the kratt has learned the job and it got faster.
func refresh() -> void:
	if job == "":
		return
	var data: Dictionary = Balance.JOBS[job]
	var level: int = Run.skill.get(job, 0)
	title_label.text = data["title"]
	where_label.text = Balance.place_text(data["spot"])
	kind_label.text = data["kind"]
	time_label.text = "%.1f s" % Run.job_time(job)
	reward_label.text = Balance.reward_text(job)
	skill_label.text = "Kratt skill %d" % level
	tooltip_text = "%s\nDrag onto: %s\nTakes %.1f s (base %.0f s, kratt skill %d)\nReward: %s" % [
		data["title"], Balance.place_text(data["spot"]), Run.job_time(job), data["time"], level,
		Balance.reward_text(job)]


func _get_drag_data(_at_position: Vector2) -> Variant:
	if job == "":
		return null
	var preview := PanelContainer.new()
	var label := Label.new()
	label.text = "%s\n%s" % [title_label.text, where_label.text]
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	preview.add_child(label)
	preview.modulate = Color(1, 1, 1, 0.9)
	var holder := Control.new()
	holder.add_child(preview)
	preview.position = Vector2(-70, -30)
	set_drag_preview(holder)
	modulate = Color(1, 1, 1, 0.35)
	return {"type": "card", "card": self, "job": job}


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		modulate = Color(1, 1, 1, 1)
