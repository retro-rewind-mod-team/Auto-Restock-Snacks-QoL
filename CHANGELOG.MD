# Changelog

## 2.0
- Extracted inline `CONFIG` block into a separate `config.lua` for RRMM support
- `restockHours` restructured from a flat integer list (`{ 18 }`) to a table of entries (`{ { hour = 18 } }`) to align with the RRMM YAML schema
- Added `Auto-Restock-Snacks-QoL.yaml` with full config definition for RRMM

## 1.9.1
<!-- TODO -->

## 1.9
<!-- TODO -->

## 1.8
<!-- TODO -->

## 1.7
- Candy dispensers now use the native `Refill by Player` function instead of direct property writes — removes the need for manual `CandyEmptynessNormalize` and `MoneyinBank` manipulation and aligns the refill path with standard game behaviour

## 1.6
- Fixed partial-fill bug: `Return Snack Base Save Struct` returns a flat struct; `Numberofsnack` is now set to the live container count before calling `Spawn and Fill Snack`
- Gamemode reference cached to avoid repeated `FindAllOf` calls on hot paths
- Daily tracker reset added for end-of-day and save-reload events

## 1.5
- Removed unused `cachedWeather` / `getWeather()` — OpenSign hook uses `FindAllOf` directly, Weather hook uses `self:get()`
- `restockShelf` now counts `emptySlots` and `totalSlots` in a single pass over `Snack Container Array` instead of two; `countEmptySlots()` removed
- `IsValid()` guard added before each shelf restock call to handle shelves that despawn between `FindAllOf` and iteration
- Fixed double cost deduction caused by iterating `Snack Container Array` twice per pack
- `restockAllShelves` logs an error when a shelf `pcall` fails
- End-of-day hook now also invalidates `cachedGamemode`, consistent with the begin-play hook

## 1.4
<!-- TODO -->

## 1.3
- Fixed shelves not being fully restocked when partially filled — the mod now always fills to maximum capacity regardless of current stock level

## 1.2
- Fixed multi-day support — restocks now work correctly on consecutive days
- Replaced midnight reset with `End of the day` event for reliable day separation regardless of store closing time

## 1.1
- Fixed the issue with the second restock trigger not firing
- Renamed mod folder from `Auto Restock QoL` to `Auto Restock Snacks QoL`

## 1.0
- Initial release
