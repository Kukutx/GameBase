class_name EvenRows
extends Node

## Keeps the buttons of a `GridContainer` in rows as full as each other: all
## in one row while they are `most` or fewer, else in as few rows as hold them
## with as many in each (four in two rows of two, not three and one).
##
## A child of the grid. It counts again whenever a button is shown or hidden,
## so a menu that offers no achievements, or a web build that cannot quit,
## keeps its rows even.

## The most buttons a row holds.
@export var most := 3

func _ready() -> void:
	for child: Node in get_parent().get_children():
		var control := child as Control
		if control != null:
			control.visibility_changed.connect(balance)
	balance()

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
