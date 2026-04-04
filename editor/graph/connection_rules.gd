class_name ConnectionRules
extends RefCounted

## Validates graph connections and detects cycles.

const GraphThemeC = preload("res://editor/graph/graph_theme.gd")


## Returns true if a connection between the given port types is valid.
static func is_valid_connection(from_type: int, to_type: int) -> bool:
	return from_type == to_type


## Check if adding a flow connection from -> to would create a cycle.
## graph_edit: the GraphEdit node containing the graph.
## from_node_name: StringName of the source GraphNode.
## to_node_name: StringName of the target GraphNode.
static func would_create_cycle(graph_edit: GraphEdit, from_node_name: StringName, to_node_name: StringName) -> bool:
	if from_node_name == to_node_name:
		return true
	# BFS from to_node following existing flow connections to see if we reach from_node.
	var visited: Dictionary = {}
	var queue: Array[StringName] = [to_node_name]
	visited[to_node_name] = true
	while not queue.is_empty():
		var current: StringName = queue.pop_front()
		for conn in graph_edit.get_connection_list():
			if conn.from_node == current:
				if conn.from_node == from_node_name or conn.to_node == from_node_name:
					# Only check flow connections for cycles
					var node := graph_edit.get_node(String(conn.from_node)) as GraphNode
					if node:
						var slot_idx: int = conn.from_port
						if node.is_slot_enabled_right(slot_idx) and node.get_slot_type_right(slot_idx) == GraphThemeC.PORT_FLOW:
							if conn.to_node == from_node_name:
								return true
				if conn.from_node == current:
					var node := graph_edit.get_node(String(conn.from_node)) as GraphNode
					if node and node.is_slot_enabled_right(conn.from_port) and node.get_slot_type_right(conn.from_port) == GraphThemeC.PORT_FLOW:
						if not visited.has(conn.to_node):
							visited[conn.to_node] = true
							queue.append(conn.to_node)
	return false


## Validate that a flow output has at most one connection.
static func flow_output_is_free(graph_edit: GraphEdit, from_node_name: StringName, from_port: int) -> bool:
	for conn in graph_edit.get_connection_list():
		if conn.from_node == from_node_name and conn.from_port == from_port:
			return false
	return true


## Validate that a flow input has at most one connection.
static func flow_input_is_free(graph_edit: GraphEdit, to_node_name: StringName, to_port: int) -> bool:
	for conn in graph_edit.get_connection_list():
		if conn.to_node == to_node_name and conn.to_port == to_port:
			return false
	return true
