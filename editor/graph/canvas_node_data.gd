class_name CanvasNodeData
extends Resource

## Serializable data for a single node on the canvas.

## Unique ID within the canvas (generated on creation).
@export var node_id: String = ""

## Node type: "start", "end", "character", "match", "cutscene",
## "board_config", "simultaneous", "canvas_instance", "comment"
@export var node_type: String = ""

## Position on the canvas (GraphNode.position_offset).
@export var position: Vector2 = Vector2.ZERO

## Type-specific configuration (serialized as dict).
@export var config: Dictionary = {}

## For nodes that reference external resources (character .tres, .dscn scripts, etc.)
@export var ref_path: String = ""
