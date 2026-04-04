extends "res://editor/graph/base_graph_node.gd"

## Character definition node.
## Output: Character port (connects to MatchNode.opponent, SimultaneousNode.opponent).
## Shows portrait thumbnail, character name, and color stripe.

const CharacterDataScript = preload("res://characters/character_data.gd")

var character_data: Resource = null  # CharacterData
var _portrait_rect: TextureRect = null
var _name_label: Label = null
var _id_label: Label = null


func _init() -> void:
	super._init()
	accent_color = GraphThemeC.COLOR_CHARACTER_NODE


func _ready() -> void:
	title = "PERSONAJE"
	custom_minimum_size.x = 180
	super._ready()

	# Row 0: portrait + info column
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)

	_portrait_rect = TextureRect.new()
	_portrait_rect.custom_minimum_size = Vector2(56, 56)
	_portrait_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	_portrait_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	hbox.add_child(_portrait_rect)

	var info_vbox := VBoxContainer.new()
	info_vbox.add_theme_constant_override("separation", 2)
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	_name_label = _make_label("Sin nombre", GraphThemeC.FONT_SIZE_NORMAL, GraphThemeC.COLOR_TEXT)
	info_vbox.add_child(_name_label)

	_id_label = _make_dim_label("id: ???")
	info_vbox.add_child(_id_label)

	hbox.add_child(info_vbox)
	add_child(hbox)

	# Port: character output on row 0
	add_character_output(0)

	# Apply initial data if set
	if character_data:
		_refresh_display()


func get_node_type() -> String:
	return "character"


func get_node_data() -> Dictionary:
	if character_data == null:
		return {}
	return {
		"character_id": character_data.character_id,
		"display_name": character_data.display_name,
	}


func set_node_data(data: Dictionary) -> void:
	if character_data == null:
		character_data = CharacterDataScript.new()
	character_data.character_id = data.get("character_id", "")
	character_data.display_name = data.get("display_name", "")
	_refresh_display()


func set_character(data: Resource) -> void:
	character_data = data
	if is_inside_tree():
		_refresh_display()


func _refresh_display() -> void:
	if character_data == null:
		return

	var display: String = character_data.display_name if character_data.display_name != "" else character_data.character_id
	if _name_label:
		_name_label.text = display
		_name_label.add_theme_color_override("font_color", character_data.color if character_data.color != Color.BLACK else GraphThemeC.COLOR_TEXT)
	if _id_label:
		_id_label.text = "id: %s" % character_data.character_id
	if _portrait_rect and character_data.portrait_image:
		_portrait_rect.texture = character_data.portrait_image

	# Update accent to character color
	if character_data.color != Color.BLACK and character_data.color != Color.WHITE:
		accent_color = character_data.color
		_apply_base_theme()
