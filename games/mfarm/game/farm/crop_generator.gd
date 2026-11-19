extends Node2D

## A crop the scene places on the land (a tree, a rock): the first time its
## location loads, it plants `seed_id`, `growth_days` grown, on its cell, which
## the land (`Farmland`) then keeps like any other crop. It leaves the scene
## either way: the location's `MFarmFarmGrid` draws the crop.

@export var seed_id: StringName
@export var growth_days := 0

func _ready() -> void:
	var location_id := MFarmLocation.id_of(self)
	var key := MFarmLocation.key_of(self)
	if location_id != &"" and seed_id != &"" and not Farmland.is_generated(location_id, key):
		Farmland.plant(location_id, MFarmMapData.cell_of(global_position), seed_id, growth_days, true)
		Farmland.mark_generated(location_id, key)
	queue_free()
