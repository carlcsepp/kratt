extends Node
## Saves screenshots of the main screens (needs a window, so no --headless):
##   godot --path . res://tests/screenshot_tour.tscn -- out=/path/to/folder

const Balance = preload("res://scripts/balance.gd")
const CardScene = preload("res://scenes/card.tscn")

var out_dir := "user://screenshots"


func _ready() -> void:
	Run.testing = true
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("out="):
			out_dir = arg.substr(4)
	DirAccess.make_dir_recursive_absolute(out_dir)
	await frames(3)

	var title = load("res://scenes/title.tscn").instantiate()
	add_child(title)
	await shot("1_title")
	title.queue_free()

	Run.new_run(3)
	Run.skill["thresh"] = 2
	var day = load("res://scenes/day.tscn").instantiate()
	add_child(day)
	day.set_process(false)
	day.play_card(card_for(day, "thresh"), day.spots["threshing_floor"])
	day.play_card(card_for(day, "mend"), day.spots["workbench"])
	for i in 50:
		day.step(0.1)
	day.show_banner("Day %d of %d. Rent at dusk: %d coins. Keep the kratt busy!" % [Run.day, Balance.DAYS, Run.rent_today()])
	await shot("2_barn")

	day.visit_time = day.elapsed + 3.0
	day.toggle_disguise()
	for i in 32:
		day.step(0.1)
	await shot("3_farmstead_visit")

	day.choose_option(0)
	for i in 25:
		day.step(0.1)
	day.toggle_disguise()
	# staged numbers so the dusk panel reads like a played day
	Run.coins = 38
	Run.bread = 3
	Run.suspicion = 2
	day.day_jobs = 10
	day.day_coins = 38
	day.day_bread = 2
	day.elapsed = Balance.DAY_LENGTH - 0.05
	day.orders.clear()
	day.current = {}
	day.step(0.1)
	await shot("4_dusk")
	day.queue_free()

	var market = load("res://scenes/market.tscn").instantiate()
	add_child(market)
	await shot("5_market")
	market.queue_free()

	Run.bread = 9
	var night = load("res://scenes/ladder_night.tscn").instantiate()
	add_child(night)
	night.stage.set_process(false)
	night.order_ladder()
	for i in 112:
		night.stage.step(0.05)
	await shot("6_ladder_night")
	night.queue_free()

	Run.ended = false
	Run.finish(true, "Free at last", "The kratt climbed the bread ladder and burst into a fireball. Folk will say they saw a falling star over your farm.")
	var end = load("res://scenes/end.tscn").instantiate()
	add_child(end)
	await shot("7_end")
	get_tree().quit()


func card_for(day: Node, job: String):
	for card in day.hand_box.get_children():
		if card.job == job:
			return card
	var card = CardScene.instantiate()
	card.setup(job)
	day.hand_box.add_child(card)
	return card


func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func shot(file_name: String) -> void:
	await frames(4)
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	image.save_png(out_dir.path_join(file_name + ".png"))
	print("saved ", out_dir.path_join(file_name + ".png"))
