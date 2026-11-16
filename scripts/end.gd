extends Control
## Win or lose screen with a short summary of the run.

const Balance = preload("res://scripts/balance.gd")

const ORANGE := Color(0.91, 0.35, 0.05)


func _ready() -> void:
	$Title.text = Run.end_title if Run.end_title != "" else "The end"
	if Run.won:
		$Title.add_theme_color_override("font_color", ORANGE)
	$Reason.text = Run.end_reason
	var best := ""
	var best_level := 0
	for job in Run.skill:
		if Run.skill[job] > best_level:
			best_level = Run.skill[job]
			best = Balance.JOBS[job]["title"]
	$Stats.text = "Reached day %d of %d.   Jobs done: %d.\nCoins %d   Bread %d   Suspicion %d/%d   Rampages %d/%d\nThe kratt's best job: %s" % [
		Run.day, Balance.DAYS, Run.jobs_done, Run.coins, Run.bread, Run.suspicion, Balance.SUSPICION_LIMIT,
		Run.rampages, Balance.RAMPAGE_LIMIT, ("%s (skill %d)" % [best, best_level]) if best != "" else "none"]
	$Again.pressed.connect(_on_again)
	$TitleButton.pressed.connect(_on_title)


func _on_again() -> void:
	Run.new_run()
	get_tree().change_scene_to_file("res://scenes/day.tscn")


func _on_title() -> void:
	get_tree().change_scene_to_file("res://scenes/title.tscn")
