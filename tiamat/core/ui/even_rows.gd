class_name EvenRows
extends Node

## Keeps the buttons of a `GridContainer` in rows as full as each other: all
## in one row while they are `most` or fewer, else in as few rows as hold them
## with as many in each (four in two rows of two, not three and one).
##
## A child of the grid. It counts again whenever a button is shown, hidden,
## added or taken away, so a menu that offers no achievements, a web build
## that cannot quit, or a pause menu whose pages come and go keeps its rows
## even.

## The most buttons a row holds.
@export var most := 3

func _ready() -> void:
	var grid := get_parent()
	grid.child_entered_tree.connect(_on_child_entered)
	# A child leaving is still the grid's as it says so.
	grid.child_exiting_tree.connect(func(_child: Node) -> void: balance.call_deferred())
	for child: Node in grid.get_children():
		_watch(child)
	balance()

func _on_child_entered(child: Node) -> void:
	_watch(child)
	balance()

func _watch(child: Node) -> void:
	var control := child as Control
	if control != null and not control.visibility_changed.is_connected(balance):
		control.visibility_changed.connect(balance)

## Gives the grid the columns that keep the buttons it shows now in even rows.
func balance() -> void:
	var grid := get_parent() as GridContainer
	if grid == null:
		return
	var shown := 0
	for child: Node in grid.get_children():
		if child is Control and (child as Control).visible:
			shown += 1
	grid.columns = columns_for(shown, most)

## The columns that put `count` buttons in even rows of at most `most`.
static func columns_for(count: int, most: int) -> int:
	var rows := maxi(1, ceili(float(count) / maxi(1, most)))
	return maxi(1, ceili(float(count) / rows))
