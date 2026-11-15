extends Node3D
## The Tool Locker sells its row in order, one item after the other, like a ladder: E buys the next one once you have the Scrip.
## Its screen shows what is for sale.

@export var row: Array[Resource] = []

@onready var screen: Label3D = $Screen/Text

var next := 0 ## The row item for sale.

func _ready() -> void:
	add_to_group("stations")
	_show()

## What E does here, for the HUD.
func prompt(player: Node3D) -> String:
	if next >= row.size():
		return "Sold out"
	var item: Resource = row[next]
	if player.scrip < item.price:
		return "%s costs %d Scrip" % [item.title, item.price]
	return "E  Buy the %s, %d Scrip" % [item.title, item.price]

## E: pay, and the new tool is in your hand, or the pack is bigger.
func use(player: Node3D) -> void:
	if next >= row.size() or not player.spend(row[next].price):
		return
	var item: Resource = row[next]
	if item.tool != null:
		player.brush.equip(item.tool)
	if item.capacity_kg > 0.0:
		player.pack.upgrade(item.capacity_kg)
	next += 1
	_show()

func _show() -> void:
	screen.text = "SOLD OUT" if next >= row.size() else "%s\n%d SCRIP" % [row[next].title.to_upper(), row[next].price]
