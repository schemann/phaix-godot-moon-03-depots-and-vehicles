extends CharacterBody3D
## A vehicle you drive. E at it puts you in the seat and E again gets you out; W and S drive, A and D steer, the mouse turns the camera around it.
## It stands on the moon under its wheels: as high as their ground is and tilted as that ground leans, each wheel set on the ground under it.
## While it drives its Head cleans a lane as wide as its footprint, with the same sweep as the brush, into a Dust Pack of its own. Stopped beside a
## Dustwell, it unloads into it.

@export var moon: Node3D
@export var speed := 1.8 ## Top speed in m/s.
@export var turn := 0.8 ## Radians a second it turns at top speed.
@export var stance := Vector2(1.68, 1.64) ## Where it stands on the ground: metres between its wheels across and along.
@export var wheel_radius := 0.395 ## Metres, for the wheels that turn as it drives.
@export var footprint := Vector2(3.0, 0.5) ## What its Head cleans: metres across and along the way it drives.

const SPEED_UP := 1.2 ## Seconds it takes from standing to top speed, and back.
const CHASE := Vector3(2.0, 3.6, -7.5) ## The camera: behind it, a little to its left and above, in its own turn.
const FOLLOW := 4.0 ## How fast the camera catches up: each second it closes all but exp(-FOLLOW) of the way.
const GLIDE_IN := 1.6 ## Seconds the camera's pull takes to come up to FOLLOW after you get in, so the view leaves your eyes gently.
const MOUSE_SENSITIVITY := 0.0025
const OUT := Vector3(2.6, 0.0, 0.0) ## Where you step out: beside its left side.
const HANDOVER := 0.8 ## Seconds the camera takes to glide back to your eyes when you get out.
const ROLLER_RADIUS := 0.27 ## Metres: the Crawler's roller.
const UNLOAD := 4.0 ## Kilograms a second that go into a Dustwell while it stands beside one.
const UNLOAD_REACH := 5.0 ## Metres from its middle to a Dustwell's at which it unloads.

@onready var camera: Camera3D = $Camera
@onready var figure: Node3D = $Figure ## The driver, seated at the model's Seat marker: shown only while someone drives.
@onready var head: Node3D = $Model/Head
@onready var pack: Node3D = $Pack ## Its own Dust Pack: what the Head takes goes in here, as far as there is room.
@onready var puff: GPUParticles3D = $Puff
@onready var gauge: Node3D = get_node_or_null("Model/Crawler/Fill") ## The strip on its side that shows how full it is.
@onready var roller: Node3D = get_node_or_null("Model/Crawler/Roller") ## Turns while the Head cleans.

var driver: Node3D = null ## Who sits in it, or null.
var yaw := 0.0 ## Where its front points: the model's +Z, turned about the moon's up.
var _speed := 0.0 ## m/s along its front, negative in reverse.
var _orbit := 0.0 ## The mouse's turn of the camera around it.
var _leaving: Node3D = null ## Who just got out: the camera glides to their eyes, then hands over.
var _from := Transform3D() ## Where that glide started.
var _glide := 0.0 ## How far a glide has come, back to your eyes or in behind it: 0.0 to 1.0.
var _wheels: Array[Node] = []
var _last := Vector3.INF ## Where the Head was one tick ago.

func _ready() -> void:
	add_to_group("stations")
	yaw = rotation.y
	_wheels = find_children("Wheel_*", "Node3D", true, false)
	pack.changed.connect(_show)
	_stand(0.0)
	_show()

## What E does here, for the HUD.
func prompt(_player: Node3D) -> String:
	return "E  Get out" if driver != null else "E  Drive the %s" % name

## E: into the seat. The walker is put away and the camera behind the vehicle takes over.
func use(player: Node3D) -> void:
	driver = player
	player.drive(self)
	_orbit = 0.0
	_leaving = null
	_glide = 0.0
	camera.global_transform = player.camera.global_transform ## it starts at your eyes, and _chase glides it back behind
	camera.make_current()

func _unhandled_input(event: InputEvent) -> void:
	if driver == null:
		return
	if event.is_action_pressed("interact"): ## E again: out of the seat, beside it
		get_viewport().set_input_as_handled()
		_leaving = driver
		_from = camera.global_transform
		_glide = 0.0
		driver.leave(self, global_transform * OUT)
		driver = null
	elif event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_orbit -= event.relative.x * MOUSE_SENSITIVITY

func _physics_process(delta: float) -> void:
	figure.visible = driver != null or _leaving != null ## it sits there until the camera is back at your eyes
	var throttle := 0.0
	var steer := 0.0
	if driver != null:
		throttle = Input.get_axis("move_back", "move_forward")
		steer = Input.get_axis("move_right", "move_left")
		_orbit -= Input.get_axis("look_left", "look_right") * 2.4 * delta
	_speed = move_toward(_speed, throttle * speed, speed / SPEED_UP * delta)
	yaw += steer * turn * delta * _speed / speed ## it turns only while it moves, like wheels do
	var front := Vector3(sin(yaw), 0.0, cos(yaw))
	var from := global_position
	velocity = front * _speed
	move_and_slide()
	_speed = velocity.dot(front) ## a machine in the way stops it
	var moved := from.distance_to(global_position) * signf(_speed)
	_stand(moved)
	_clean(moved)
	_unload(delta)
	if _leaving != null:
		_hand_back(delta)
	else:
		_chase(delta)

## The Head on the ground: from where it was one tick ago to where it is now, one sweep of the footprint, at most what fits into the pack.
func _clean(moved: float) -> void:
	var point := head.global_position
	point.y = moon.surface.height_at(point.x, point.z)
	if _last != Vector3.INF and moved != 0.0:
		pack.add(moon.sweep(_last, point, global_basis.z, footprint, false, 255, pack.room()))
	_last = point
	puff.global_transform = Transform3D(global_basis, point)
	puff.emitting = absf(moved) > 0.0 and not pack.is_full()
	if roller != null:
		roller.rotate_x(-moved / ROLLER_RADIUS * 2.0) ## twice as fast as it drives, against the way it goes

## Standing still beside a Dustwell, the pack goes into it, UNLOAD kilograms a second.
func _unload(delta: float) -> void:
	if absf(_speed) > 0.05 or pack.bytes == 0:
		return
	for machine: Node3D in get_tree().get_nodes_in_group("stations"):
		if machine.has_method("store") and global_position.distance_to(machine.global_position) < UNLOAD_REACH:
			machine.store(pack.take(roundi(UNLOAD * pack.BYTES_PER_KG * delta)))
			return

func _show() -> void:
	if gauge != null:
		gauge.scale.y = clampf(pack.kilograms() / pack.capacity_kg, 0.001, 1.0)

## The body on the ground under its wheels: as high as their ground is on average and tilted as it leans along and across, and each wheel set
## on the ground under it. `moved` is the metres it drove this tick, which turn the wheels.
func _stand(moved: float) -> void:
	var flat := Basis(Vector3.UP, yaw)
	var x := stance.x / 2.0
	var z := stance.y / 2.0
	var left_front := _ground(flat * Vector3(x, 0.0, z))
	var right_front := _ground(flat * Vector3(-x, 0.0, z))
	var left_back := _ground(flat * Vector3(x, 0.0, -z))
	var right_back := _ground(flat * Vector3(-x, 0.0, -z))
	var lean := Vector3(-(left_front + left_back - right_front - right_back) / 2.0 / stance.x, 1.0, -(left_front + right_front - left_back - right_back) / 2.0 / stance.y)
	var up := (flat * lean).normalized()
	var front := (flat.z - up * flat.z.dot(up)).normalized()
	var height := (left_front + right_front + left_back + right_back) / 4.0
	global_transform = Transform3D(Basis(up.cross(front), up, front), Vector3(global_position.x, height, global_position.z))
	for wheel: Node3D in _wheels:
		var at: Vector3 = global_transform * Vector3(wheel.position.x, 0.0, wheel.position.z)
		var centre := Vector3(at.x, moon.surface.height_at(at.x, at.z) + wheel_radius, at.z)
		wheel.position.y = (global_transform.affine_inverse() * centre).y
		wheel.rotate_x(moved / wheel_radius)

## The height of the moon at a point given from the vehicle's middle.
func _ground(offset: Vector3) -> float:
	return moon.surface.height_at(global_position.x + offset.x, global_position.z + offset.z)

## The camera behind it, a moment late: it closes the gap by 1 - exp(-FOLLOW * delta) each tick, so it moves the same at any frame rate,
## and it never goes under the ground. Right after you get in, its pull eases in over GLIDE_IN, so the view never jumps from your eyes.
func _chase(delta: float) -> void:
	_glide = minf(_glide + delta / GLIDE_IN, 1.0)
	var want := global_position + Basis(Vector3.UP, yaw + _orbit) * CHASE
	want.y = maxf(want.y, moon.surface.height_at(want.x, want.z) + 1.0)
	camera.global_position = camera.global_position.lerp(want, (1.0 - exp(-FOLLOW * delta)) * smoothstep(0.0, 1.0, _glide))
	camera.look_at(global_position + Vector3.UP * 1.2)

## Out of the seat: the camera glides from behind the vehicle to your eyes in HANDOVER, eased, and there you show again and your own camera takes over.
func _hand_back(delta: float) -> void:
	var eyes: Camera3D = _leaving.camera
	_glide = minf(_glide + delta / HANDOVER, 1.0)
	camera.global_transform = _from.interpolate_with(eyes.global_transform, smoothstep(0.0, 1.0, _glide))
	if _glide >= 1.0:
		_leaving.show() ## only now: on the way, the brush and the pack would hang in the air beside the vehicle
		eyes.make_current()
		_leaving = null
