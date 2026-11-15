extends Node3D
## The Dustwell: walk up to it, press E, and the Dust Pack empties into it. Press E again and a Lofter takes everything
## inside off the moon, and the launch pays Scrip for every kilogram. Its gauge shows how full it is.

const DustPack := preload("dust_pack.gd")
const Lofter := preload("lofter.tscn")
const GAUGE_KG := 10.0 ## The kilograms that fill the gauge on the front to the top.
const SCRIP_PER_KG := 5 ## What one kilogram pays when its Lofter launches.

@onready var gauge: Node3D = $Dustwell/Fill
@onready var socket: Node3D = $LofterSocket

var stored := 0 ## Bytes of dust inside: exactly the bytes the pack held.
var lofter: Node3D = null ## The Lofter in the cradle, ready to fly; null while the next one comes up.

func _ready() -> void:
	add_to_group("stations")
	lofter = _new_lofter(false)
	_show()

## What E does here, for the HUD.
func prompt(player: Node3D) -> String:
	if player.pack.bytes > 0:
		return "E  Empty the Dust Pack"
	if stored > 0 and lofter != null:
		return "E  Launch the Lofter, %.1f kg" % kilograms()
	return "The Dust Pack is empty"

## E: first the pack goes in, then the Lofter flies and pays.
func use(player: Node3D) -> void:
	if player.pack.bytes > 0:
		stored += player.pack.take_all()
	elif stored > 0 and lofter != null:
		player.pay(roundi(kilograms() * SCRIP_PER_KG))
		stored = 0
		_launch(lofter)
		lofter = null
	_show()

## A vehicle unloads here: its bytes of dust go in like the pack's.
func store(bytes: int) -> void:
	stored += bytes
	_show()

func kilograms() -> float:
	return stored / float(DustPack.BYTES_PER_KG)

func _show() -> void:
	gauge.scale.y = clampf(kilograms() / GAUGE_KG, 0.001, 1.0)

## The Lofter lights its flame and climbs straight up, faster and faster, and frees itself far above.
## Three seconds later the next one comes up into the cradle.
func _launch(rocket: Node3D) -> void:
	rocket.get_node("Exhaust").emitting = true
	var flight := create_tween()
	flight.tween_property(rocket, "position:y", 150.0, 8.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	flight.tween_callback(rocket.queue_free)
	var next := create_tween()
	next.tween_interval(3.0)
	next.tween_callback(func() -> void: lofter = _new_lofter(true))

## A Lofter in the cradle. With `rise` it comes up from below the cradle instead of standing there at once.
func _new_lofter(rise: bool) -> Node3D:
	var rocket: Node3D = Lofter.instantiate()
	socket.add_child(rocket)
	if rise:
		rocket.position.y = -1.7
		create_tween().tween_property(rocket, "position:y", 0.0, 2.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	return rocket
