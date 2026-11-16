extends Node
## Plays whole runs with a simple strategy, to see how the numbers in balance.gd play out.
##   godot --headless --path . res://tests/balance_bot.tscn -- runs=20
## The bot keeps the queue full, disguises the kratt before the pastor comes, bribes or talks,
## and buys cards and charms at the market. A real player can do better (or worse).

const Balance = preload("res://scripts/balance.gd")

var runs := 10


func _ready() -> void:
	Run.testing = true
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("runs="):
			runs = int(arg.substr(5))
	await get_tree().process_frame
	var wins := 0
	var reasons := {}
	for seed_value in range(1, runs + 1):
		var lines: Array = await play_run(seed_value)
		if Run.won:
			wins += 1
		reasons[Run.end_title] = reasons.get(Run.end_title, 0) + 1
		print("run %d: %s (reached day %d)" % [seed_value, Run.end_title, Run.day])
		for line in lines:
			print("    ", line)
	print("\nwins: %d of %d" % [wins, runs])
	for title in reasons:
		print("  %s: %d" % [title, reasons[title]])
	get_tree().quit()


func play_run(seed_value: int) -> Array:
	Run.new_run(seed_value)
	var lines: Array = []
	while not Run.ended:
		var day = load("res://scenes/day.tscn").instantiate()
		add_child(day)
		day.set_process(false)
		var idle := 0.0
		while day.running:
			bot_turn(day)
			if not day.is_working():
				idle += 0.1
			day.step(0.1)
		lines.append("day %d: jobs %d, coins %d (earned %d), bread %d, suspicion %d, rampages %d, idle %d s, deck %d" % [
			Run.day, day.day_jobs, Run.coins, day.day_coins, Run.bread, Run.suspicion, Run.rampages, roundi(idle), Run.deck.size()])
		day.queue_free()
		await get_tree().process_frame
		if Run.ended:
			break
		if Run.day >= Balance.DAYS:
			if Run.bread >= Run.ladder_bread():
				Run.finish(true, "Free at last", "")
			else:
				Run.finish(false, "The ladder was too short", "")
			break
		var market = load("res://scenes/market.tscn").instantiate()
		add_child(market)
		await get_tree().process_frame
		bot_market(market)
		lines.append("  market: deck %d, coins %d, charms %s" % [Run.deck.size(), Run.coins, ", ".join(PackedStringArray(Run.charms))])
		market.queue_free()
		await get_tree().process_frame
		Run.day += 1
	return lines


func score(day: Node, job: String) -> float:
	var data: Dictionary = Balance.JOBS[job]
	var value: float = data["coins"] + data["bread"] * 1.5
	if data["suspicion"] > 0 and Run.suspicion >= 2:
		value -= 20.0
	if Balance.SPOTS[data["spot"]]["far"] and day.visit_state == "none" and day.visit_time - day.elapsed < 25.0:
		value += 10.0
	return value


func bot_turn(day: Node) -> void:
	if day.visit_state == "coming" and not day.disguised and not day.kratt_hidden() and day.elapsed >= day.visit_time - 2.5:
		day.toggle_disguise()
	if day.visit_state == "here":
		if day.visit_leave < 0.0:
			if Run.bread >= 1 and (Run.bread > Run.ladder_bread() - 4 or Run.suspicion < 2):
				day.choose_option(0)
			elif day.fuse > Balance.SERMON_LEAVE + 2.0 or day.is_working():
				day.choose_option(1)
			else:
				day.choose_option(0 if Run.bread >= 1 else 1)
		return
	if day.disguised and day.visit_state == "gone":
		day.toggle_disguise()
	for attempt in 3:
		if day.order_count() >= Balance.QUEUE_MAX:
			return
		var best = null
		var best_score := -999.0
		for card in day.hand_box.get_children():
			if card.is_queued_for_deletion():
				continue
			if not day.can_play_card(card, day.spots[Balance.JOBS[card.job]["spot"]]):
				continue
			var s := score(day, card.job)
			if s > best_score:
				best_score = s
				best = card
		if best == null:
			return
		day.play_card(best, day.spots[Balance.JOBS[best.job]["spot"]])


func bot_market(market: Node) -> void:
	for round_index in 2:
		for i in market.offers.size():
			var offer: Dictionary = market.offers[i]
			if offer["sold"]:
				continue
			var job: String = offer["job"]
			if job == "steal" and Run.suspicion >= 2:
				continue
			var wanted: bool = job == "bake" or Balance.JOBS[job]["coins"] >= 2 or round_index == 1
			if wanted and Run.coins >= Balance.JOBS[job]["price"]:
				market.buy_card(i)
	for i in market.charm_offers.size():
		if Run.coins >= Balance.CHARM_PRICE and market.charm_offers[i]["id"] in ["rowan", "nail", "horseshoe", "salt"]:
			market.buy_charm(i)
