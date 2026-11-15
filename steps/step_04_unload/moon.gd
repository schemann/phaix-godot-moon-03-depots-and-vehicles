extends Node3D
## The moon of this tutorial: one surface, one dust tile, and the count of what was cleaned. The brush talks to it, the HUD listens.

signal dust_changed

const DustTile := preload("dust_tile.gd")
const GRAMS_PER_FULL_PIXEL := 1.0
const ALL := DustTile.FULL * DustTile.PIXELS * DustTile.PIXELS ## No limit: every byte of the tile.

@onready var surface: Node3D = $Surface
@onready var stones: GeometryInstance3D = $Rocks

var tile: RefCounted = DustTile.new()
var removed := 0 ## Bytes taken from the mask so far.
var bare := 0 ## Bytes of the mask under the pads: bare from the start, so there is nothing to clean there.
var _dirty := false

func _ready() -> void:
	## No dust lies under a machine: its pad is bare rock, taken from the mask without counting (nothing was cleaned, the dust is not in the pack).
	for pad: Dictionary in surface.PADS:
		bare += tile.stamp(Vector3(float(pad.x), 0.0, float(pad.z)), Vector3.FORWARD, Vector2(float(pad.hx) * 2.0, float(pad.hz) * 2.0), false, DustTile.FULL)
	tile.upload()
	surface.material.set_shader_parameter("dust_mask", tile.texture)
	## The stones read the same mask, so their shader lifts them as high as the dust under them.
	stones.material_override.set_shader_parameter("dust_mask", tile.texture)

## One stamp of the tool's head where the brush is, at most `limit` bytes. It returns what it took.
func clean(point: Vector3, heading: Vector3, size: Vector2, round_head: bool, amount: int, limit := ALL) -> int:
	var taken: int = tile.stamp(point, heading, size, round_head, amount, Vector3.INF, limit)
	_count(taken)
	return taken

## A stroke from one point to another: stamps along the line, half the head's shorter side apart, so that a fast hand leaves no gaps.
## Each stamp knows where the one before it stood and takes only the ground that one did not cover, so a pass takes `amount` once.
## Every stamp gets the room the stamps before it left, so the whole stroke takes at most `limit`. It returns what it took.
func sweep(from: Vector3, to: Vector3, heading: Vector3, size: Vector2, round_head: bool, amount: int, limit := ALL) -> int:
	var stamps := ceili(from.distance_to(to) / (minf(size.x, size.y) * 0.5))
	var taken := 0
	for i in range(1, stamps + 1):
		var before := from.lerp(to, float(i - 1) / stamps)
		taken += tile.stamp(from.lerp(to, float(i) / stamps), heading, size, round_head, amount, before, limit - taken)
	_count(taken)
	return taken

## What the stamps took goes to removed, and the HUD hears of it, only when anything left the mask.
func _count(taken: int) -> void:
	if taken > 0:
		removed += taken
		_dirty = true
		dust_changed.emit()

func _process(_delta: float) -> void:
	if _dirty:
		_dirty = false
		tile.upload()

## How much dust lies at x, z: 1.0 for a full layer, 0.0 for bare rock.
func dust_at(x: float, z: float) -> float:
	var px := clampi(int((x / DustTile.METRES + 0.5) * DustTile.PIXELS), 0, DustTile.PIXELS - 1)
	var pz := clampi(int((z / DustTile.METRES + 0.5) * DustTile.PIXELS), 0, DustTile.PIXELS - 1)
	return tile.bytes[pz * DustTile.PIXELS + px] / float(DustTile.FULL)

func kilograms() -> float:
	return removed / float(DustTile.FULL) * GRAMS_PER_FULL_PIXEL / 1000.0

func clean_percent() -> float:
	return 100.0 * removed / float(ALL - bare)
