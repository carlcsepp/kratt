extends Node
## Autoload "Run": the state of one run that survives scene changes
## (day, coins, bread, suspicion, rampages, deck, the kratt's skills, charms).

const Balance = preload("res://scripts/balance.gd")

var day := 1
var coins := 0
var bread := 0
var suspicion := 0
var rampages := 0
var deck: Array[String] = []
var skill := {}                 # job id -> how many times the kratt has done it
var charms: Array[String] = []
var jobs_done := 0
var won := false
var ended := false
var end_title := ""
var end_reason := ""
var testing := false            # set by the test scenes: no scene changes
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	new_run()


func new_run(seed_value: int = -1) -> void:
	if seed_value >= 0:
		rng.seed = seed_value
	else:
		rng.randomize()
	day = 1
	coins = Balance.START_COINS
	bread = Balance.START_BREAD
	suspicion = 0
	rampages = 0
	deck.clear()
	for job in Balance.START_DECK:
		deck.append(job)
	skill.clear()
	for job in Balance.JOBS:
		skill[job] = 0
	charms.clear()
	jobs_done = 0
	won = false
	ended = false
	end_title = ""
	end_reason = ""


## Seconds the job takes now that the kratt has learned it skill[job] times.
func job_time(job: String) -> float:
	var base: float = Balance.JOBS[job]["time"]
	var level: int = skill.get(job, 0)
	return maxf(Balance.MIN_JOB_TIME, base * pow(Balance.LEARN_FACTOR, level))


func rent_today() -> int:
	return Balance.RENT[clampi(day - 1, 0, Balance.RENT.size() - 1)]


func ladder_bread() -> int:
	return maxi(1, Balance.LADDER_BREAD - (2 if has_charm("crust") else 0))


func has_charm(id: String) -> bool:
	return charms.has(id)


## A shuffled copy of the deck, used as the day's draw pile.
func shuffled_deck() -> Array[String]:
	var pile: Array[String] = []
	for job in deck:
		pile.append(job)
	for i in range(pile.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp := pile[i]
		pile[i] = pile[j]
		pile[j] = tmp
	return pile


## Rough seconds of work the given cards give the kratt (job time plus a short walk each).
func work_seconds(jobs: Array) -> float:
	var total := 0.0
	for job in jobs:
		total += job_time(job) + Balance.TRAVEL_SAME_MAP
	return total


## Ends the run and shows the end screen.
func finish(won_run: bool, title: String, reason: String) -> void:
	if ended:
		return
	ended = true
	won = won_run
	end_title = title
	end_reason = reason
	if not testing:
		get_tree().change_scene_to_file.call_deferred("res://scenes/end.tscn")
