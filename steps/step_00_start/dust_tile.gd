extends RefCounted
## One tile of dust: 512 by 512 pixels, one byte each. 255 is a full layer, 0 is bare rock. The bytes on the CPU are the truth, the texture is a copy for the shader.

const PIXELS := 512
const METRES := 32.0
const FULL := 255

var bytes := PackedByteArray()
var image: Image
var texture: ImageTexture

func _init() -> void:
	bytes.resize(PIXELS * PIXELS)
	bytes.fill(FULL)
	image = Image.create_from_data(PIXELS, PIXELS, false, Image.FORMAT_R8, bytes)
	texture = ImageTexture.create_from_image(image)

## Takes dust under the head of a tool: `size` is the head in metres, across and along `heading`, a bar or, with `round_head`, a disc. A pixel on the edge takes its share.
## With `before`, where the stamp before this one stood, it takes only the ground that stamp did not cover.
## `limit` is the most it may take in all, the room left in the Dust Pack; at the limit it stops. It returns how much it took.
func stamp(point: Vector3, heading: Vector3, size: Vector2, round_head: bool, amount: int, before := Vector3.INF, limit := FULL * PIXELS * PIXELS) -> int:
	var scale := PIXELS / METRES
	var along := Vector2(heading.x, heading.z).normalized()
	var across := Vector2(-along.y, along.x)
	var half := size / 2.0
	var cx := (point.x + METRES / 2.0) * scale
	var cy := (point.z + METRES / 2.0) * scale
	var reach := half.length() * scale + 1.0
	var taken := 0
	for y in range(maxi(int(cy - reach), 0), mini(int(cy + reach) + 2, PIXELS)):
		for x in range(maxi(int(cx - reach), 0), mini(int(cx + reach) + 2, PIXELS)):
			var ground := Vector2(x + 0.5, y + 0.5) / scale - Vector2.ONE * METRES / 2.0
			var take := roundi(amount * _cover(ground - Vector2(point.x, point.z), across, along, half, round_head))
			if before != Vector3.INF:
				take -= roundi(amount * _cover(ground - Vector2(before.x, before.z), across, along, half, round_head))
			if take <= 0:
				continue
			var at := y * PIXELS + x
			take = mini(mini(bytes[at], take), limit - taken)
			bytes[at] -= take
			taken += take
			if taken >= limit:
				return taken
	return taken

## How much of a pixel the head covers, from the pixel's offset to the middle of the head: 1 inside, 0 outside, a share on the edge.
func _cover(offset: Vector2, across: Vector2, along: Vector2, half: Vector2, round_head: bool) -> float:
	var pixel := METRES / PIXELS
	if round_head:
		return clampf((half.x - offset.length()) / pixel + 0.5, 0.0, 1.0)
	var inside_across := half.x - absf(offset.dot(across))
	var inside_along := half.y - absf(offset.dot(along))
	return clampf(inside_across / pixel + 0.5, 0.0, 1.0) * clampf(inside_along / pixel + 0.5, 0.0, 1.0)

## Sends the bytes to the texture.
func upload() -> void:
	image.set_data(PIXELS, PIXELS, false, Image.FORMAT_R8, bytes)
	texture.update(image)
