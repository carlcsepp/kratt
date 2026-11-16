extends RefCounted
## Every tuning number for the prototype lives in this file.
## Change a value, press F5, play. Other scripts read these with
## `const Balance = preload("res://scripts/balance.gd")`.

# --- The run ---
const DAYS := 4                    # days before the ladder night
const DAY_LENGTH := 120.0          # seconds from dawn to dusk
const START_COINS := 0
const START_BREAD := 2
const RENT := [25, 35, 48, 60]     # coins due at dusk on day 1, 2, 3, 4
const LADDER_BREAD := 12           # loaves the bread ladder needs on the last night
const SUSPICION_DECAY := 1         # the village forgets a little every night

# --- Cards and the kratt ---
const HAND_SIZE := 5
const QUEUE_MAX := 3               # orders the kratt holds, counting the one it is doing
const LEARN_FACTOR := 0.85         # every repeat of a job makes it 15% faster
const MIN_JOB_TIME := 1.5          # a job never gets faster than this (seconds)
const TRAVEL_SAME_MAP := 1.0       # seconds to walk to a spot on the same screen
const TRAVEL_OTHER_MAP := 2.0      # seconds to walk between the barn and the farmstead
const FUSE_MAX := 15.0             # seconds of idling before a rampage
const FUSE_REFILL := 3.0           # fuse seconds won back per second of work
const RAMPAGE_LIMIT := 3           # the third rampage kills you
const SUSPICION_LIMIT := 5         # full suspicion brings the torch mob

# --- The pastor's visit (once a day) ---
const VISIT_TIMES := [60.0, 40.0, 75.0, 50.0]   # seconds after dawn, per day
const VISIT_WARNING := 12.0        # warning banner this many seconds before he arrives
const VISIT_PATIENCE := 15.0       # seconds he waits for an answer
const BRIBE_LEAVE := 2.0           # seconds until he leaves after each answer
const SERMON_LEAVE := 12.0
const EXCUSE_LEAVE := 1.0

# --- Night market ---
const MARKET_OFFERS := 3           # task cards for sale each night
const CHARM_OFFERS := 2            # charms for sale each night
const CHARM_PRICE := 6
const BURN_PRICE := 2              # coins to remove one card from the deck
const ROWAN_BURN := 0.7            # fuse burn speed with the Rowan Twig charm

# --- Work spots ("map" is the screen the spot is on) ---
const SPOTS := {
	"threshing_floor": {"name": "Threshing floor", "map": "barn", "far": false},
	"oven": {"name": "Oven", "map": "barn", "far": false},
	"workbench": {"name": "Workbench", "map": "barn", "far": false},
	"hay_pile": {"name": "Hay pile", "map": "barn", "far": false},
	"woodpile": {"name": "Woodpile", "map": "farm", "far": false},
	"well": {"name": "Well", "map": "farm", "far": false},
	"field": {"name": "Rye field", "map": "farm", "far": false},
	"forest": {"name": "Forest (far)", "map": "farm", "far": true},
}

# --- Task cards. "time" is seconds of work before the kratt learns the job.
# Far jobs include the trip, and the kratt can't be seen while it is away.
const JOBS := {
	"thresh": {"title": "Thresh Rye", "spot": "threshing_floor", "kind": "Chore", "time": 8.0, "coins": 4, "bread": 0, "suspicion": 0, "price": 5},
	"bake": {"title": "Bake Bread", "spot": "oven", "kind": "Bake", "time": 10.0, "coins": 0, "bread": 2, "suspicion": 0, "price": 5},
	"mend": {"title": "Mend Tools", "spot": "workbench", "kind": "Chore", "time": 6.0, "coins": 3, "bread": 0, "suspicion": 0, "price": 4},
	"straws": {"title": "Count the Straws", "spot": "hay_pile", "kind": "Busywork", "time": 5.0, "coins": 0, "bread": 0, "suspicion": 0, "price": 1},
	"chop": {"title": "Chop Firewood", "spot": "woodpile", "kind": "Chore", "time": 7.0, "coins": 3, "bread": 0, "suspicion": 0, "price": 4},
	"water": {"title": "Fetch Water", "spot": "well", "kind": "Chore", "time": 5.0, "coins": 2, "bread": 0, "suspicion": 0, "price": 3},
	"mow": {"title": "Mow Rye", "spot": "field", "kind": "Chore", "time": 9.0, "coins": 4, "bread": 0, "suspicion": 0, "price": 5},
	"forest_wood": {"title": "Haul Forest Wood", "spot": "forest", "kind": "Far chore", "time": 16.0, "coins": 5, "bread": 0, "suspicion": 0, "price": 5},
	"steal": {"title": "Steal Butter", "spot": "forest", "kind": "Theft", "time": 18.0, "coins": 8, "bread": 0, "suspicion": 1, "price": 3, "rumor": "The neighbours are missing their butter."},
}

const START_DECK := ["thresh", "thresh", "thresh", "chop", "chop", "water", "water", "mend", "mend", "bake", "bake", "straws", "mow", "forest_wood", "steal"]

# --- Folk charms (bought at the night market, kept for the rest of the run) ---
const CHARMS := {
	"rowan": {"name": "Rowan Twig", "text": "The idle fuse burns 30% slower."},
	"salt": {"name": "Salt Line", "text": "Once a day, a visitor doesn't notice the kratt."},
	"nail": {"name": "Iron Nail", "text": "Rampages don't burn your cards."},
	"horseshoe": {"name": "Horseshoe", "text": "+1 coin for every finished job."},
	"crust": {"name": "Blessed Crust", "text": "The bread ladder needs 2 fewer loaves."},
}


## "BARN · Oven", "YARD · Well" or "FAR · Forest (far)"
static func place_text(spot_id: String) -> String:
	var spot: Dictionary = SPOTS[spot_id]
	var where := "FAR"
	if not spot["far"]:
		where = "BARN" if spot["map"] == "barn" else "YARD"
	return "%s · %s" % [where, spot["name"]]


## "+3 coins", "+2 bread", "+6 coins, +1 suspicion" or "No reward, keeps it busy"
static func reward_text(job: String) -> String:
	var data: Dictionary = JOBS[job]
	var parts := PackedStringArray()
	if data["coins"] > 0:
		parts.append("+%d coins" % data["coins"])
	if data["bread"] > 0:
		parts.append("+%d bread" % data["bread"])
	if data["suspicion"] > 0:
		parts.append("+%d suspicion" % data["suspicion"])
	if parts.is_empty():
		return "No reward, keeps it busy"
	return ", ".join(parts)
