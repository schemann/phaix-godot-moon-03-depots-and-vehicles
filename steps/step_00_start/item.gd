extends Resource
## One row of the Tool Locker, as data: its name, its price, and the tool it puts in your hand, or a bigger Dust Pack.
## The tool scene carries its own footprint, so a new tool is a new file here and no new code.

@export var title := ""
@export var price := 0
@export var tool: PackedScene
@export var capacity_kg := 0.0 ## Above zero: the Dust Pack grows to this, instead of a new tool.
