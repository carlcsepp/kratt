extends Node
## Automated checks of the gameplay loop. Runs without a window:
##   godot --headless --path . res://tests/test_runner.tscn
## Prints "ok"/"FAIL" per check and exits with code 1 if anything failed.

const Balance = preload("res://scripts/balance.gd")
const CardScene = preload("res://scenes/card.tscn")

var checks := 0
var failures := 0


func _ready() -> void:
	Run.testing = true
	await get_tree().process_frame
	await test_cards_and_queue()
	await test_drag_and_drop_hooks()
	await test_learning()
	await test_fuse_and_rampages()
	await test_visit_seen()
	await test_disguise()
	await test_far_job_and_answers()
	await test_dusk_and_rent()
	await test_market()
	await test_ladder()
	await test_other_scenes()
	print("\n%d checks, %d failed" % [checks, failures])
	get_tree().quit(1 if failures > 0 else 0)


func check(ok: bool, what: String) -> void:
	checks += 1
	if ok:
		print("  ok    ", what)
	else:
		failures += 1
		printerr("  FAIL  ", what)


func new_day(seed_value: int) -> Node:
	Run.new_run(seed_value)
	var day = load("res://scenes/day.tscn").instantiate()
	add_child(day)
	day.set_process(false)
	return day


func done(node: Node) -> void:
	node.queue_free()
	await get_tree().process_frame


func run_for(day: Node, seconds: float, busy := false) -> void:
	var t := 0.0
	while t < seconds and day.running:
		if busy:
			keep_busy(day)
		day.step(0.05)
		t += 0.05


## Plays any card that fits while the kratt has room for more orders.
func keep_busy(day: Node) -> void:
	for card in day.hand_box.get_children():
		if day.order_count() >= Balance.QUEUE_MAX:
			return
		if card.is_queued_for_deletion():
			continue
		day.play_card(card, day.spots[Balance.JOBS[card.job]["spot"]])


## A card of the given job from the hand, or a new one put into the hand.
func card_for(day: Node, job: String):
	for card in day.hand_box.get_children():
		if card.job == job and not card.is_queued_for_deletion():
			return card
	var card = CardScene.instantiate()
	card.setup(job)
	day.hand_box.add_child(card)
	return card


func test_cards_and_queue() -> void:
	print("cards and the order queue")
	var day := new_day(1)
	check(day.hand_box.get_child_count() == Balance.HAND_SIZE, "the hand starts with %d cards" % Balance.HAND_SIZE)
	check(day.draw_pile.size() == Balance.START_DECK.size() - Balance.HAND_SIZE, "the rest of the deck is the draw pile")
	var card = card_for(day, "thresh")
	check(not day.play_card(card, day.spots["oven"]), "a card can't go on the wrong spot")
	check(day.play_card(card, day.spots["threshing_floor"]), "a card goes on the spot it names")
	check(day.orders.size() == 1, "playing a card adds an order")
	check(day.hand_box.get_child_count() == Balance.HAND_SIZE, "a new card is drawn into the hand")
	day.play_card(card_for(day, "mend"), day.spots["workbench"])
	day.play_card(card_for(day, "bake"), day.spots["oven"])
	check(day.order_count() == 3, "three orders fit in the queue")
	check(not day.play_card(card_for(day, "chop"), day.spots["woodpile"]), "a fourth order is refused")
	await done(day)


func test_drag_and_drop_hooks() -> void:
	print("drag and drop")
	var day := new_day(11)
	var card = card_for(day, "water")
	var data := {"type": "card", "card": card, "job": "water"}
	check(not day.spots["oven"]._can_drop_data(Vector2.ZERO, data), "the oven refuses a Fetch Water card")
	check(day.spots["well"]._can_drop_data(Vector2.ZERO, data), "the well accepts it")
	day.spots["well"]._drop_data(Vector2.ZERO, data)
	check(day.order_count() == 1 and day.orders[0]["job"] == "water", "dropping the card gives the order")
	day.farm_tab._can_drop_data(Vector2.ZERO, data)
	check(day.shown_map == "farm" and day.farm_map.visible, "hovering a tab while dragging switches the screen")
	await done(day)


func test_learning() -> void:
	print("work, rewards and learning")
	var day := new_day(2)
	var coins_before: int = Run.coins
	day.play_card(card_for(day, "thresh"), day.spots["threshing_floor"])
	run_for(day, Balance.TRAVEL_SAME_MAP + Balance.JOBS["thresh"]["time"] + 0.5)
	check(Run.coins == coins_before + Balance.JOBS["thresh"]["coins"], "a finished job pays its coins")
	check(Run.skill["thresh"] == 1, "the kratt learned the job")
	check(is_equal_approx(Run.job_time("thresh"), Balance.JOBS["thresh"]["time"] * Balance.LEARN_FACTOR), "the job is now 15% faster")
	check(day.current.is_empty() and day.orders.is_empty(), "the queue is empty again")
	var bread_before: int = Run.bread
	day.play_card(card_for(day, "bake"), day.spots["oven"])
	run_for(day, Balance.TRAVEL_SAME_MAP + Balance.JOBS["bake"]["time"] + 0.5)
	check(Run.bread == bread_before + Balance.JOBS["bake"]["bread"], "baking gives bread")
	await done(day)


func test_fuse_and_rampages() -> void:
	print("idle fuse and rampages")
	var day := new_day(3)
	run_for(day, Balance.FUSE_MAX - 1.0)
	check(Run.rampages == 0 and day.fuse < 1.5, "the fuse burns while the kratt is idle")
	run_for(day, 1.5)
	check(Run.rampages == 1, "a rampage when the fuse runs out")
	var target := ""
	for id in day.spots:
		if day.spots[id].smashed:
			target = id
	check(target != "", "the rampage smashed a work spot")
	check(Run.suspicion >= 1, "the rampage raised suspicion")
	for job in Balance.JOBS:
		if Balance.JOBS[job]["spot"] == target:
			check(not day.play_card(card_for(day, job), day.spots[target]), "no orders on a smashed spot")
			break
	run_for(day, Balance.FUSE_MAX * 2.0 + 1.0)
	check(Run.rampages == Balance.RAMPAGE_LIMIT and Run.ended and not Run.won, "the third rampage ends the run")
	await done(day)


func test_visit_seen() -> void:
	print("the pastor sees the kratt")
	var day := new_day(4)
	day.visit_time = 6.0
	day.play_card(card_for(day, "thresh"), day.spots["threshing_floor"])
	run_for(day, 5.0)
	check(day.visit_state == "coming", "a warning before the pastor arrives")
	var before: int = Run.suspicion
	run_for(day, 1.2)
	check(day.visit_state == "here" and day.pastor.visible, "the pastor arrives on time")
	check(Run.suspicion == before + 1, "he sees the kratt working in the barn: suspicion +1")
	check(not day.hand_box.visible and day.dialogue.visible, "the cards are put away during the talk")
	check(not day.play_card(card_for(day, "mend"), day.spots["workbench"]), "no cards can be played while he is here")
	var bread: int = Run.bread
	day.choose_option(0)
	check(Run.bread == bread - 1, "bribing him costs a loaf")
	run_for(day, Balance.BRIBE_LEAVE + 0.2)
	check(day.visit_state == "gone" and not day.pastor.visible and day.hand_box.visible, "he leaves after the bribe")
	await done(day)


func test_disguise() -> void:
	print("the scarecrow disguise")
	var day := new_day(5)
	day.visit_time = 8.0
	day.play_card(card_for(day, "thresh"), day.spots["threshing_floor"])
	run_for(day, 3.0)
	var work_before: float = day.current["work_t"]
	day.toggle_disguise()
	check(day.disguised and day.kratt.mode == "scarecrow", "the kratt can be disguised as a scarecrow")
	var fuse_before: float = day.fuse
	run_for(day, 2.0)
	check(is_equal_approx(day.current["work_t"], work_before), "a disguised kratt doesn't work")
	check(day.fuse < fuse_before, "its fuse burns while it is disguised")
	check(day.kratt_map == "farm", "it stands in the field on the farmstead")
	var before: int = Run.suspicion
	run_for(day, 3.5)
	check(day.visit_state == "here" and Run.suspicion == before, "the pastor doesn't notice the scarecrow")
	day.toggle_disguise()
	check(day.disguised, "it can't climb down while the pastor watches")
	day.choose_option(0)
	run_for(day, Balance.BRIBE_LEAVE + 0.2)
	day.toggle_disguise()
	check(not day.disguised and day.visit_state == "gone", "back to work after he left")
	run_for(day, 10.0)
	check(Run.skill["thresh"] == 1 and Run.rampages == 0, "it finished the job it was doing before")
	await done(day)


func test_far_job_and_answers() -> void:
	print("far jobs and the other answers")
	var day := new_day(6)
	day.visit_time = 6.0
	day.play_card(card_for(day, "forest_wood"), day.spots["forest"])
	run_for(day, Balance.TRAVEL_OTHER_MAP + 0.3)
	check(not day.kratt.visible and day.kratt_hidden(), "the kratt is out of sight on a far job")
	var before: int = Run.suspicion
	run_for(day, 6.0 - Balance.TRAVEL_OTHER_MAP)
	check(day.visit_state == "here" and Run.suspicion == before, "the pastor can't see a kratt that is far away")
	day.choose_option(2)
	check(Run.suspicion == before + 1, "a bad excuse raises suspicion")
	run_for(day, Balance.EXCUSE_LEAVE + 0.2)
	check(day.visit_state == "gone", "he leaves quickly after the excuse")
	await done(day)

	day = new_day(12)
	Run.suspicion = 2
	day.visit_time = 4.0
	day.play_card(card_for(day, "steal"), day.spots["forest"])
	run_for(day, 4.2)
	day.choose_option(1)
	check(Run.suspicion == 1, "talking about the sermon lowers suspicion")
	run_for(day, Balance.SERMON_LEAVE + 0.2)
	check(day.visit_state == "gone", "he leaves after the long talk")
	run_for(day, 6.0)
	check(Run.suspicion == 2 and Run.coins >= Balance.JOBS["steal"]["coins"], "a theft pays well but raises suspicion")
	await done(day)

	day = new_day(13)
	day.visit_time = 3.0
	day.play_card(card_for(day, "forest_wood"), day.spots["forest"])
	before = Run.suspicion
	run_for(day, 3.2 + Balance.VISIT_PATIENCE + 0.3)
	check(day.visit_state == "gone" and Run.suspicion == before + 1, "ignoring the pastor costs suspicion")
	await done(day)


func test_dusk_and_rent() -> void:
	print("dusk and rent")
	var day := new_day(7)
	day.visit_time = 9999.0
	run_for(day, Balance.DAY_LENGTH - 0.2, true)
	check(day.running, "a busy kratt makes it to dusk")
	day.orders.clear()
	day.current = {}
	Run.coins = Run.rent_today() + 5
	Run.suspicion = 2
	run_for(day, 0.5)
	check(not day.running and day.dusk_panel.visible, "the day ends at dusk")
	check(Run.coins == 5, "the rent is paid at dusk")
	check(Run.suspicion == 2 - Balance.SUSPICION_DECAY, "the village forgets some suspicion overnight")
	await done(day)

	day = new_day(10)
	day.visit_time = 9999.0
	Run.day = Balance.DAYS
	Run.coins = 999
	Run.suspicion = 2
	day.elapsed = Balance.DAY_LENGTH - 0.01
	run_for(day, 0.1)
	check(not day.running and Run.suspicion == 2, "suspicion doesn't fade before the ladder night")
	await done(day)

	day = new_day(8)
	Run.coins = 0
	day.elapsed = Balance.DAY_LENGTH - 0.01
	run_for(day, 0.1)
	check(Run.ended and not Run.won and Run.end_title == "Thrown off the farm", "no rent money ends the run")
	await done(day)


func test_market() -> void:
	print("night market")
	Run.new_run(9)
	Run.coins = 30
	var market = load("res://scenes/market.tscn").instantiate()
	add_child(market)
	await get_tree().process_frame
	var deck_before: int = Run.deck.size()
	var job: String = market.offers[0]["job"]
	market.buy_card(0)
	check(Run.deck.size() == deck_before + 1 and Run.coins == 30 - Balance.JOBS[job]["price"], "buying a card adds it to the deck")
	market.buy_card(0)
	check(Run.deck.size() == deck_before + 1, "each offer can only be bought once")
	var coins: int = Run.coins
	market.burn_card("straws")
	check(Run.deck.size() == deck_before and Run.coins == coins - Balance.BURN_PRICE, "burning removes a card for a price")
	if market.charm_offers.size() > 0:
		var id: String = market.charm_offers[0]["id"]
		market.buy_charm(0)
		check(Run.has_charm(id), "a charm can be bought")
	await done(market)


func test_ladder() -> void:
	print("ladder night")
	for enough in [true, false]:
		Run.new_run(10)
		Run.bread = Run.ladder_bread() if enough else Run.ladder_bread() - 3
		var night = load("res://scenes/ladder_night.tscn").instantiate()
		add_child(night)
		await get_tree().process_frame
		night.stage.set_process(false)
		night.set_process(false)
		night.order_ladder()
		for i in 200:
			night.stage.step(0.05)
		night._process(0.0)
		check(night.continue_button.visible, "the ladder night plays out (enough bread: %s)" % enough)
		night._on_continue()
		check(Run.ended and Run.won == enough, "enough bread wins, too little loses (enough bread: %s)" % enough)
		await done(night)


func test_other_scenes() -> void:
	print("other scenes")
	for path in ["res://scenes/title.tscn", "res://scenes/end.tscn"]:
		var node = load(path).instantiate()
		add_child(node)
		await get_tree().process_frame
		check(is_instance_valid(node) and node.is_inside_tree(), "%s opens" % path)
		await done(node)
