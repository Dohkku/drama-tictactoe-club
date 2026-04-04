extends "res://editor/graph/base_graph_node.gd"

## Non-functional annotation node. Colored box with text.

var comment_text: String = "Nota..."
var comment_color: Color = Color(0.3, 0.3, 0.35, 0.6)
var _text_edit: TextEdit = null


func _init() -> void:
	super._init()
	accent_color = GraphThemeC.COLOR_COMMENT


func _ready() -> void:
	title = "NOTA"
	custom_minimum_size = Vector2(200, 80)
	super._ready()

	_text_edit = TextEdit.new()
	_text_edit.text = comment_text
	_text_edit.custom_minimum_size = Vector2(180, 60)
	_text_edit.placeholder_text = "Escribe una nota..."
	_text_edit.add_theme_font_size_override("font_size", GraphThemeC.FONT_SIZE_SMALL)
	_text_edit.add_theme_color_override("font_color", GraphThemeC.COLOR_TEXT)
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = comment_color
	bg_style.set_corner_radius_all(4)
	_text_edit.add_theme_stylebox_override("normal", bg_style)
	_text_edit.text_changed.connect(_on_text_changed)
	add_child(_text_edit)


func get_node_type() -> String:
	return "comment"


func get_node_data() -> Dictionary:
	return {
		"comment_text": comment_text,
		"comment_color": comment_color.to_html(true),
	}


func set_node_data(data: Dictionary) -> void:
	comment_text = data.get("comment_text", "")
	if data.has("comment_color"):
		comment_color = Color.from_string(data.comment_color, comment_color)
	if _text_edit:
		_text_edit.text = comment_text


func _on_text_changed() -> void:
	comment_text = _text_edit.text
