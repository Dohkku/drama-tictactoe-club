extends "res://editor/graph/base_graph_node.gd"

## Terminal node. Single flow input.


func _init() -> void:
	super._init()
	accent_color = GraphThemeC.COLOR_END


func _ready() -> void:
	title = "FIN"
	custom_minimum_size.x = 100
	super._ready()

	var spacer := _make_dim_label("||")
	spacer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(spacer)
	add_flow_input(0)


func get_node_type() -> String:
	return "end"
