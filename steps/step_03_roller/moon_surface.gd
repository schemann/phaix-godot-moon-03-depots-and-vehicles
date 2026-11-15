@tool
extends Node3D
## Bright Basin: one square of the moon, a crater with a rim. Every height comes from one function, height_at().

const TILE_METRES := 32.0 ## Metres along one side of the tile.
const TILE_CELLS := 512 ## Grid cells along one side: one vertex for every pixel of the dust mask, so the mask can lift the ground.
const FAR_METRES := 960.0 ## The land around the tile; nobody walks there.
const FAR_CELLS := 240 ## 4 m cells: a vertex lies on every edge of the tile, so the land meets the tile without a gap.
const RIM_RADIUS := 13.0
const RIM_HEIGHT := 1.5
const DEPTH := 1.2
const CRATERS := [ ## Small impacts inside the bowl: x, z, radius, depth.
	Vector4(-7.0, -4.5, 2.2, 0.34), Vector4(5.5, -7.0, 1.5, 0.24), Vector4(7.5, 3.5, 2.6, 0.38), Vector4(-3.0, -9.0, 1.2, 0.18),
	Vector4(2.0, -2.5, 0.9, 0.14), Vector4(-8.5, 5.0, 1.4, 0.2), Vector4(10.0, -4.0, 1.1, 0.16), Vector4(0.5, 9.0, 1.7, 0.26),
]

const PADS := [ ## Where a machine stands the ground is level, so every foot of it touches: x, z, half sides and height of each pad, in metres.
	{x = 1.86, z = 3.5, hx = 1.82, hz = 1.19, y = -1.25},
	{x = -3.5, z = 3.84, hx = 1.1, hz = 0.76, y = -1.21}
]
const PAD_BLEND := 1.5 ## Metres over which a pad meets the ground around it.

@export var material: Material

var _hills := FastNoiseLite.new()
var _bumps := FastNoiseLite.new()

func _ready() -> void:
	_hills.seed = 3
	_hills.frequency = 0.0045
	_bumps.seed = 5
	_bumps.frequency = 0.14
	_add_mesh("Ground", _grid(TILE_METRES, TILE_CELLS, 0.0))
	_add_mesh("Land", _grid(FAR_METRES, FAR_CELLS, 1.0))
	if not Engine.is_editor_hint():
		_add_collision()

## The crater: a shallow bowl, a soft rim, gentle hills outside, and a level pad under each machine.
func height_at(x: float, z: float) -> float:
	var r := Vector2(x, z).length() / RIM_RADIUS
	var bowl := -DEPTH * (1.0 - smoothstep(0.0, 1.0, r * r))
	var rim := RIM_HEIGHT * exp(-pow((r - 1.0) / 0.22, 2.0))
	var far := smoothstep(1.1, 6.0, r) * _hills.get_noise_2d(x, z) * 34.0
	var dents := 0.0
	for crater: Vector4 in CRATERS:
		var d := Vector2(x - crater.x, z - crater.y).length() / crater.z
		dents += crater.w * (exp(-pow((d - 1.0) / 0.3, 2.0)) * 0.55 - exp(-d * d * 1.6))
	var ground := bowl + rim + far + dents + _bumps.get_noise_2d(x, z) * 0.14
	for pad: Dictionary in PADS:
		var outside := maxf(absf(x - float(pad.x)) - float(pad.hx), absf(z - float(pad.z)) - float(pad.hz))
		ground = lerpf(float(pad.y), ground, smoothstep(0.0, PAD_BLEND, outside))
	return ground

## Which way the ground faces at x, z: height_at half a metre to each side, so a brush head a metre wide lies on it.
func normal_at(x: float, z: float) -> Vector3:
	var e := 0.5
	return Vector3(height_at(x - e, z) - height_at(x + e, z), 2.0 * e, height_at(x, z - e) - height_at(x, z + e)).normalized()

func _grid(metres: float, cells: int, drop: float) -> ArrayMesh:
	var mesh_tool := SurfaceTool.new()
	mesh_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cell := metres / cells
	for j in cells + 1:
		for i in cells + 1:
			var x := -metres / 2.0 + i * cell
			var z := -metres / 2.0 + j * cell
			var under_the_tile := absf(x) < TILE_METRES / 2.0 and absf(z) < TILE_METRES / 2.0
			mesh_tool.set_uv(Vector2(x, z))
			mesh_tool.add_vertex(Vector3(x, height_at(x, z) - (drop if under_the_tile else 0.0), z))
	for j in cells:
		for i in cells:
			var a := j * (cells + 1) + i
			var b := a + 1
			var c := a + cells + 1
			var d := c + 1
			for index: int in [a, b, c, b, d, c]:
				mesh_tool.add_index(index)
	mesh_tool.generate_normals()
	mesh_tool.generate_tangents()
	return mesh_tool.commit()

func _add_mesh(mesh_name: String, mesh: ArrayMesh) -> void:
	var instance := MeshInstance3D.new()
	instance.name = mesh_name
	instance.mesh = mesh
	instance.material_override = material
	add_child(instance)

func _add_collision() -> void:
	var heights := PackedFloat32Array()
	heights.resize((TILE_CELLS + 1) * (TILE_CELLS + 1))
	var cell := TILE_METRES / TILE_CELLS
	for j in TILE_CELLS + 1:
		for i in TILE_CELLS + 1:
			heights[j * (TILE_CELLS + 1) + i] = height_at(-TILE_METRES / 2.0 + i * cell, -TILE_METRES / 2.0 + j * cell)
	var shape := HeightMapShape3D.new()
	shape.map_width = TILE_CELLS + 1
	shape.map_depth = TILE_CELLS + 1
	shape.map_data = heights
	var collision := CollisionShape3D.new()
	collision.shape = shape
	var body := StaticBody3D.new()
	body.scale = Vector3(cell, 1.0, cell)
	body.add_child(collision)
	add_child(body)
