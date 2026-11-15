@tool
extends MultiMeshInstance3D
## Stones on the moon: one rock model, many copies, a fixed seed. Scenery; nothing in the tutorial depends on them.
## The rock is Boulder_A of models/rocks.glb, our own rock models; the material of the Rocks node colours it.

const COUNT := 900
const REACH := 90.0
const ROCKS := preload("res://models/rocks.glb")
const ROCK_WIDTH := 1.4 ## Metres across Boulder_A: the copies are scaled from it.

@export var moon_surface: Node3D

func _ready() -> void:
	await get_tree().process_frame
	var copies := MultiMesh.new()
	copies.transform_format = MultiMesh.TRANSFORM_3D
	copies.mesh = _rock()
	copies.instance_count = COUNT
	var random := RandomNumberGenerator.new()
	random.seed = 41
	for i in COUNT:
		var angle := random.randf() * TAU
		var distance := pow(random.randf(), 0.7) * REACH + 5.0
		var size := pow(random.randf(), 7.0) * 1.3 + 0.05
		if distance < 13.5:
			size = min(size, 0.32)
		var x := cos(angle) * distance
		var z := sin(angle) * distance
		var at := Vector3(x, moon_surface.height_at(x, z), z)
		var turn := Vector3((random.randf() - 0.5) * 0.4, random.randf() * TAU, (random.randf() - 0.5) * 0.4)
		var basis_now := Basis.from_euler(turn).scaled(Vector3.ONE * size / ROCK_WIDTH)
		copies.set_instance_transform(i, Transform3D(basis_now, at))
	multimesh = copies

## The mesh of one rock of the model file, its origin under its middle where it rests on the ground.
func _rock() -> Mesh:
	var rocks: Node3D = ROCKS.instantiate()
	var mesh: Mesh = (rocks.get_node("Boulder_A") as MeshInstance3D).mesh
	rocks.free()
	return mesh
