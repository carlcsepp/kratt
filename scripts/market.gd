extends Control
## The night market between days: buy task cards and folk charms, burn cards you don't want.
## A deck that is too thin runs out before dusk, and the kratt idles. The deck info shows on top
## roughly how long your cards keep it busy now that it has learned some jobs.

const Balance = preload("res://scripts/balance.gd")

@onready var title_label: Label = $Title
@onready var stats_label: Label = $Stats
@onready var offers_box: VBoxContainer = $Offers
@onready var charms_box: VBoxContainer = $Charms
@onready var owned_label: Label = $OwnedCharms
@onready var deck_info: Label = $DeckInfo
@onready var deck_box: GridContainer = $Deck
@onready var message_label: Label = $Message
@onready var start_button: Button = $StartButton

var offers: Array = []          # [{"job": String, "sold": bool}]
var charm_offers: Array = []    # [{"id": String, "sold": bool}]


func _ready() -> void:
	if Run.deck.is_empty():
		Run.new_run()
	var jobs: Array = Balance.JOBS.keys()
	for i in Balance.MARKET_OFFERS:
		offers.append({"job": jobs[Run.rng.randi_range(0, jobs.size() - 1)], "sold": false})
	var free: Array = []
	for id in Balance.CHARMS:
		if not Run.has_charm(id):
			free.append(id)
	for i in mini(Balance.CHARM_OFFERS, free.size()):
		var j := Run.rng.randi_range(0, free.size() - 1)
		charm_offers.append({"id": free[j], "sold": false})
		free.remove_at(j)
	start_button.text = "Start day %d" % (Run.day + 1)
	start_button.pressed.connect(_on_start)
	rebuild()


func next_rent() -> int:
	return Balance.RENT[clampi(Run.day, 0, Balance.RENT.size() - 1)]


func rebuild() -> void:
	title_label.text = "Night market after day %d" % Run.day
	stats_label.text = "Coins %d     Bread %d     Suspicion %d/%d     Rampages %d/%d     Rent tomorrow: %d" % [
		Run.coins, Run.bread, Run.suspicion, Balance.SUSPICION_LIMIT, Run.rampages, Balance.RAMPAGE_LIMIT, next_rent()]
	for box in [offers_box, charms_box, deck_box]:
		for child in box.get_children():
			box.remove_child(child)
			child.queue_free()

	for i in offers.size():
		var job: String = offers[i]["job"]
		var data: Dictionary = Balance.JOBS[job]
		var button := _row(offers_box, "%s   (%s, %.1f s, %s)" % [
			data["title"], Balance.place_text(data["spot"]), Run.job_time(job), Balance.reward_text(job)])
		if offers[i]["sold"]:
			button.text = "Bought"
			button.disabled = true
		else:
			button.text = "Buy (%d)" % data["price"]
			button.disabled = Run.coins < data["price"]
			button.pressed.connect(buy_card.bind(i))

	for i in charm_offers.size():
		var id: String = charm_offers[i]["id"]
		var button := _row(charms_box, "%s: %s" % [Balance.CHARMS[id]["name"], Balance.CHARMS[id]["text"]])
		if charm_offers[i]["sold"]:
			button.text = "Bought"
			button.disabled = true
		else:
			button.text = "Buy (%d)" % Balance.CHARM_PRICE
			button.disabled = Run.coins < Balance.CHARM_PRICE
			button.pressed.connect(buy_charm.bind(i))
	var names := PackedStringArray()
	for id in Run.charms:
		names.append("%s (%s)" % [Balance.CHARMS[id]["name"], Balance.CHARMS[id]["text"]])
	owned_label.text = "Your charms: " + ("none yet" if names.is_empty() else "; ".join(names))

	var counts := {}
	for job in Run.deck:
		counts[job] = counts.get(job, 0) + 1
	for job in Balance.JOBS:
		if not counts.has(job):
			continue
		var button := _row(deck_box, "%s x%d   (kratt skill %d, %.1f s)" % [
			Balance.JOBS[job]["title"], counts[job], Run.skill.get(job, 0), Run.job_time(job)])
		button.text = "Burn one (%d)" % Balance.BURN_PRICE
		button.disabled = Run.coins < Balance.BURN_PRICE or Run.deck.size() <= 1
		button.pressed.connect(burn_card.bind(job))
	deck_info.text = "Your deck: %d cards. At the kratt's current speed they keep it busy for about %d s of the %d s day." % [
		Run.deck.size(), roundi(Run.work_seconds(Run.deck)), roundi(Balance.DAY_LENGTH)]


## Adds a row with a text label and a button to a container and returns the button.
func _row(box: Container, text: String) -> Button:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var label := Label.new()
	label.text = text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 15)
	row.add_child(label)
	var button := Button.new()
	button.custom_minimum_size = Vector2(130, 0)
	row.add_child(button)
	box.add_child(row)
	return button


func buy_card(index: int) -> void:
	var job: String = offers[index]["job"]
	var price: int = Balance.JOBS[job]["price"]
	if offers[index]["sold"] or Run.coins < price:
		return
	Run.coins -= price
	Run.deck.append(job)
	offers[index]["sold"] = true
	message_label.text = "%s is now in your deck." % Balance.JOBS[job]["title"]
	rebuild()


func buy_charm(index: int) -> void:
	var id: String = charm_offers[index]["id"]
	if charm_offers[index]["sold"] or Run.coins < Balance.CHARM_PRICE:
		return
	Run.coins -= Balance.CHARM_PRICE
	Run.charms.append(id)
	charm_offers[index]["sold"] = true
	message_label.text = "You hang the %s over the barn door." % Balance.CHARMS[id]["name"]
	rebuild()


func burn_card(job: String) -> void:
	if Run.coins < Balance.BURN_PRICE or not Run.deck.has(job) or Run.deck.size() <= 1:
		return
	Run.coins -= Balance.BURN_PRICE
	Run.deck.erase(job)
	message_label.text = "You burned one %s card." % Balance.JOBS[job]["title"]
	rebuild()


func _on_start() -> void:
	Run.day += 1
	get_tree().change_scene_to_file("res://scenes/day.tscn")
