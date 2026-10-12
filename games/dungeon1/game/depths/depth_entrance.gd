class_name DepthEntrance
extends InteractivePortal

## The way down from camp: starts a new run (`DepthRun.start_run()`) and takes
## the player to its first depth.

func _ready() -> void:
	super()
	about_to_travel.connect(DepthRun.start_run)
