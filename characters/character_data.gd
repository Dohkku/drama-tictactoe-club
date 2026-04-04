class_name CharacterData
extends Resource

@export var character_id: String = ""
@export var display_name: String = ""
@export var color: Color = Color.WHITE

## Base portrait image (fallback if no specific expression image is found)
@export var portrait_image: Texture2D = null

## Map of expression names to specific portrait images
## { "happy": Texture2D, "angry": Texture2D, ... }
@export var expression_images: Dictionary = {}

@export var expressions: Dictionary = {}  # {expression_name: Color}
@export var piece_type: String = "O"

## Default placement style for board pieces (slam, gentle, spinning, etc.)
@export var default_style: String = "gentle"

## Portrait crop — pan offset as fraction (-0.5 to 0.5) within the slot
@export var portrait_offset: Vector2 = Vector2.ZERO

## Portrait crop — zoom level (0.5 = zoomed out, 2.0 = zoomed in)
@export var portrait_zoom: float = 1.0

## Default body pose when entering a scene
@export var default_pose: String = "idle"

## Available body poses with metadata for future animation system
## { pose_name: { "description": String, "energy": float, "openness": float } }
## energy: 0.0=calm to 1.0=intense — drives animation speed/amplitude
## openness: 0.0=closed/defensive to 1.0=open/welcoming — drives posture
@export var poses: Dictionary = {}

## Default look direction ("left", "right", "center", "away")
@export var default_look: String = "center"

## Voice — used by DialogueAudio for per-character typing beeps
@export var voice_pitch: float = 220.0
@export var voice_variation: float = 30.0
@export var voice_waveform: String = "sine"  # "sine", "square", "triangle"

## Dialogue style — per-character dialogue box appearance
@export var dialogue_bg_color: Color = Color(0.1, 0.1, 0.15, 0.9)
@export var dialogue_border_color: Color = Color(0.3, 0.3, 0.4, 1.0)
