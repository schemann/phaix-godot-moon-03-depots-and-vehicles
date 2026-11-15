extends CharacterBody3D
## A walker on the moon: mouse or right stick to look, WASD or left stick to walk, Space to jump. Gravity is the moon's, 1.62.
## The Dust Pack on its back holds what the brush takes, and E uses the machine within reach.

const SPEED := 3.2
const ACCELERATION := 9.0
const JUMP := 2.4
const GRAVITY := 1.62
const MOUSE_SENSITIVITY := 0.0025
const STICK_SPEED := 2.4
const REACH := 3.5 ## Metres from the middle of a machine at which E reaches it: its front and the brush head ahead of you both stay clear of it.

signal scrip_changed

@export var moon: Node3D

@onready var camera: Camera3D = $Camera
@onready var pack: Node3D = $Pack
@onready var brush: Node3D = $Camera/Brush

var scrip := 0 ## Money: the Lofters pay it, the Tool Locker takes it.

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event.is_action_pressed("interact") and station() != null:
		station().use(self)
	elif event.is_action_pressed("capture_mouse"):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		look(-event.relative.x * MOUSE_SENSITIVITY, -event.relative.y * MOUSE_SENSITIVITY)

func look(yaw: float, pitch: float) -> void:
	rotate_y(yaw)
	camera.rotation.x = clampf(camera.rotation.x + pitch, deg_to_rad(-80.0), deg_to_rad(70.0))

func _physics_process(delta: float) -> void:
	var stick := Input.get_vector("look_left", "look_right", "look_up", "look_down")
	look(-stick.x * STICK_SPEED * delta, -stick.y * STICK_SPEED * delta)
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var wanted := (transform.basis * Vector3(input.x, 0.0, input.y)) * SPEED
	velocity.x = move_toward(velocity.x, wanted.x, ACCELERATION * delta)
	velocity.z = move_toward(velocity.z, wanted.z, ACCELERATION * delta)
	if is_on_floor():
		if Input.is_action_just_pressed("jump"):
			velocity.y = JUMP
	else:
		velocity.y -= GRAVITY * delta
	move_and_slide()

## The machine within reach: the first of the group "stations" closer than REACH, or null.
func station() -> Node3D:
	for machine: Node3D in get_tree().get_nodes_in_group("stations"):
		if global_position.distance_to(machine.global_position) < REACH:
			return machine
	return null

func pay(amount: int) -> void:
	scrip += amount
	scrip_changed.emit()

## Pays `price` if there is enough Scrip, and says whether it did.
func spend(price: int) -> bool:
	if scrip < price:
		return false
	scrip -= price
	scrip_changed.emit()
	return true
