extends Sprite2D

## A layer of the player's look (body, hair, arm, tool). The body's walk and
## run clips call `FootstepSound` on each step.

func FootstepSound() -> void:
	GameAudio.play_cue(&"sfx_footstep_soft")
