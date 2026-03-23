class_name CharacterData
extends Resource

@export var character_id: String = ""
@export var display_name: String = ""
@export var color: Color = Color.WHITE
@export var expressions: Dictionary = {}  # {expression_name: Color}
@export var piece_type: String = "O"

## Default placement style for board pieces (slam, gentle, spinning, etc.)
@export var default_style: String = "gentle"

## Default body pose when entering a scene
@export var default_pose: String = "idle"

## Available body poses with metadata for future animation system
## { pose_name: { "description": String, "energy": float, "openness": float } }
## energy: 0.0=calm to 1.0=intense — drives animation speed/amplitude
## openness: 0.0=closed/defensive to 1.0=open/welcoming — drives posture
@export var poses: Dictionary = {}

## Default look direction ("left", "right", "center", "away")
@export var default_look: String = "center"
