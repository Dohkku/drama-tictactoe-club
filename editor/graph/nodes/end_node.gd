extends "res://editor/graph/base_graph_node.gd"

## Terminal node. Single flow input.


func _init() -> void:
	super._init()
	accent_color = GraphThemeC.COLOR_END


func _ready() -> void:
	title = "FIN"
	super._ready()

	var spacer := _make_label("  ")
	add_child(spacer)
	add_flow_input(0)


func get_node_type() -> String:
	return "end"
