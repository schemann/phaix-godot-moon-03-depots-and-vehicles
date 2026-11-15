extends SceneTree
## Headless tests for godot-moon-03. From the repository root:
##   godot --headless --path godot-moon/03-depots-and-vehicles -s res://tests/run_tests.gd
## Prints PASS or FAIL per test and exits with 0 only if every test passed. `-- --only=text` runs the tests whose name contains the text.

const STEPS: Array[String] = ["step_00_start", "step_01_place", "step_02_crawler", "step_03_roller", "step_04_unload"]
const FINAL := "step_04_unload"
const Tile := preload("res://steps/step_04_unload/dust_tile.gd")
const DustPack := preload("res://steps/step_04_unload/dust_pack.gd")
const Placer := preload("res://steps/step_04_unload/placer.gd")
const Vehicle := preload("res://steps/step_04_unload/vehicle.gd")

## What each step adds to the one before.
const NEW_FILES: Dictionary[String, Array] = {
	"step_01_place": ["dustwell.tscn", "dustwell.tres", "placer.gd"],
	"step_02_crawler": ["crawler.tscn", "vehicle.gd"],
	"step_03_roller": [],
	"step_04_unload": [],
}

var _failed := 0
var _only := ""

func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--only="):
			_only = argument.trim_prefix("--only=")
	_all.call_deferred()

func _all() -> void:
	for test: Callable in [
		_the_locker_sells_the_dustwell_last, _a_dustwell_waits_for_clean_ground, _a_dustwell_keeps_its_distance, _a_dustwell_stays_off_steep_ground,
		_a_placed_dustwell_stands_on_its_foundation, _a_placed_dustwell_takes_the_pack_and_launches,
		_e_gets_you_in_and_out, _the_driver_sits_only_while_driving, _the_camera_stays_clear_of_the_driver, _the_seat_empties_out_of_view, _e_reaches_the_nearest_machine, _the_crawler_drives_and_turns, _the_crawler_stands_on_its_wheels, _the_crawler_stops_at_a_machine,
		_the_roller_clears_its_lane, _the_load_stops_at_the_vehicle_pack, _a_stop_at_a_dustwell_unloads,
		_every_step_adds_its_files, _every_step_loads, _no_light_shows_a_warning_triangle, _every_scene_is_on_jolt,
	]:
		if _only.is_empty() or test.get_method().contains(_only):
			await test.call()
	print("RESULT %s" % ("PASS" if _failed == 0 else "FAIL %d" % _failed))
	quit(0 if _failed == 0 else 1)

func _check(name_of_test: String, ok: bool, detail := "") -> void:
	print("%s %s %s" % ["PASS" if ok else "FAIL", name_of_test, detail])
	if not ok:
		_failed += 1

func _scene(step := FINAL) -> Node:
	var scene: Node = (load("res://steps/%s/main.tscn" % step) as PackedScene).instantiate()
	root.add_child(scene)
	return scene

func _drop(scene: Node) -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for action: String in ["move_forward", "move_back", "move_left", "move_right", "brush"]:
		Input.action_release(action)
	scene.queue_free()
	await process_frame
	await process_frame

func _ticks(count: int) -> void:
	for i in count:
		await physics_frame

## The player stands at x, z looking along yaw (0 looks along -Z).
func _stand(scene: Node, x: float, z: float, yaw: float) -> Node3D:
	var player: Node3D = scene.get_node("Player")
	player.global_position = Vector3(x, scene.get_node("Moon/Surface").height_at(x, z) + 0.05, z)
	player.rotation.y = yaw
	player.velocity = Vector3.ZERO
	return player

## The ground ahead of the player cleaned: a square of `size` metres around the point `ahead` metres ahead.
func _clean_ahead(scene: Node, player: Node3D, ahead: float, size: float) -> void:
	var at: Vector3 = player.global_transform * Vector3(0.0, 0.0, -ahead)
	scene.get_node("Moon").clean(at, Vector3.FORWARD, Vector2(size, size), false, Tile.FULL)

## The Tool Locker sells the Dustwell after the three tools of tutorial 02, for 40 Scrip, and E gives you its ghost to hold; it stays for sale.
func _the_locker_sells_the_dustwell_last() -> void:
	var scene := _scene()
	await physics_frame
	var player: Node3D = _stand(scene, -3.4, 0.9, PI)
	var locker: Node3D = scene.get_node("Locker")
	var titles: Array[String] = []
	for item: Resource in locker.row:
		titles.append(item.title)
	locker.next = 3
	locker._show()
	player.pay(40)
	locker.use(player)
	var first: bool = player.scrip == 0 and player.placer.scene != null
	player.placer.ghost.free()
	player.placer.scene = null
	player.pay(40)
	locker.use(player)
	_check("the Locker sells the Dustwell last, again and again", titles == ["Widebar", "Dust Pack 4 kg", "Rotary Scrubber", "Dustwell"] and first
		and player.scrip == 0 and player.placer.scene != null and locker.next == 3 and locker.screen.text == "DUSTWELL\n40 SCRIP",
		"row %s, scrip %d, holding %s, still for sale: %s" % [titles, player.scrip, player.placer.scene, locker.screen.text.replace("\n", " ")])
	await _drop(scene)

## The ghost stands ahead of you; on dust it is red and E places nothing; on cleaned ground it is green.
func _a_dustwell_waits_for_clean_ground() -> void:
	var scene := _scene()
	await physics_frame
	var player: Node3D = _stand(scene, -1.0, 2.0, 0.0)
	player.placer.hold(load("res://steps/%s/dustwell.tscn" % FINAL))
	await _ticks(2)
	var on_dust: String = player.placer.why
	var red: Color = player.placer._look.albedo_color
	var before := scene.get_tree().get_nodes_in_group("stations").size()
	player.placer.place()
	var placed_on_dust := scene.get_tree().get_nodes_in_group("stations").size() - before
	_clean_ahead(scene, player, Placer.AHEAD, 5.0)
	await _ticks(2)
	var on_clean: String = player.placer.why
	var green: Color = player.placer._look.albedo_color
	_check("a Dustwell waits for clean ground", on_dust == "Clean the ground first" and red == Placer.BAD and placed_on_dust == 0 and on_clean == "" and green == Placer.GOOD,
		"on dust \"%s\", placed %d; on cleaned ground \"%s\"" % [on_dust, placed_on_dust, on_clean])
	await _drop(scene)

## Not within SPACE of another machine: the ghost in front of the first Dustwell is red.
func _a_dustwell_keeps_its_distance() -> void:
	var scene := _scene()
	await physics_frame
	var player: Node3D = _stand(scene, 2.0, -5.0, PI) ## looking along +Z: the ghost's middle at z 0.5, 3 m before the first Dustwell's
	player.placer.hold(load("res://steps/%s/dustwell.tscn" % FINAL))
	_clean_ahead(scene, player, Placer.AHEAD, 6.0)
	await _ticks(2)
	var near: String = player.placer.why
	_check("a Dustwell keeps its distance", near == "Too close to another machine", "3 m from the Dustwell: \"%s\"" % near)
	await _drop(scene)

## Steep rock: on the crater's rim the rock under the footprint rises more than MAX_RISE.
func _a_dustwell_stays_off_steep_ground() -> void:
	var scene := _scene()
	await physics_frame
	var player: Node3D = _stand(scene, 0.0, -6.0, 0.0) ## the ghost on the north slope of the rim
	player.placer.hold(load("res://steps/%s/dustwell.tscn" % FINAL))
	_clean_ahead(scene, player, Placer.AHEAD, 6.0)
	await _ticks(2)
	_check("a Dustwell stays off steep ground", player.placer.why == "The ground is too steep here", "on the rim: \"%s\"" % player.placer.why)
	await _drop(scene)

## Placed: a real Dustwell stands where the ghost stood, in the group stations, its feet on a level foundation whose top is the highest rock under the
## footprint and whose bottom is below the lowest; the foundation has a body on layer 3, and the ghost is gone.
func _a_placed_dustwell_stands_on_its_foundation() -> void:
	var scene := _scene()
	await physics_frame
	var player: Node3D = _stand(scene, -1.0, 2.0, 0.0)
	player.placer.hold(load("res://steps/%s/dustwell.tscn" % FINAL))
	_clean_ahead(scene, player, Placer.AHEAD, 5.0)
	await _ticks(2)
	var where: Transform3D = player.placer.ghost.global_transform
	player.placer.place()
	await _ticks(2)
	var placed: Node3D = null
	for machine: Node3D in scene.get_tree().get_nodes_in_group("stations"):
		if machine.global_position.distance_to(where.origin) < 0.01:
			placed = machine
	var surface: Node3D = scene.get_node("Moon/Surface")
	var high := -INF
	var low := INF
	var box: Rect2 = placed.get_meta("footprint") if placed != null else Rect2()
	for x in range(0, 34):
		for z in range(0, 21):
			var point := where * Vector3(box.position.x + x * 0.1, 0.0, box.position.y + z * 0.1)
			high = maxf(high, surface.height_at(point.x, point.z))
			low = minf(low, surface.height_at(point.x, point.z))
	var slab: MeshInstance3D = placed.find_children("*", "MeshInstance3D", false, false).back() if placed != null else null
	var top: float = slab.global_position.y + slab.mesh.size.y / 2.0 if slab != null else INF
	var bottom: float = slab.global_position.y - slab.mesh.size.y / 2.0 if slab != null else INF
	var body: StaticBody3D = slab.get_child(0) if slab != null else null
	_check("a placed Dustwell stands on its foundation", placed != null and player.placer.scene == null and absf(top - where.origin.y) < 0.001
		and absf(top - high) < 0.05 and bottom < low - 0.2 and body != null and body.collision_layer == 4,
		"top %.3f, rock %.3f to %.3f, bottom %.3f" % [top, low, high, bottom])
	await _drop(scene)

## The placed Dustwell is a Dustwell like the first: E empties the pack into it and E again launches its Lofter and pays.
func _a_placed_dustwell_takes_the_pack_and_launches() -> void:
	var scene := _scene()
	await physics_frame
	var player: Node3D = _stand(scene, -1.0, 2.0, 0.0)
	player.placer.hold(load("res://steps/%s/dustwell.tscn" % FINAL))
	_clean_ahead(scene, player, Placer.AHEAD, 5.0)
	await _ticks(2)
	player.placer.place()
	await _ticks(2)
	var placed: Node3D = scene.get_tree().get_nodes_in_group("stations").back()
	player.pack.add(DustPack.BYTES_PER_KG * 2)
	placed.use(player)
	var stored: int = placed.stored
	placed.use(player)
	_check("a placed Dustwell takes the pack and launches", stored == DustPack.BYTES_PER_KG * 2 and player.pack.bytes == 0 and player.scrip == 10 and placed.stored == 0,
		"stored %d, scrip %d" % [stored, player.scrip])
	await _drop(scene)

## Into a vehicle of `scene` (bought first in the steps that sell it): the player beside it presses E.
func _get_in(scene: Node, vehicle: Node3D) -> Node3D:
	var player: Node3D = scene.get_node("Player")
	if "owned" in vehicle:
		vehicle.owned = true
	vehicle.use(player)
	return player

## E reaches the nearest machine in reach, not the first one the group lists: 2.3 m from the Crawler and about 3.4 m from the Dustwell
## both are within REACH and it is the Crawler; with no machine within REACH there is none.
func _e_reaches_the_nearest_machine() -> void:
	var scene := _scene()
	await physics_frame
	var crawler: Node3D = scene.get_node("Crawler")
	var well: Node3D = scene.get_node("Dustwell")
	var from := Vector2(crawler.global_position.x, crawler.global_position.z)
	var at := from + (Vector2(well.global_position.x, well.global_position.z) - from).normalized() * 2.3
	var player: Node3D = _stand(scene, at.x, at.y, 0.0)
	var both: bool = player.global_position.distance_to(crawler.global_position) < player.REACH and player.global_position.distance_to(well.global_position) < player.REACH
	var nearest: Node3D = player.station()
	_stand(scene, 0.0, -9.0, 0.0)
	var none: Node3D = player.station()
	_check("E reaches the nearest machine", both and nearest == crawler and none == null, "both in reach %s, nearest %s, far from everything %s" % [both, nearest, none])
	await _drop(scene)

## Drives for `seconds` with the throttle and the steering held as given (1.0 full ahead, 1.0 full left).
func _drive(throttle: float, steer: float, seconds: float) -> void:
	for pair: Array in [["move_forward", "move_back", throttle], ["move_left", "move_right", steer]]:
		Input.action_release(pair[0])
		Input.action_release(pair[1])
		if pair[2] > 0.0:
			Input.action_press(pair[0], pair[2])
		elif pair[2] < 0.0:
			Input.action_press(pair[1], -pair[2])
	await _ticks(roundi(seconds * 60.0))

## E at the Crawler: the walker is hidden and stopped, the Crawler's camera is the one in use and starts at the walker's eyes, the HUD offers to
## get out; E again puts the walker beside the Crawler's left side, looking the way it looks, and the camera glides back to its eyes in HANDOVER
## and hands over to the walker's own camera. The walker stays hidden while the camera glides and shows at the hand-over: on the way its brush
## and its pack would hang in the air beside the Crawler (series rule 65).
func _e_gets_you_in_and_out() -> void:
	var scene := _scene("step_02_crawler")
	await physics_frame
	var crawler: Node3D = scene.get_node("Crawler")
	var player: Node3D = _stand(scene, 6.0, 1.6, PI / 2.0) ## 2.6 m from the Crawler's middle, beside it
	var reached: Node3D = player.station()
	var eyes: Vector3 = player.camera.global_position
	_get_in(scene, crawler)
	var starts: float = crawler.camera.global_position.distance_to(eyes)
	var step := 0.0 ## the largest step of the camera in one tick while it glides in behind (take_motion: at most 0.5 m a frame of 30 fps)
	var was: Vector3 = crawler.camera.global_position
	for i in roundi(Vehicle.GLIDE_IN * 60.0) + 30:
		await physics_frame
		step = maxf(step, crawler.camera.global_position.distance_to(was))
		was = crawler.camera.global_position
	var inside: bool = player.vehicle == crawler and not player.visible and player.process_mode == Node.PROCESS_MODE_DISABLED and crawler.camera.current
	var prompt: String = crawler.prompt(player)
	var press := InputEventAction.new()
	press.action = "interact"
	press.pressed = true
	Input.parse_input_event(press)
	for i in 3: ## input reaches the nodes once per frame, and a busy frame runs several physics ticks
		await process_frame
	var release := InputEventAction.new()
	release.action = "interact"
	Input.parse_input_event(release)
	var beside: Vector3 = crawler.global_transform.affine_inverse() * player.global_position
	var out: bool = player.vehicle == null and not player.visible and crawler.driver == null ## out, and hidden while the camera glides
	var looks: float = absf(wrapf(player.rotation.y - crawler.yaw - PI, -PI, PI))
	await _ticks(roundi(Vehicle.HANDOVER * 30.0))
	var halfway: float = crawler.camera.global_position.distance_to(player.camera.global_position)
	var gliding: bool = crawler.camera.current and halfway > 0.5 and not player.visible
	await _ticks(roundi(Vehicle.HANDOVER * 30.0) + 2)
	var handed: bool = player.camera.current and crawler._leaving == null and player.visible
	_check("E gets you in and out", reached == crawler and starts < 0.001 and step < 0.2 and inside and prompt == "E  Get out" and out and beside.x > 2.0 and looks < 0.01
		and gliding and handed,
		"reached %s, the camera %.3f m from the eyes at the start and at most %.3f m a tick behind, in %s, prompt \"%s\", out and hidden %s at %s, looking %.3f off, %.2f m from the eyes halfway and hidden %s, handed over and shown %s"
		% [reached, starts, step, inside, prompt, out, beside, looks, halfway, gliding, handed])
	await _drop(scene)

## The driver (Fable review M6 of build 5; Daniel, 2026-11-08: "Fahrer bauen"): one seated figure per vehicle, at the model's Seat marker, hidden while nobody drives,
## shown from E in and kept until the camera is back at the walker's eyes (the walker shows there), so the seat is never empty while the viewer sees it.
func _the_driver_sits_only_while_driving() -> void:
	var scene := _scene()
	await physics_frame
	for vehicle: Node3D in [scene.get_node("Crawler")]:
		var seat: Node3D = vehicle.get_node("Model/Seat")
		var figure: Node3D = vehicle.figure
		var at_the_seat: bool = figure.global_position.distance_to(seat.global_position) < 0.01
		var empty: bool = not figure.visible
		var player := _get_in(scene, vehicle)
		await _ticks(3)
		var seated: bool = figure.visible and vehicle.driver == player
		var press := InputEventAction.new()
		press.action = "interact"
		press.pressed = true
		Input.parse_input_event(press)
		for i in 3:
			await process_frame
		var release := InputEventAction.new()
		release.action = "interact"
		Input.parse_input_event(release)
		await _ticks(roundi(Vehicle.HANDOVER * 30.0))
		var on_the_way: bool = figure.visible and vehicle._leaving != null and not player.visible
		await _ticks(roundi(Vehicle.HANDOVER * 30.0) + 4)
		var gone: bool = not figure.visible and vehicle._leaving == null and player.visible
		_check("the driver sits only while driving (%s)" % vehicle.name, at_the_seat and empty and seated and on_the_way and gone,
			"at the Seat marker %s, hidden before E %s, shown in the seat %s, still shown while the camera glides back %s, gone and the walker shown at the hand-over %s"
			% [at_the_seat, empty, seated, on_the_way, gone])
	await _drop(scene)

## The camera never passes through the driver: at the glide in from beside the vehicle and at the hand-over, from the camera turned round the vehicle by the orbits
## the takes use (-1.0 to 0.9 rad), the camera stays 0.5 m or more from the figure's boxes (the near plane is 0.05 m; series rule 65, nothing hangs in the picture).
func _the_camera_stays_clear_of_the_driver() -> void:
	var scene := _scene()
	await physics_frame
	var worst := INF
	var where := ""
	for vehicle: Node3D in [scene.get_node("Crawler")]:
		for orbit: float in [-1.0, 0.0, 0.9]:
			for side: float in [-1.0, 1.0]:
				var player := _get_in(scene, vehicle)
				player.global_position = vehicle.global_transform * Vector3(side * 2.6, 0.0, 0.0) ## beside it, as the takes get in
				vehicle.camera.global_transform = player.camera.global_transform
				for i in roundi(Vehicle.GLIDE_IN * 60.0):
					await physics_frame
					var gap := _gap_to(vehicle.figure, vehicle.camera.global_position)
					if gap < worst:
						worst = gap
						where = "%s glide in from the %s side" % [vehicle.name, "left" if side > 0.0 else "right"]
				vehicle._orbit = orbit
				await _ticks(10)
				var press := InputEventAction.new()
				press.action = "interact"
				press.pressed = true
				Input.parse_input_event(press)
				for i in 3:
					await process_frame
				var release := InputEventAction.new()
				release.action = "interact"
				Input.parse_input_event(release)
				for i in roundi(Vehicle.HANDOVER * 60.0) + 6:
					await physics_frame
					var gap := _gap_to(vehicle.figure, vehicle.camera.global_position)
					if gap < worst:
						worst = gap
						where = "%s hand-over from orbit %.1f" % [vehicle.name, orbit]
				await _ticks(10)
	_check("the camera stays clear of the driver", worst >= 0.5, "closest %.2f m (%s)" % [worst, where])
	await _drop(scene)

## The seat empties only when the camera no longer looks at it (the narration says so, Daniel's M6 a, rule 69): in the last frame the driver is still shown, at
## the end of the hand-over, neither the walker's camera nor the vehicle's camera has the seat (hip, chest, head) in its view, for the orbits the takes use and for
## both vehicles, from both sides of the seat.
func _the_seat_empties_out_of_view() -> void:
	var scene := _scene()
	await physics_frame
	var seen := 0
	var checked := 0
	var where := ""
	for vehicle: Node3D in [scene.get_node("Crawler")]:
		for orbit: float in [-1.0, 0.0, 0.9]:
			for side: float in [-1.0, 1.0]:
				var player := _get_in(scene, vehicle)
				player.global_position = vehicle.global_transform * Vector3(side * 2.6, 0.0, 0.0)
				await _ticks(roundi(Vehicle.GLIDE_IN * 60.0))
				vehicle._orbit = orbit
				await _ticks(10)
				var press := InputEventAction.new()
				press.action = "interact"
				press.pressed = true
				Input.parse_input_event(press)
				for i in 3:
					await process_frame
				var release := InputEventAction.new()
				release.action = "interact"
				Input.parse_input_event(release)
				var last_in_view := false
				var last_frame := -1
				for i in roundi(Vehicle.HANDOVER * 60.0) + 12:
					await physics_frame
					if vehicle.figure.visible:
						last_frame = i
						last_in_view = false
						for height: float in [0.1, 0.5, 0.9]:
							var point: Vector3 = vehicle.figure.global_position + Vector3(0.0, height, 0.0)
							if vehicle.camera.is_position_in_frustum(point) or player.camera.is_position_in_frustum(point):
								last_in_view = true
				checked += 1
				if last_frame < 0 or last_in_view:
					seen += 1
					where = "%s, orbit %.1f, %s side, last shown frame %d" % [vehicle.name, orbit, "left" if side > 0.0 else "right", last_frame]
				await _ticks(10)
	_check("the seat empties only when the camera no longer looks at it", seen == 0 and checked == 6, "%d of %d hand-overs ended with the seat in view or never showed the driver (%s)" % [seen, checked, where])
	await _drop(scene)

## The distance from `point` to the boxes of the meshes under `figure`.
func _gap_to(figure: Node3D, point: Vector3) -> float:
	var least := INF
	for mesh: MeshInstance3D in figure.find_children("*", "MeshInstance3D", true, false):
		var box: AABB = mesh.global_transform * mesh.get_aabb()
		var inside := Vector3(maxf(maxf(box.position.x - point.x, 0.0), point.x - box.end.x), maxf(maxf(box.position.y - point.y, 0.0), point.y - box.end.y),
			maxf(maxf(box.position.z - point.z, 0.0), point.z - box.end.z))
		least = minf(least, inside.length())
	return least

## The Crawler drives at its speed, 1.8 m/s, and turns only while it moves: full left at a standstill does not turn it.
func _the_crawler_drives_and_turns() -> void:
	var scene := _scene("step_02_crawler")
	await physics_frame
	var crawler: Node3D = scene.get_node("Crawler")
	_get_in(scene, crawler)
	var yaw0: float = crawler.yaw
	await _drive(0.0, 1.0, 1.0)
	var turned_standing: float = absf(crawler.yaw - yaw0)
	var start: Vector3 = crawler.global_position
	await _drive(1.0, 0.0, 3.0)
	var from: Vector3 = crawler.global_position
	await _drive(1.0, 0.0, 1.0)
	var top: float = Vector2(crawler.global_position.x - from.x, crawler.global_position.z - from.z).length()
	var yaw1: float = crawler.yaw
	await _drive(1.0, 1.0, 1.0)
	var turned: float = crawler.yaw - yaw1
	_check("the Crawler drives and turns", turned_standing < 0.001 and absf(top - 1.8) < 0.05 and absf(turned - 0.8) < 0.05 and start.distance_to(from) > 3.0,
		"turned %.3f rad standing, %.2f m in the fourth second, %.3f rad in a second full left at speed" % [turned_standing, top, turned])
	await _drop(scene)

## Series rule 65: every wheel on the ground while the Crawler drives over the crater floor, its small crater at (2.0, -2.5) included.
func _the_crawler_stands_on_its_wheels() -> void:
	var scene := _scene("step_02_crawler")
	await physics_frame
	var crawler: Node3D = scene.get_node("Crawler")
	var surface: Node3D = scene.get_node("Moon/Surface")
	_get_in(scene, crawler)
	var worst := 0.0
	Input.action_press("move_forward")
	for i in 360:
		await physics_frame
		for wheel: Node3D in crawler.find_children("Wheel_*", "Node3D", true, false):
			var lowest: float = wheel.global_position.y - crawler.wheel_radius
			worst = maxf(worst, absf(lowest - surface.height_at(wheel.global_position.x, wheel.global_position.z)))
	_check("the Crawler stands on its wheels", worst < 0.01 and crawler.global_position.x < 0.0, "a wheel off the rock by %.4f m at most, at x %.2f" % [worst, crawler.global_position.x])
	await _drop(scene)

## Series rule 41: a vehicle does not drive through a machine; driven at the Tool Locker it stops at it.
func _the_crawler_stops_at_a_machine() -> void:
	var scene := _scene("step_02_crawler")
	await physics_frame
	var crawler: Node3D = scene.get_node("Crawler")
	var locker: Node3D = scene.get_node("Locker")
	crawler.global_position = Vector3(-3.5, crawler.global_position.y, -3.0)
	crawler.yaw = 0.0 ## its front along +Z, at the Locker
	_get_in(scene, crawler)
	await _drive(1.0, 0.0, 6.0)
	var front: float = crawler.global_position.z + 2.5
	_check("the Crawler stops at a machine", front < locker.global_position.z - 0.4, "its front at z %.2f, the Locker's middle at z %.2f" % [front, locker.global_position.z])
	await _drop(scene)

## Step 3: the Crawler's Head clears a lane 3 m wide behind it with the same sweep as the brush; its own pack holds what left the mask.
func _the_roller_clears_its_lane() -> void:
	var scene := _scene("step_03_roller")
	await physics_frame
	var crawler: Node3D = scene.get_node("Crawler")
	var moon: Node3D = scene.get_node("Moon")
	_get_in(scene, crawler)
	await _drive(1.0, 0.0, 4.0)
	var x: float = crawler.global_position.x + 3.5 ## behind it: it drives along -X
	var cleared := 0
	var z := -4.0
	while z <= 2.0:
		if moon.dust_at(x, z) < 0.1:
			cleared += 1
		z += 0.05
	var width: float = cleared * 0.05
	_check("the roller clears its lane", absf(width - 3.0) < 0.15 and crawler.pack.bytes == moon.removed and moon.removed > 0,
		"a lane %.2f m wide, the pack %d bytes, the mask lost %d" % [width, crawler.pack.bytes, moon.removed])
	await _drop(scene)

## A full vehicle pack takes nothing more: the lane stops where the pack is full.
func _the_load_stops_at_the_vehicle_pack() -> void:
	var scene := _scene("step_03_roller")
	await physics_frame
	var crawler: Node3D = scene.get_node("Crawler")
	var moon: Node3D = scene.get_node("Moon")
	crawler.pack.add(crawler.pack.room() - 20000)
	_get_in(scene, crawler)
	await _drive(1.0, 0.0, 4.0)
	_check("the load stops at the vehicle pack", crawler.pack.is_full() and moon.removed == 20000 and not crawler.puff.emitting,
		"the mask lost %d, the pack is %s" % [moon.removed, "full" if crawler.pack.is_full() else "not full"])
	await _drop(scene)

## The original's rule: a vehicle that stops at the dump empties into it. Stopped beside the Dustwell the Crawler's load goes in, 4 kg a second; driving
## past it, nothing does.
func _a_stop_at_a_dustwell_unloads() -> void:
	var scene := _scene("step_04_unload")
	await physics_frame
	var crawler: Node3D = scene.get_node("Crawler")
	var dustwell: Node3D = scene.get_node("Dustwell")
	crawler.global_position = Vector3(7.0, crawler.global_position.y, 2.5) ## 4.6 m from the Dustwell's middle, its front 1 m clear of it
	crawler.pack.add(DustPack.BYTES_PER_KG * 6)
	_get_in(scene, crawler)
	await _ticks(60)
	var after_one: float = dustwell.kilograms()
	await _ticks(60)
	var after_two: float = dustwell.kilograms()
	_check("a stop at a Dustwell unloads", absf(after_one - 4.0) < 0.1 and absf(after_two - 6.0) < 0.001 and crawler.pack.bytes == 0,
		"%.2f kg in after one second, %.2f kg after two, the pack holds %d" % [after_one, after_two, crawler.pack.bytes])
	await _drop(scene)

func _every_step_adds_its_files() -> void:
	for i in range(1, STEPS.size()):
		var step := STEPS[i]
		if not DirAccess.dir_exists_absolute("res://steps/" + step):
			_check("%s exists" % step, false)
			continue
		var before := DirAccess.open("res://steps/" + STEPS[i - 1]).get_files()
		var after := DirAccess.open("res://steps/" + step).get_files()
		var added: Array[String] = []
		for file in after:
			if file not in before and not file.ends_with(".uid"):
				added.append(file)
		added.sort()
		var wanted: Array = NEW_FILES[step].duplicate()
		wanted.sort()
		_check("%s adds %s" % [step, str(wanted)], str(added) == str(wanted), str(added))

func _every_step_loads() -> void:
	for step in STEPS:
		var scene := _scene(step)
		await _ticks(4)
		var player: Node = scene.get_node("Player")
		var ground: float = scene.get_node("Moon/Surface").height_at(0.0, 6.0)
		var view: Camera3D = player.get_viewport().get_camera_3d()
		_check("%s loads and starts at the player's eyes" % step, player.camera != null and absf(ground) < 3.0 and view == player.camera,
			"ground=%.2f, the view is %s" % [ground, str(view.get_path()) if view != null else "none"])
		await _drop(scene)

## The editor draws a yellow triangle on a Light3D whose scale is not 1 (godot-moon-01): the engine's own test on every light of every step.
func _no_light_shows_a_warning_triangle() -> void:
	for step in STEPS:
		var scene: Node = (load("res://steps/%s/main.tscn" % step) as PackedScene).instantiate()
		var lights := scene.find_children("*", "Light3D", true, false)
		var warned: Array[String] = []
		for light: Light3D in lights:
			if not light.scale.is_equal_approx(Vector3.ONE):
				warned.append("%s scale %s" % [scene.get_path_to(light), light.scale])
		_check("%s: no light shows a warning triangle" % step, not lights.is_empty() and warned.is_empty(), "%d light(s) %s" % [lights.size(), str(warned)])
		scene.free()

func _every_scene_is_on_jolt() -> void:
	var engine: String = ProjectSettings.get_setting("physics/3d/physics_engine")
	_check("every scene is on Jolt", engine == "Jolt Physics", engine)
