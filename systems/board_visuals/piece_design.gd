class_name PieceDesign
extends Resource

## Defines the visual appearance of a game piece.
## Supports geometric shapes, Unicode text characters, and textures.

@export var design_name: String = ""
## "geometric", "text", or "texture"
@export var design_type: String = "geometric"
## For geometric: "x", "o", "triangle", "square", "star", "diamond"
@export var geometric_shape: String = "x"
## For text: any Unicode string
@export var text_character: String = ""
## For texture type
@export var texture_image: Texture2D = null
## Relative line thickness multiplier
@export var line_width_factor: float = 1.0
## Whether geometric shapes are filled vs outline only
@export var fill: bool = false
## Shape of the piece body: "circle", "rounded_square", "hexagon", "diamond_body", "shield"
@export var body_shape: String = "circle"
## Color for the piece body. Transparent (alpha=0) = use piece_color.
@export var body_color: Color = Color(0, 0, 0, 0)
## Color for the symbol drawn on top. Transparent (alpha=0) = use piece_color.
@export var symbol_color: Color = Color(0, 0, 0, 0)


static func body_shape_names() -> PackedStringArray:
	return PackedStringArray(["circle", "rounded_square", "hexagon", "diamond_body", "shield"])


static func body_shape_labels() -> PackedStringArray:
	return PackedStringArray(["Círculo", "Cuadrado R.", "Hexágono", "Diamante", "Escudo"])


static func _make_geometric(name: String, shape: String, filled: bool = false, width: float = 1.0) -> Resource:
	var d: Resource = load("res://systems/board_visuals/piece_design.gd").new()
	d.design_name = name
	d.design_type = "geometric"
	d.geometric_shape = shape
	d.fill = filled
	d.line_width_factor = width
	return d


static func _make_text(name: String, character: String, width: float = 1.0) -> Resource:
	var d: Resource = load("res://systems/board_visuals/piece_design.gd").new()
	d.design_name = name
	d.design_type = "text"
	d.text_character = character
	d.line_width_factor = width
	return d


static func x_design() -> Resource:
	return _make_geometric("X", "x")

static func o_design() -> Resource:
	return _make_geometric("O", "o")

static func triangle_design() -> Resource:
	return _make_geometric("Triángulo", "triangle")

static func square_design() -> Resource:
	return _make_geometric("Cuadrado", "square")

static func star_design() -> Resource:
	return _make_geometric("Estrella", "star")

static func diamond_design() -> Resource:
	return _make_geometric("Diamante", "diamond")

static func text_design(character: String, name: String) -> Resource:
	return _make_text(name, character)


static func all_designs() -> Array:
	return [
		x_design(),
		o_design(),
		triangle_design(),
		square_design(),
		star_design(),
		diamond_design(),
		text_design("火", "火 Fuego"),
		text_design("龍", "龍 Dragón"),
		text_design("♠", "♠ Pica"),
		text_design("★", "★ Estrella"),
	]
