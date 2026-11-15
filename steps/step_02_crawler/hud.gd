extends CanvasLayer
## How much dust the brush has taken, how clean the tile is, what the Dust Pack holds and the Scrip you have.
## At the bottom, what E does: get out of the vehicle, place the machine you hold, or use the machine within reach.

@export var moon: Node3D
@export var player: Node3D

@onready var dust: Label = $Panel/Dust
@onready var clean: Label = $Panel/Clean
@onready var in_pack: Label = $Panel/Pack
@onready var money: Label = $Panel/Scrip
@onready var prompt: Label = $Prompt

func _ready() -> void:
	moon.dust_changed.connect(_show)
	player.pack.changed.connect(_show)
	player.scrip_changed.connect(_show)
	_show()

func _show() -> void:
	dust.text = "DUST  %.1f kg" % moon.kilograms()
	clean.text = "CLEAN  %.1f %%" % moon.clean_percent()
	in_pack.text = "PACK  %.1f / %.1f kg" % [player.pack.kilograms(), player.pack.capacity_kg]
	money.text = "SCRIP  %d" % player.scrip

func _process(_delta: float) -> void:
	var machine: Node3D = player.vehicle if player.vehicle != null else player.placer if player.placer.scene != null else player.station()
	prompt.text = machine.prompt(player) if machine != null else ""
