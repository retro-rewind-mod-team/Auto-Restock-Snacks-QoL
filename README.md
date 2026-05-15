# Auto Restock Snacks – QoL

**Version:** 1.7  
**Game:** Retro Rewind Video Store Simulator  
**Requires:** UE4SS v3.0.1

---

## What it does

Automatically restocks snack shelves, fridges, and candy dispensers so you never
have to fill them by hand.

- Restocks everything when you open the store via the Open/Closed sign
- Optionally restocks again at one or more configured in-game hours
- Deducts the purchase cost from your funds (configurable)
- Refills candy dispensers using the game's native logic, which correctly
  handles revenue and fill animation

---

## Requirements

- UE4SS v3.0.1

---

## Installation

1. Copy the mod folder into your UE4SS `Mods/` directory.
2. Open `main.lua` and adjust the `CONFIG` block at the top to your liking.
3. Load your save and open the store — restocking happens automatically.

---

## Configuration

All options are at the top of `main.lua` inside the `CONFIG` table.

| Option         | Default   | Description |
|----------------|-----------|-------------|
| `restockHours` | `{ 18 }`  | Additional in-game hours at which a second restock runs. Set to `{}` to disable. |
| `deductCost`   | `true`    | Deducts the purchase cost of restocked snacks from your funds. Set to `false` for free restocking. |
| `restockCandy` | `true`    | Includes candy dispensers in the restock. Set to `false` to skip them. |
| `Debug`        | `false`   | Logs hook registration details and internal errors to the UE4SS console. |

### Examples

Restock at store open and again at 18:00 (default):
```lua
restockHours = { 18 },
```

Restock at 15:00 and 19:00, no cost deduction:
```lua
restockHours  = { 15, 19 },
deductCost    = false,
```

Disable all scheduled restocks (open only):
```lua
restockHours = {},
```

---

## How it works

**Shelf and fridge restock**  
Hooks the `OpenSign: Change Sign` event to detect when the store opens. The
actual restock runs one timer tick later (via `WeatherSystem: Timer Event – Add
one minute`) to ensure all shelf actors are fully loaded. For each snack pack,
the mod reads the current container count, calls `Return Snack Base Save Struct`
to get the pack's save data, overrides `Numberofsnack` with the live count, then
calls `Spawn and Fill Snack` to fill it to 100 %.

**Cost deduction**  
Before filling, the mod counts empty slots and reads the pack's sale price and
`Stock Price Off` ratio to calculate the purchase price per unit. The total cost
across all packs is deducted in a single `Change Money` call after all shelves
have been processed.

**Candy dispensers**  
Uses the game's native `Refill by Player` function — the same path triggered by
manual player interaction. This correctly updates the fill material and handles
any internal revenue tracking the game applies.

**Scheduled restocks**  
Additional hours in `restockHours` are checked every minute. A restock only
fires if the current hour matches, the minute is 0, the store has been opened
that day, and the hour has not already been restocked. All daily trackers reset
at end-of-day and on save reload.

---

## Known limitations

- The shelf restock runs synchronously and may cause a brief freeze of roughly
  0.5 seconds on larger stores. This is a technical constraint — asynchronous
  execution causes garbage-collection crashes on NPC references and is not used.
- Realtime snack restocking via `BTTask_Parallel-Snack` hooks is not supported
  in this version. Navigating from a snack object to its pack via `GetOuter()`
  currently returns Blackboard key addresses instead of real object references.

---

## Changelog

### 1.7
- Candy dispensers now use the native `Refill by Player` function instead of
  direct property writes. This removes the need for manual
  `CandyEmptynessNormalize` and `MoneyinBank` manipulation and aligns the
  refill path with standard game behaviour.

### 1.6 and earlier
- Partial-fill bug fixed: `Return Snack Base Save Struct` returns a flat struct;
  `Numberofsnack` is now set to the live container count before calling
  `Spawn and Fill Snack`.
- Gamemode reference cached to avoid repeated `FindAllOf` calls on hot paths.
- Daily tracker reset added for end-of-day and save-reload events.

## License
Shield: [![CC BY-NC-SA 4.0][cc-by-nc-sa-shield]][cc-by-nc-sa]

This work is licensed under a
[Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License][cc-by-nc-sa].

[![CC BY-NC-SA 4.0][cc-by-nc-sa-image]][cc-by-nc-sa]

[cc-by-nc-sa]: http://creativecommons.org/licenses/by-nc-sa/4.0/
[cc-by-nc-sa-image]: https://licensebuttons.net/l/by-nc-sa/4.0/88x31.png
[cc-by-nc-sa-shield]: https://img.shields.io/badge/License-CC%20BY--NC--SA%204.0-lightgrey.svg
