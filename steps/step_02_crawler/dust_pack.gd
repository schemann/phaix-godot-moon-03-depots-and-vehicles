extends Node3D
## The Dust Pack on the player's back. What the brush takes goes in here, up to its capacity; a full pack takes nothing more.
## It counts in bytes of the mask, like the moon, so it holds exactly what left the mask.

signal changed

const BYTES_PER_KG := 255 * 1000 ## One full pixel is one gram (moon.gd), so a kilogram is 255000 bytes.

@export var capacity_kg := 2.0

var bytes := 0 ## What the pack holds.

## How many more bytes fit in.
func room() -> int:
	return roundi(capacity_kg * BYTES_PER_KG) - bytes

func add(taken: int) -> void:
	if taken > 0:
		bytes += taken
		changed.emit()

func is_full() -> bool:
	return room() <= 0

func kilograms() -> float:
	return bytes / float(BYTES_PER_KG)

## Empties the pack and returns what it held.
func take_all() -> int:
	var all := bytes
	bytes = 0
	changed.emit()
	return all

## A bigger pack: more room, the same dust inside.
func upgrade(kg: float) -> void:
	capacity_kg = kg
	changed.emit()
