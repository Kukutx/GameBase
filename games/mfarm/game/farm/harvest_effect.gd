class_name MFarmHarvestEffect
extends CPUParticles2D

## The burst a harvest action shows: leaves, stone chips or cut grass.

const TEXTURES := {
	MFarmCropData.Effect.LEAVES_GREEN: preload("res://game/unity/art/Items/Tree01/Tree01_Leaves.tres"),
	MFarmCropData.Effect.LEAVES_ORANGE: preload("res://game/unity/art/Items/Tree02/Tree02_Leaves.tres"),
	MFarmCropData.Effect.ROCK: preload("res://game/unity/art/Items/Rocks/Rock_Harvest.tres"),
	MFarmCropData.Effect.GRASS: preload("res://game/unity/art/Items/Grass/Grass_Particale.tres"),
}

static func spawn(parent: Node, effect: MFarmCropData.Effect, at: Vector2) -> void:
	if not TEXTURES.has(effect):
		return
	var particles := MFarmHarvestEffect.new()
	particles.texture = TEXTURES[effect]
	particles.position = at
	particles.z_index = 300
	particles.z_as_relative = false
	var leaves := effect == MFarmCropData.Effect.LEAVES_GREEN or effect == MFarmCropData.Effect.LEAVES_ORANGE
	particles.amount = 10
	particles.lifetime = 1.0
	particles.one_shot = true
	particles.explosiveness = 0.9
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	particles.emission_rect_extents = Vector2(24, 12) if leaves else Vector2(6, 4)
	particles.direction = Vector2.UP
	particles.spread = 20.0 if leaves else 60.0
	particles.initial_velocity_min = 0.0 if leaves else 30.0
	particles.initial_velocity_max = 10.0 if leaves else 60.0
	particles.gravity = Vector2(0, 60) if leaves else Vector2(0, 220)
	particles.angular_velocity_min = -90.0
	particles.angular_velocity_max = 90.0
	particles.scale_amount_min = 0.6
	particles.scale_amount_max = 1.0
	particles.finished.connect(particles.queue_free)
	parent.add_child(particles)
	particles.emitting = true
