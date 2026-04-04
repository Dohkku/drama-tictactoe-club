class_name CanvasConnectionData
extends Resource

## Serializable data for a single connection between nodes.

@export var from_node: String = ""   # node_id of source
@export var from_port: int = 0
@export var to_node: String = ""     # node_id of target
@export var to_port: int = 0
