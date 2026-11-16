extends Control
## The last night: give the kratt the one job it can never finish, a ladder of bread up to the sky.
## With enough bread it climbs to the top and bursts into a fireball. Without, it comes back down.

const Balance = preload("res://scripts/balance.gd")

@onready var text_label: Label = $Text
@onready var stage: Control = $Stage
@onready var result_label: Label = $Result
@onready var order_button: Button = $OrderButton
@onready var continue_button: Button = $ContinueButton

var success := false


func _ready() -> void:
	if Run.deck.is_empty():
		Run.new_run()
	var need := Run.ladder_bread()
	text_label.text = "%d days are behind you. Tonight you give the kratt the one job it can never finish: build a ladder of bread up to the sky.\nThe ladder needs %d loaves. You have %d." % [
		Balance.DAYS, need, Run.bread]
	stage.loaves_needed = need
	stage.loaves = Run.bread
	order_button.pressed.connect(order_ladder)
	continue_button.pressed.connect(_on_continue)
	continue_button.visible = false
	result_label.text = ""


func order_ladder() -> void:
	order_button.disabled = true
	success = Run.bread >= Run.ladder_bread()
	stage.success = success
	stage.start()


func _process(_delta: float) -> void:
	if stage.finished and not continue_button.visible:
		order_button.visible = false
		continue_button.visible = true
		if success:
			result_label.text = "The kratt reaches the top, bursts into flame and streaks across the sky like a falling star."
		else:
			result_label.text = "The bread runs out halfway up. The kratt climbs down, eyes glowing, looking for more work..."


func _on_continue() -> void:
	if success:
		Run.finish(true, "Free at last", "The kratt climbed the bread ladder and burst into a fireball. Folk will say they saw a falling star over your farm.")
	else:
		Run.finish(false, "The ladder was too short",
			"You had %d of the %d loaves the ladder needed. The kratt came back down, found no work, and found you." % [Run.bread, Run.ladder_bread()])
