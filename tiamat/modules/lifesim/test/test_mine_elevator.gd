extends GutTest

## The mine's elevator: the floors it stops at, and the list it shows the
## player when it stops at more than one.

const ELEVATOR_SCENE := preload("res://tiamat/modules/lifesim/mining/mine_elevator.tscn")

var _world_snapshot: Dictionary

func before_each() -> void:
	_world_snapshot = WorldState.to_save_data()
	WorldState.clear()
	MineState.enter_from_surface()

func after_each() -> void:
	InputLock.clear()
	WorldState.load_save_data(_world_snapshot)

func _elevator() -> MineElevator:
	var elevator := ELEVATOR_SCENE.instantiate() as MineElevator
	add_child_autofree(elevator)
	return elevator

func test_the_elevator_stops_at_floor_one_and_each_checkpoint_reached() -> void:
	var elevator := _elevator()
	assert_eq(elevator.get_stops(), PackedInt32Array())
	assert_false(elevator.interactable.enabled, "no stop before the first checkpoint")
	assert_eq(elevator.label.text, "Elevator locked")
	MineState.set_floor(4)
	assert_eq(elevator.get_stops(), PackedInt32Array([1]))
	assert_eq(elevator.label.text, "Elevator ↑ F1")
	MineState.set_floor(5)
	MineState.set_floor(1)
	assert_eq(elevator.get_stops(), PackedInt32Array([5]), "the floor the player is on is no stop")
	assert_eq(elevator.label.text, "Elevator → F5")

func test_with_several_stops_the_player_picks_the_floor() -> void:
	MineState.set_floor(12)
	var elevator := _elevator()
	assert_eq(elevator.get_stops(), PackedInt32Array([1, 5, 10]))
	assert_eq(elevator.label.text, "Mine Elevator")
	elevator.interactable.interacted.emit(null)
	var menu := elevator.get_choice_menu()
	assert_true(menu.is_open())
	assert_eq(menu.get_buttons().map(func(button: Button) -> String: return button.text), ["Floor 1", "Floor 5", "Floor 10"])
	assert_true(menu.get_button(&"1").has_focus(), "deep in the mine, the way up first")
	menu.close()
	assert_eq(MineState.get_current_floor(), 12, "closing the list rides nowhere")
	MineState.set_floor(1)
	elevator.interactable.interacted.emit(null)
	assert_true(menu.get_button(&"10").has_focus(), "at the top, the deepest stop first")
	assert_true(menu.choose(&"10"))
	assert_eq(MineState.get_current_floor(), 1, "an elevator in no mine rides nowhere")
	assert_false(elevator.ride_to(7), "a floor it does not stop at")
