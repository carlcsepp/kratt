# Kratt - low-fi prototype

A low-fi prototype of the core loop of Kratt, made in Godot 4. Everything is boxes, text and simple shapes on purpose: it's for testing how the loop plays, not how the game looks.

## Opening it

1. Get Godot 4.4 or newer (the standard version, not .NET). We made and tested it with 4.7.2.
2. In the Godot Project Manager, click **Import** and pick `project.godot` from this folder.
3. Press **F5** (or the play button in the top right). The game starts on the title screen.

The first time you open it, Godot takes a few seconds to build its `.godot` cache folder.

## How to play

Everything is done with the mouse.

- A run is 4 days of 2 minutes each, then the ladder night.
- Drag task cards from your hand onto the work spot named on the card (BARN, YARD or FAR). The kratt holds up to 3 orders and walks to the spots by itself.
- Switch between the barn and the farmstead with the tabs at the top or the door buttons. While you're dragging a card, hover over a tab to switch screens.
- Every time the kratt repeats a job it gets 15% faster at it, so it needs more and more work.
- When it has no orders, its idle fuse burns. When the fuse runs out, the kratt smashes a work spot and burns the cards in your hand that go there. The third rampage kills you.
- The pastor comes once a day (the orange dot on the timeline). Before he arrives, send the kratt on a FAR job or press **Disguise as scarecrow**. A disguised kratt doesn't work, so the fuse burns. If he sees the kratt, suspicion goes up. Then pick an answer to get rid of him. At 5 suspicion the villagers come with torches.
- Rent is due at dusk. After that comes the night market, where you can buy task cards and charms or pay to burn cards you don't want. Suspicion also drops by 1 on each of these nights.
- After day 4 the kratt builds a ladder out of bread. You need 12 loaves.

You lose if you can't pay the rent, the kratt rampages 3 times, suspicion reaches 5, or you don't have enough bread on the last night.

## Changing the numbers

All the tuning values are in `scripts/balance.gd`, each with a comment: day length, rent, card times and rewards, the fuse, when the pastor comes, market prices, charms and the starting deck. Change a value and press F5.

With the current numbers, a simple bot that keeps the queue full wins 39 of 60 runs. Most of its losses are on the day 4 rent, and a few come from suspicion, the bread ladder or the day 3 rent.

## What's where

- `scenes/` - the screens (title, day, market, ladder_night, end) and the small pieces they use (card, work_spot, kratt, pastor)
- `scripts/run.gd` - the state of the whole run, loaded as `Run`: day, coins, bread, suspicion, deck, what the kratt has learned and the charms
- `scripts/day.gd` - one day: hand and draw pile, the order queue, walking, work, the fuse, rampages, the pastor and dusk
- `scripts/market.gd`, `scripts/ladder_night.gd` - the night market and the ending
- `scripts/balance.gd` - all the numbers
- `ui/theme.tres` - font sizes and box styles
- `tests/` - test scenes, not part of the game

## Tests (optional)

Run these from this folder, where `godot` is your Godot 4 executable:

```
godot --headless --path . res://tests/test_runner.tscn
godot --headless --path . res://tests/balance_bot.tscn -- runs=20
```

The first one runs 62 checks on the game rules. The second plays whole runs with a bot and prints how each one went, which is useful after changing `balance.gd`.

## Not in the prototype yet

- Art and sound. There's no woodcut style, no music and no sound effects.
- The kratt shows timers and a fuse bar. In the real game it should twitch, smoke and glow instead.
- Only one visitor (the pastor), no special days, and 4 days instead of 6.
- No saving, settings or real tutorial. The title screen has the short rules.
- No web build yet. The project already uses the Compatibility renderer, so Project > Export > Web works once the export templates are installed.
