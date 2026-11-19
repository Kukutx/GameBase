extends Node2D

## An instance `test_node_pool.gd` pools: it counts how often it was taken.

var takes := 0

func reuse() -> void:
	takes += 1
