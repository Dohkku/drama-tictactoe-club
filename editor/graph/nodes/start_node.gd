extends "res://editor/graph/base_graph_node.gd"

## Entry point node. Single flow output.


func _init() -> void:
	super._init()
	accent_color = GraphThemeC.COLOR_START


func _ready() -> void:
	title = "INICIO"
	super._ready()

	var spacer := _make_label("  ")
	add_child(spacer)
	add_flow_output(0)


func get_node_type() -> String:
	return "start"
