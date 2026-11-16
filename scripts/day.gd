extends Control
## One day on the farm, the core loop of the prototype.
## Drag task cards onto work spots to give the kratt orders (max 3 at a time). It works through
## them on its own and gets faster at jobs it repeats. With nothing to do, its idle fuse burns, and
## when the fuse runs out it goes on a rampage. Hide it from the pastor, pay the rent at dusk.

const Balance = preload("res://scripts/balance.gd")
const CardScene = preload("res://scenes/card.tscn")

const INK := Color(0.08, 0.07, 0.06)
const ORANGE := Color(0.91, 0.35, 0.05)

@onready var barn_map: Control = $Maps/BarnMap
@onready var farm_map: Control = $Maps/FarmMap
@onready var kratt: Control = $Maps/BarnMap/Kratt
@onready var pastor: Control = $Maps/FarmMap/Pastor
@onready var scarecrow_point: Control = $Maps/FarmMap/ScarecrowPoint
@onready var barn_exit: Control = $Maps/BarnMap/ExitPoint
@onready var farm_exit: Control = $Maps/FarmMap/BarnDoorPoint
@onready var day_label: Label = $TopBar/DayLabel
@onready var clock_label: Label = $TopBar/ClockLabel
@onready var barn_tab: Button = $TopBar/BarnTab
@onready var farm_tab: Button = $TopBar/FarmTab
@onready var timeline: Control = $TopBar/Timeline
@onready var coins_label: Label = $TopBar/Coins
@onready var bread_label: Label = $TopBar/Bread
@onready var suspicion_label: Label = $TopBar/Suspicion
@onready var rampage_label: Label = $TopBar/Rampages
@onready var status_label: Label = $Bottom/KrattPanel/Status
@onready var slot_labels: Array = [$Bottom/KrattPanel/Slots/Slot1/Text, $Bottom/KrattPanel/Slots/Slot2/Text, $Bottom/KrattPanel/Slots/Slot3/Text]
@onready var fuse_bar: ProgressBar = $Bottom/KrattPanel/FuseBar
@onready var fuse_label: Label = $Bottom/KrattPanel/FuseLabel
@onready var disguise_button: Button = $Bottom/KrattPanel/DisguiseButton
@onready var hand_box: HBoxContainer = $Bottom/Hand
@onready var deck_label: Label = $Bottom/DeckPanel/DeckLabel
@onready var dialogue: Control = $Dialogue
@onready var dialogue_line: Label = $Dialogue/Line
@onready var option_buttons: Array = [$Dialogue/Options/Bribe, $Dialogue/Options/Sermon, $Dialogue/Options/Excuse]
@onready var patience_bar: ProgressBar = $Dialogue/Patience
@onready var banner: Label = $Banner
@onready var dusk_panel: Control = $Dusk
@onready var dusk_text: Label = $Dusk/Text
@onready var dusk_button: Button = $Dusk/Continue

var spots := {}                  # spot id -> work spot node
var draw_pile: Array[String] = []
var played: Array[String] = []
var orders: Array = []           # waiting orders: {"job", "spot"}
var current := {}                # order being done: {"job", "spot", "phase", "t", "travel", "work_t", "dur"}
var elapsed := 0.0
var running := false
var fuse := Balance.FUSE_MAX
var disguised := false
var kratt_map := "barn"
var kratt_feet := Vector2.ZERO
var kratt_spot := ""             # spot the kratt is standing at, "" while walking
var walk := {}                   # {"legs": [{"map", "from", "to", "dur"}], "i", "t"}
var visit_time := 60.0
var visit_state := "none"        # none -> coming -> here -> gone
var visit_wait := 0.0
var visit_leave := -1.0
var salt_used := false
var shown_map := "barn"
var banner_time := 0.0
var fuse_burning_style := false
var day_coins := 0
var day_bread := 0
var day_jobs := 0


func _ready() -> void:
	if Run.deck.is_empty():
		Run.new_run()
	for map in [barn_map, farm_map]:
		for child in map.get_children():
			if child.has_method("is_work_spot"):
				spots[child.spot_id] = child
				child.day = self
	barn_tab.day = self
	farm_tab.day = self
	barn_tab.pressed.connect(show_map.bind("barn"))
	farm_tab.pressed.connect(show_map.bind("farm"))
	$Maps/BarnMap/DoorButton.pressed.connect(show_map.bind("farm"))
	$Maps/FarmMap/BarnButton.pressed.connect(show_map.bind("barn"))
	disguise_button.pressed.connect(toggle_disguise)
	for i in option_buttons.size():
		option_buttons[i].pressed.connect(choose_option.bind(i))
	dusk_button.pressed.connect(_on_dusk_continue)
	start_day()


func start_day() -> void:
	elapsed = 0.0
	running = true
	fuse = Balance.FUSE_MAX
	orders.clear()
	current = {}
	walk = {}
	disguised = false
	salt_used = false
	day_coins = 0
	day_bread = 0
	day_jobs = 0
	visit_time = Balance.VISIT_TIMES[clampi(Run.day - 1, 0, Balance.VISIT_TIMES.size() - 1)]
	visit_state = "none"
	visit_leave = -1.0
	pastor.visible = false
	dialogue.visible = false
	dusk_panel.visible = false
	hand_box.visible = true
	for id in spots:
		spots[id].set_smashed(false)
	for card in hand_box.get_children():
		hand_box.remove_child(card)
		card.queue_free()
	draw_pile = Run.shuffled_deck()
	played.clear()
	for i in Balance.HAND_SIZE:
		draw_card()
	kratt.mode = "normal"
	kratt.visible = true
	place_kratt("barn", spots["threshing_floor"].work_point())
	kratt_spot = ""
	show_map("barn")
	show_banner("Day %d of %d. Rent at dusk: %d coins. Keep the kratt busy!" % [Run.day, Balance.DAYS, Run.rent_today()])
	update_ui()


func _process(delta: float) -> void:
	step(delta)


## Advances the day by delta seconds. The tests call this directly.
func step(delta: float) -> void:
	if banner_time > 0.0:
		banner_time -= delta
		if banner_time <= 0.0:
			banner.visible = false
	if not running:
		return
	elapsed += delta
	update_walk(delta)
	update_orders(delta)
	update_fuse(delta)
	if not running:
		return
	update_visit(delta)
	if not running:
		return
	update_ui()
	if elapsed >= Balance.DAY_LENGTH:
		end_day()


# ---------------- cards ----------------

func draw_card() -> void:
	if draw_pile.is_empty() or hand_box.get_child_count() >= Balance.HAND_SIZE:
		return
	var card = CardScene.instantiate()
	card.setup(draw_pile.pop_back())
	hand_box.add_child(card)


func order_count() -> int:
	return orders.size() + (0 if current.is_empty() else 1)


func can_play_card(card: Variant, spot: Variant) -> bool:
	if not running or visit_state == "here":
		return false
	if card == null or not is_instance_valid(card) or card.get_parent() != hand_box:
		return false
	if spot.smashed or Balance.JOBS[card.job]["spot"] != spot.spot_id:
		return false
	return order_count() < Balance.QUEUE_MAX


## Gives the kratt the card's job as a new order. Returns false if the card can't go there.
func play_card(card: Variant, spot: Variant) -> bool:
	if not can_play_card(card, spot):
		return false
	orders.append({"job": card.job, "spot": spot.spot_id})
	played.append(card.job)
	hand_box.remove_child(card)
	card.queue_free()
	draw_card()
	update_ui()
	return true


# ---------------- the kratt ----------------

func map_node(id: String) -> Control:
	return barn_map if id == "barn" else farm_map


func place_kratt(map_id: String, feet: Vector2) -> void:
	if kratt.get_parent() != map_node(map_id):
		kratt.reparent(map_node(map_id), false)
	kratt_map = map_id
	kratt_feet = feet
	kratt.position = feet - Vector2(kratt.size.x * 0.5, kratt.size.y)


func exit_point(map_id: String) -> Vector2:
	var marker: Control = barn_exit if map_id == "barn" else farm_exit
	return marker.position


## Walks the kratt to a point on a screen in `duration` seconds, through the barn door if needed.
func walk_to(map_id: String, feet: Vector2, duration: float) -> void:
	var legs: Array = []
	if map_id == kratt_map:
		legs.append({"map": map_id, "from": kratt_feet, "to": feet, "dur": duration})
	else:
		legs.append({"map": kratt_map, "from": kratt_feet, "to": exit_point(kratt_map), "dur": duration * 0.5})
		legs.append({"map": map_id, "from": exit_point(map_id), "to": feet, "dur": duration * 0.5})
	walk = {"legs": legs, "i": 0, "t": 0.0}


func update_walk(delta: float) -> void:
	if walk.is_empty():
		return
	var legs: Array = walk["legs"]
	var leg: Dictionary = legs[walk["i"]]
	walk["t"] += delta
	var k := clampf(walk["t"] / maxf(leg["dur"], 0.01), 0.0, 1.0)
	var from: Vector2 = leg["from"]
	place_kratt(leg["map"], from.lerp(leg["to"], k))
	if k >= 1.0:
		walk["i"] += 1
		walk["t"] = 0.0
		if walk["i"] >= legs.size():
			walk = {}


func travel_time(spot_id: String) -> float:
	if spot_id == kratt_spot:
		return 0.3
	var spot_map: String = Balance.SPOTS[spot_id]["map"]
	return Balance.TRAVEL_SAME_MAP if spot_map == kratt_map else Balance.TRAVEL_OTHER_MAP


## Sends the kratt (back) to the current order's spot. Work already done is kept.
func begin_travel() -> void:
	var spot_id: String = current["spot"]
	current["phase"] = "travel"
	current["t"] = 0.0
	current["travel"] = travel_time(spot_id)
	walk_to(Balance.SPOTS[spot_id]["map"], spots[spot_id].work_point(), current["travel"])
	kratt_spot = ""


func update_orders(delta: float) -> void:
	if disguised:
		return
	if current.is_empty():
		if orders.is_empty():
			return
		var next: Dictionary = orders.pop_front()
		current = {"job": next["job"], "spot": next["spot"], "work_t": 0.0, "dur": Run.job_time(next["job"])}
		begin_travel()
		return
	if current["phase"] == "travel":
		current["t"] += delta
		if current["t"] >= current["travel"]:
			current["phase"] = "work"
			kratt_spot = current["spot"]
			if Balance.SPOTS[current["spot"]]["far"]:
				kratt.visible = false
	else:
		current["work_t"] += delta
		if current["work_t"] >= current["dur"]:
			finish_order()


func finish_order() -> void:
	var job: String = current["job"]
	var spot_id: String = current["spot"]
	var data: Dictionary = Balance.JOBS[job]
	var coins: int = data["coins"]
	if Run.has_charm("horseshoe"):
		coins += 1
	var bread: int = data["bread"]
	Run.coins += coins
	Run.bread += bread
	Run.skill[job] = Run.skill.get(job, 0) + 1
	Run.jobs_done += 1
	day_coins += coins
	day_bread += bread
	day_jobs += 1
	current = {}
	kratt.visible = true
	var bits := PackedStringArray()
	if coins > 0:
		bits.append("+%d coins" % coins)
	if bread > 0:
		bits.append("+%d bread" % bread)
	if bits.is_empty():
		bits.append("done")
	popup(spot_id, ", ".join(bits))
	for card in hand_box.get_children():
		card.refresh()
	if data["suspicion"] > 0:
		add_suspicion(data["suspicion"], data.get("rumor", "Someone noticed."))


func is_working() -> bool:
	return not disguised and not current.is_empty()


## True if the pastor can't see the kratt: it is disguised or away on a far job.
func kratt_hidden() -> bool:
	if disguised:
		return true
	return not current.is_empty() and current["phase"] == "work" and Balance.SPOTS[current["spot"]]["far"]


func toggle_disguise() -> void:
	if not running:
		return
	if disguised:
		if visit_state == "here":
			show_banner("Not while the pastor is watching!")
			return
		disguised = false
		kratt.mode = "normal"
		if not current.is_empty():
			begin_travel()
		show_banner("The kratt climbs down from its post and gets back to work.")
	else:
		if not current.is_empty() and current["phase"] == "work" and Balance.SPOTS[current["spot"]]["far"]:
			show_banner("The kratt is far away right now. Nobody can see it anyway.")
			return
		disguised = true
		kratt.visible = true
		kratt.mode = "scarecrow"
		var trip := Balance.TRAVEL_SAME_MAP if kratt_map == "farm" else Balance.TRAVEL_OTHER_MAP
		walk_to("farm", scarecrow_point.position, trip)
		kratt_spot = ""
		show_banner("The kratt stands in the field as a scarecrow. It can't work like this, so its fuse burns.")
	update_ui()


# ---------------- idle fuse and rampage ----------------

func update_fuse(delta: float) -> void:
	if is_working():
		fuse = minf(Balance.FUSE_MAX, fuse + Balance.FUSE_REFILL * delta)
	else:
		var rate := Balance.ROWAN_BURN if Run.has_charm("rowan") else 1.0
		fuse -= delta * rate
		if fuse <= 0.0:
			rampage()


func rampage() -> void:
	fuse = Balance.FUSE_MAX
	Run.rampages += 1
	var choices: Array[String] = []
	for id in spots:
		if not spots[id].smashed and not Balance.SPOTS[id]["far"]:
			choices.append(id)
	var message := "RAMPAGE! The kratt ran out of work and went wild"
	if not choices.is_empty():
		var target: String = choices[Run.rng.randi_range(0, choices.size() - 1)]
		spots[target].set_smashed(true)
		var kept: Array = []
		for order in orders:
			if order["spot"] != target:
				kept.append(order)
		orders = kept
		if not current.is_empty() and current["spot"] == target:
			current = {}
		var burned := 0
		if not Run.has_charm("nail"):
			for card in hand_box.get_children():
				if Balance.JOBS[card.job]["spot"] == target:
					Run.deck.erase(card.job)
					hand_box.remove_child(card)
					card.queue_free()
					burned += 1
			while hand_box.get_child_count() < Balance.HAND_SIZE and not draw_pile.is_empty():
				draw_card()
		var spot_name: String = Balance.SPOTS[target]["name"]
		message = "RAMPAGE! The kratt smashed the %s" % spot_name.to_lower()
		if burned > 0:
			message += " and burned %d of its cards" % burned
		popup(target, "SMASHED")
	if disguised:
		disguised = false
		kratt.mode = "normal"
		if visit_state == "here":
			add_suspicion(1, "The pastor saw the scarecrow come alive!")
			if not running:
				return
	show_banner("%s. Rampage %d of %d." % [message, Run.rampages, Balance.RAMPAGE_LIMIT])
	if Run.rampages >= Balance.RAMPAGE_LIMIT:
		running = false
		Run.finish(false, "The kratt killed you", "It ran out of work for the third time, and this time it came for you.")
		return
	add_suspicion(1, "")


func add_suspicion(amount: int, message: String) -> void:
	if amount <= 0:
		return
	Run.suspicion = mini(Balance.SUSPICION_LIMIT, Run.suspicion + amount)
	if message != "":
		show_banner("%s  Suspicion +%d." % [message, amount])
	if Run.suspicion >= Balance.SUSPICION_LIMIT and running:
		running = false
		Run.finish(false, "The villagers came with torches",
			"Suspicion reached %d. Someone told the village about the kratt." % Balance.SUSPICION_LIMIT)


# ---------------- the pastor's visit ----------------

func update_visit(delta: float) -> void:
	if visit_state == "none":
		if elapsed >= visit_time - Balance.VISIT_WARNING:
			visit_state = "coming"
			show_banner("The pastor is coming up the road! Send the kratt somewhere far, or disguise it.")
	elif visit_state == "coming":
		if elapsed >= visit_time:
			pastor_arrives()
	elif visit_state == "here":
		if visit_leave >= 0.0:
			visit_leave -= delta
			if visit_leave <= 0.0:
				pastor_leaves()
		else:
			visit_wait += delta
			patience_bar.value = Balance.VISIT_PATIENCE - visit_wait
			if visit_wait >= Balance.VISIT_PATIENCE:
				add_suspicion(1, "The pastor got tired of waiting and walked off, frowning.")
				if running:
					pastor_leaves()


func pastor_arrives() -> void:
	visit_state = "here"
	visit_wait = 0.0
	visit_leave = -1.0
	pastor.visible = true
	show_map("farm")
	dialogue.visible = true
	hand_box.visible = false
	patience_bar.max_value = Balance.VISIT_PATIENCE
	patience_bar.value = Balance.VISIT_PATIENCE
	for button in option_buttons:
		button.disabled = false
	option_buttons[0].disabled = Run.bread < 1
	var line := "\"Good day! I was on my way to the manor and thought I would look in on you.\""
	if disguised:
		line = "\"Good day! I was on my way to the manor. Is that a new scarecrow in your field?\""
	if not kratt_hidden():
		if Run.has_charm("salt") and not salt_used:
			salt_used = true
			show_banner("Your salt line kept the pastor from noticing the kratt.")
		else:
			var where := "in the barn" if kratt_map == "barn" else "in the yard"
			line = "\"Good day! ...What is that thing %s?\"" % where
			add_suspicion(1, "The pastor saw the kratt %s!" % where)
	dialogue_line.text = line


func choose_option(index: int) -> void:
	if visit_state != "here" or visit_leave >= 0.0:
		return
	if index == 0:
		if Run.bread < 1:
			return
		Run.bread -= 1
		visit_leave = Balance.BRIBE_LEAVE
		dialogue_line.text = "\"Bless you, that smells wonderful!\" He tucks the loaf under his arm and turns to go."
	elif index == 1:
		visit_leave = Balance.SERMON_LEAVE
		Run.suspicion = maxi(0, Run.suspicion - 1)
		dialogue_line.text = "You talk about Sunday's sermon for a long, long time. He leaves pleased with you."
	else:
		visit_leave = Balance.EXCUSE_LEAVE
		dialogue_line.text = "\"A sick cow, you say?\" He doesn't look convinced."
		add_suspicion(1, "The pastor didn't believe your excuse.")
	for button in option_buttons:
		button.disabled = true
	update_ui()


func pastor_leaves() -> void:
	visit_state = "gone"
	visit_leave = -1.0
	pastor.visible = false
	dialogue.visible = false
	hand_box.visible = true
	show_banner("The pastor has gone. Back to work!")


# ---------------- dusk ----------------

func end_day() -> void:
	running = false
	pastor.visible = false
	dialogue.visible = false
	hand_box.visible = true
	var rent := Run.rent_today()
	if Run.coins < rent:
		Run.finish(false, "Thrown off the farm",
			"At dusk on day %d you had %d coins, but the rent was %d. The manor lord took the farm." % [Run.day, Run.coins, rent])
		return
	Run.coins -= rent
	var forgotten := mini(Run.suspicion, Balance.SUSPICION_DECAY)
	if Run.day < Balance.DAYS:
		Run.suspicion -= forgotten
	else:
		forgotten = 0
	dusk_text.text = "Jobs finished today: %d.  Coins earned: %d.  Bread baked: %d.\n\nRent paid: %d coins. You have %d coins and %d bread left.\nSuspicion %d of %d%s, rampages %d of %d." % [
		day_jobs, day_coins, day_bread, rent, Run.coins, Run.bread,
		Run.suspicion, Balance.SUSPICION_LIMIT, (" (%d forgotten overnight)" % forgotten if forgotten > 0 else ""),
		Run.rampages, Balance.RAMPAGE_LIMIT]
	dusk_button.text = "Go to the night market" if Run.day < Balance.DAYS else "Face the last night"
	dusk_panel.visible = true
	banner.visible = false
	banner_time = 0.0
	update_ui()


func _on_dusk_continue() -> void:
	if Run.day < Balance.DAYS:
		get_tree().change_scene_to_file("res://scenes/market.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/ladder_night.tscn")


# ---------------- screen and HUD ----------------

func show_map(id: String) -> void:
	shown_map = id
	barn_map.visible = id == "barn"
	farm_map.visible = id == "farm"
	barn_tab.set_pressed_no_signal(id == "barn")
	farm_tab.set_pressed_no_signal(id == "farm")


func show_banner(text: String) -> void:
	banner.text = text
	banner.visible = true
	banner_time = 4.5


## Small floating text over a work spot, e.g. "+3 coins".
func popup(spot_id: String, text: String) -> void:
	var spot: Control = spots[spot_id]
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", ORANGE)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spot.get_parent().add_child(label)
	label.position = spot.position + Vector2(10, -6)
	var tween := label.create_tween()
	tween.tween_property(label, "position:y", label.position.y - 36.0, 1.4)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 1.4)
	tween.tween_callback(label.queue_free)


func update_ui() -> void:
	var left := maxf(0.0, Balance.DAY_LENGTH - elapsed)
	day_label.text = "Day %d of %d" % [Run.day, Balance.DAYS]
	clock_label.text = "%d:%02d left today" % [floori(left / 60.0), floori(left) % 60]
	coins_label.text = "Coins %d\nrent %d at dusk" % [Run.coins, Run.rent_today()]
	bread_label.text = "Bread %d" % Run.bread
	suspicion_label.text = "Suspicion %d/%d" % [Run.suspicion, Balance.SUSPICION_LIMIT]
	rampage_label.text = "Rampages %d/%d" % [Run.rampages, Balance.RAMPAGE_LIMIT]
	timeline.now = clampf(elapsed / Balance.DAY_LENGTH, 0.0, 1.0)
	timeline.visit_at = -1.0 if visit_state == "gone" else visit_time / Balance.DAY_LENGTH
	timeline.visit_text = "Pastor (here)" if visit_state == "here" else "Pastor"
	timeline.queue_redraw()
	farm_tab.text = "Farmstead !" if visit_state == "coming" or visit_state == "here" else "Farmstead"

	# order queue: slot 1 is the job being done
	var shown: Array = []
	if not current.is_empty():
		shown.append(current)
	shown.append_array(orders)
	for i in slot_labels.size():
		var text := "%d. empty" % (i + 1)
		if i < shown.size():
			var order: Dictionary = shown[i]
			text = "%d. %s" % [i + 1, Balance.JOBS[order["job"]]["title"]]
			if i == 0 and not current.is_empty():
				if disguised:
					text += "\non hold"
				elif current["phase"] == "travel":
					text += "\nwalking there"
				else:
					text += "\n%.1f s left" % maxf(0.0, current["dur"] - current["work_t"])
			else:
				text += "\n%.1f s" % Run.job_time(order["job"])
		slot_labels[i].text = text

	# kratt status, figure and fuse
	var tag := ""
	if disguised:
		status_label.text = "Disguised as a scarecrow. Not working!"
		tag = "scarecrow"
	elif current.is_empty():
		status_label.text = "Idle! Give it an order."
		tag = "idle!"
	else:
		var job_title: String = Balance.JOBS[current["job"]]["title"]
		var spot_name: String = Balance.SPOTS[current["spot"]]["name"]
		if current["phase"] == "travel":
			status_label.text = "Walking to the %s" % spot_name.to_lower()
			tag = "..."
		elif Balance.SPOTS[current["spot"]]["far"]:
			status_label.text = "Away: %s (%.0f s)" % [job_title, current["dur"] - current["work_t"]]
		else:
			status_label.text = "%s at the %s" % [job_title, spot_name.to_lower()]
			tag = "%.1f s" % maxf(0.0, current["dur"] - current["work_t"])
	kratt.set_tag(tag)
	kratt.burning = not is_working()
	kratt.working = is_working() and current["phase"] == "work"
	kratt.progress = current["work_t"] / current["dur"] if kratt.working else -1.0
	fuse_bar.max_value = Balance.FUSE_MAX
	fuse_bar.value = fuse
	fuse_label.text = "%d s" % ceili(fuse)
	var burning_now := not is_working()
	if burning_now != fuse_burning_style:
		fuse_burning_style = burning_now
		var fill := StyleBoxFlat.new()
		fill.bg_color = ORANGE if burning_now else INK
		fuse_bar.add_theme_stylebox_override("fill", fill)
	disguise_button.text = "Back to work" if disguised else "Disguise as scarecrow"
	disguise_button.disabled = not running

	# what each work spot is doing
	for id in spots:
		var info := PackedStringArray()
		if spots[id].smashed:
			info.append("Smashed until tomorrow")
		for i in shown.size():
			if shown[i]["spot"] == id:
				if i == 0 and not current.is_empty():
					if Balance.SPOTS[id]["far"] and current["phase"] == "work" and not disguised:
						info.append("#1 kratt away, %.0f s" % (current["dur"] - current["work_t"]))
					else:
						info.append("#1 " + ("on hold" if disguised else "working"))
				else:
					info.append("#%d waiting" % (i + 1))
		spots[id].set_info("\n".join(info))

	# deck
	var remaining: Array = []
	for card in hand_box.get_children():
		remaining.append(card.job)
	remaining.append_array(draw_pile)
	for order in shown:
		remaining.append(order["job"])
	deck_label.text = "Draw pile: %d\nPlayed today: %d\nWork in cards: ~%d s\nTime left: %d s" % [
		draw_pile.size(), played.size(), roundi(Run.work_seconds(remaining)), roundi(left)]
