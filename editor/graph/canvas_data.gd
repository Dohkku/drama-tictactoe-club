class_name CanvasData
extends Resource

## Serializable canvas state for the node-based editor.
## Stores all nodes, connections, and view state.
## Can be saved as .tres and instanced inside other canvases.

@export var canvas_name: String = ""
@export var nodes: Array[Resource] = []       # Array[CanvasNodeData]
@export var connections: Array[Resource] = []  # Array[CanvasConnectionData]
@export var scroll_offset: Vector2 = Vector2.ZERO
@export var zoom: float = 1.0

## For sub-canvas instancing: which internal ports are exposed to the parent.
@export var exposed_inputs: Array[Dictionary] = []   # [{name, type, node_id, port}]
@export var exposed_outputs: Array[Dictionary] = []  # [{name, type, node_id, port}]
