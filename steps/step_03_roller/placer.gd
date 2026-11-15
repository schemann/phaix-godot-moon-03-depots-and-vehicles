extends Node3D
## Places a machine on the moon. hold() takes its scene; until E puts it down, a see-through copy of it, the ghost, stands on the ground ahead,
## green where it may stand and red where it may not. It may stand only on clean ground, clear of the other machines, on rock its foundation can
## level out. Placed is placed: it never moves again.

const AHEAD := 5.5 ## Metres from the player to the middle of the ghost.
const STEP := 0.5 ## Metres between two looks at the ground under it.
const MAX_DUST := 0.02 ## The share of a full layer that may still lie under it: clean the ground first.
const SPACE := 5.0 ## Metres its middle keeps from every other machine.
const MAX_RISE := 0.4 ## Metres the rock under it may rise from its lowest to its highest point.
const DEPTH := 0.3 ## Metres the foundation reaches below the lowest rock under it.
const MARGIN := 0.2 ## Metres the foundation reaches beyond the footprint on every side.
const GOOD := Color(0.35, 1.0, 0.5, 0.45)
const BAD := Color(1.0, 0.3, 0.25, 0.45)
const CONCRETE := preload("res://materials/foundation.tres")

@onready var moon: Node3D = owner.moon

var scene: PackedScene = null ## The machine you hold, or null.
var ghost: Node3D = null
var slab: MeshInstance3D = null ## The foundation under the ghost: level on top, as deep as the rock under it needs.
var why := "" ## Why the machine may not stand here; empty where it may.
var _footprint := Rect2() ## The ground the machine stands on, in its own space: x and z.
var _look := StandardMaterial3D.new()

## Holds a machine to place: its ghost appears ahead of you.
func hold(machine: PackedScene) -> void:
	scene = machine
	ghost = machine.instantiate()
	_footprint = ghost.get_meta("footprint")
	ghost.set_script(null) ## a copy to look at: it joins no group and launches nothing
	ghost.get_node("Body").free() ## and nothing bumps into it
	_look.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	for mesh: MeshInstance3D in ghost.find_children("*", "MeshInstance3D", true, false):
		mesh.material_override = _look
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	slab = MeshInstance3D.new()
	slab.mesh = BoxMesh.new()
	slab.material_override = _look
	ghost.add_child(slab)
	ghost.top_level = true
	add_child(ghost)

func _physics_process(_delta: float) -> void:
	if scene == null:
		return
	var player: Node3D = owner
	ghost.global_basis = player.global_basis ## its front towards you
	var middle := Vector3(_footprint.get_center().x, 0.0, _footprint.get_center().y)
	ghost.global_position = player.global_transform * Vector3(0.0, 0.0, -AHEAD) - ghost.global_basis * middle
	why = _check()
	_look.albedo_color = GOOD if why.is_empty() else BAD

## Looks at the ground under the footprint every STEP metres, stands the ghost on the highest rock there and sizes its foundation.
## Returns why it may not stand here.
func _check() -> String:
	var low := INF
	var high := -INF
	var dust := 0.0
	var looks := 0
	for x in range(ceili(_footprint.size.x / STEP) + 1):
		for z in range(ceili(_footprint.size.y / STEP) + 1):
			var point := ghost.global_transform * Vector3(_footprint.position.x + x * STEP, 0.0, _footprint.position.y + z * STEP)
			var rock: float = moon.surface.height_at(point.x, point.z)
			low = minf(low, rock)
			high = maxf(high, rock)
			dust += moon.dust_at(point.x, point.z)
			looks += 1
	ghost.global_position.y = high
	var depth := high - low + DEPTH
	slab.mesh.size = Vector3(_footprint.size.x + MARGIN * 2.0, depth, _footprint.size.y + MARGIN * 2.0)
	slab.position = Vector3(_footprint.get_center().x, -depth / 2.0, _footprint.get_center().y)
	if dust / looks > MAX_DUST:
		return "Clean the ground first"
	for machine: Node3D in get_tree().get_nodes_in_group("stations"):
		if machine.global_position.distance_to(slab.global_position) < SPACE:
			return "Too close to another machine"
	if high - low > MAX_RISE:
		return "The ground is too steep here"
	return ""

## What E does here, for the HUD.
func prompt(_player: Node3D) -> String:
	return why if not why.is_empty() else "E  Place the %s" % ghost.name

## E: the machine stands where its ghost stands, on its foundation, and stays there.
func place() -> void:
	if scene == null or not why.is_empty():
		return
	var machine: Node3D = scene.instantiate()
	owner.get_parent().add_child(machine)
	machine.global_transform = ghost.global_transform
	slab.reparent(machine)
	slab.material_override = null
	slab.mesh.material = CONCRETE
	var body := StaticBody3D.new()
	body.collision_layer = 4
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	shape.shape.size = slab.mesh.size
	body.add_child(shape)
	slab.add_child(body)
	ghost.queue_free()
	scene = null
