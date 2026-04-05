extends "res://editor/graph/base_graph_node.gd"

## Single polymorphic node for all cinematic DSL commands.
## Uses category + command dropdowns that reconfigure parameters dynamically.

const POSITIONS_LIST := ["far_left", "left", "center_left", "center", "center_right", "right", "far_right"]
const DIRECTIONS := ["", "left", "right"]
const STYLES := ["gentle", "slam", "spinning", "dramatic", "nervous"]
const CAMERA_MODES := ["smooth", "snappy"]
const LAYOUT_MODES := ["fullscreen", "split", "board_only"]

# Category definitions: label, color, commands with parameter specs
# Parameter types: "char", "text", "position", "direction", "float:min:max", "flag", "color_str", "track", "option:a,b,c"
const CATEGORIES := {
	"dialogue": {
		"label": "DIALOGO", "color": Color(0.3, 0.65, 0.9),
		"commands": {
			"dialogue": {"character": "char", "expression": "expr", "text": "text", "target": "char_opt"},
			"choose": {"options_text": "text"},
		}
	},
	"char_action": {
		"label": "ACCION", "color": Color(1.0, 0.65, 0.2),
		"commands": {
			"enter": {"character": "char", "position": "position", "enter_from": "direction"},
			"exit": {"character": "char", "direction": "direction"},
			"move": {"character": "char", "position": "position"},
			"clear_stage": {},
		}
	},
	"char_state": {
		"label": "ESTADO", "color": Color(0.9, 0.45, 0.6),
		"commands": {
			"expression": {"character": "char", "expression": "expr"},
			"pose": {"character": "char", "state": "pose_select"},
			"look_at": {"character": "char", "target": "text_short"},
			"depth": {"character": "char", "depth": "float:0.5:1.5", "duration": "float:0.1:2.0"},
		}
	},
	"camera": {
		"label": "CAMARA", "color": Color(0.6, 0.35, 0.85),
		"commands": {
			"focus": {"character": "char_opt"},
			"clear_focus": {},
			"close_up": {"character": "char", "zoom": "float:1.0:2.0", "duration": "float:0.1:1.0"},
			"pull_back": {"character": "char", "zoom": "float:0.5:1.0", "duration": "float:0.1:1.0"},
			"camera_reset": {"duration": "float:0.1:1.0"},
			"camera_mode": {"mode": "option:smooth,snappy"},
			"camera_snap": {"character": "char", "zoom": "float:1.0:2.0"},
		}
	},
	"effect": {
		"label": "EFECTO", "color": Color(0.9, 0.3, 0.3),
		"commands": {
			"shake": {"intensity": "float:0.1:1.0", "duration": "float:0.1:1.0"},
			"flash": {"color": "text_short", "duration": "float:0.05:0.5"},
			"transition": {"style": "option:fade_black,fade_white,flash_red,flash_blue", "duration": "float:0.2:2.0"},
			"speed_lines": {"direction": "option:right,left,up,down,radial", "duration": "float:0.1:1.0"},
			"wipe": {"direction": "option:right,left,up,down", "duration": "float:0.2:1.0"},
			"wipe_out": {"direction": "option:right,left,up,down", "duration": "float:0.2:1.0"},
		}
	},
	"layout": {
		"label": "LAYOUT", "color": Color(0.85, 0.75, 0.2),
		"commands": {
			"layout_fullscreen": {},
			"layout_split": {},
			"layout_board_only": {},
			"layout_instant": {"mode": "option:fullscreen,split,board_only"},
		}
	},
	"audio": {
		"label": "AUDIO", "color": Color(0.2, 0.7, 0.65),
		"commands": {
			"music": {"track": "audio_music"},
			"sfx": {"sound": "audio_sfx"},
			"stop_music": {},
		}
	},
	"board": {
		"label": "TABLERO", "color": Color(0.3, 0.8, 0.85),
		"commands": {
			"board_enable": {},
			"board_disable": {},
			"set_style": {"target": "option:player,opponent", "style": "option:gentle,slam,spinning,dramatic,nervous"},
			"set_emotion": {"target": "option:player,opponent", "emotion": "text_short"},
		}
	},
	"logic": {
		"label": "LOGICA", "color": Color(0.35, 0.75, 0.35),
		"commands": {
			"if_flag": {"flag": "text_short"},
			"else": {},
			"end_if": {},
			"set_flag": {"flag": "text_short"},
			"clear_flag": {"flag": "text_short"},
		}
	},
	"ui": {
		"label": "UI", "color": Color(0.6, 0.6, 0.65),
		"commands": {
			"title_card": {"title": "text_short", "subtitle": "text_short"},
			"background": {"source": "text_short"},
			"background_gradient": {"top_color": "text_short", "bottom_color": "text_short"},
			"wait": {"duration": "float:0.1:5.0"},
		}
	},
}

var category: String = ""
var command: String = ""
var params: Dictionary = {}
var available_characters: Array = []  # Array[CharacterData]
var step_number: int = -1  # Set by cinematic editor for display

var _category_btn: OptionButton = null
var _command_btn: OptionButton = null
var _params_container: VBoxContainer = null
var _command_keys: Array = []  # Maps command_btn index → command key
var _audio_preview_player: AudioStreamPlayer = null

# Descriptions for parameterless commands so they don't look empty
const CMD_DESCRIPTIONS := {
	"clear_focus": "Restaura brillo de todos los personajes",
	"clear_stage": "Elimina todos los personajes del escenario",
	"board_enable": "Permite al jugador interactuar con el tablero",
	"board_disable": "Bloquea la interaccion con el tablero",
	"stop_music": "Detiene la musica de fondo",
	"layout_fullscreen": "Cinematica a pantalla completa",
	"layout_split": "Divide pantalla: cinematica + tablero",
	"layout_board_only": "Solo tablero visible",
	"else": "Rama alternativa (si el flag NO esta activo)",
	"end_if": "Cierra el bloque condicional",
}


func _init() -> void:
	super._init()
	accent_color = Color(0.5, 0.5, 0.55)


func _ready() -> void:
	title = "COMANDO"
	custom_minimum_size.x = 200
	resizable = false
	super._ready()

	# Slot 0: flow through
	var top_hbox := HBoxContainer.new()
	top_hbox.add_theme_constant_override("separation", 4)

	_category_btn = OptionButton.new()
	_category_btn.add_theme_font_size_override("font_size", 11)
	_category_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var cat_idx := 0
	for cat_key in CATEGORIES:
		_category_btn.add_item(CATEGORIES[cat_key].label, cat_idx)
		cat_idx += 1
	_category_btn.item_selected.connect(_on_category_selected)
	top_hbox.add_child(_category_btn)

	_command_btn = OptionButton.new()
	_command_btn.add_theme_font_size_override("font_size", 11)
	_command_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_command_btn.item_selected.connect(_on_command_selected)
	top_hbox.add_child(_command_btn)

	add_child(top_hbox)
	add_flow_through(0)

	# Slot 1+: dynamic params
	_params_container = VBoxContainer.new()
	_params_container.add_theme_constant_override("separation", 4)
	add_child(_params_container)
	set_slot_enabled_left(1, false)
	set_slot_enabled_right(1, false)

	# Apply initial state
	if category != "":
		_select_category(category)
		_select_command(command)
	elif _category_btn.item_count > 0:
		_on_category_selected(0)

	# Ensure compact size after setup
	size = Vector2.ZERO
	reset_size()


func _exit_tree() -> void:
	_stop_audio_preview()


func get_node_type() -> String:
	return "cinematic_command"


func get_node_data() -> Dictionary:
	return {"category": category, "command": command, "params": params.duplicate()}


func set_node_data(data: Dictionary) -> void:
	category = data.get("category", "")
	command = data.get("command", "")
	params = data.get("params", {}).duplicate()
	if is_inside_tree() and category != "":
		_select_category(category)
		_select_command(command)


func setup_as(cat: String, cmd: String, p: Dictionary = {}) -> void:
	category = cat
	command = cmd
	params = p.duplicate()
	if is_inside_tree():
		_select_category(cat)
		_select_command(cmd)


# ── Category/Command selection ──

func _on_category_selected(idx: int) -> void:
	var keys: Array = CATEGORIES.keys()
	if idx < 0 or idx >= keys.size():
		return
	category = keys[idx]
	var cat_data: Dictionary = CATEGORIES[category]
	accent_color = cat_data.color
	title = cat_data.label
	_apply_base_theme()

	# Populate command dropdown
	_command_btn.clear()
	_command_keys.clear()
	var cmd_idx := 0
	for cmd_key in cat_data.commands:
		_command_btn.add_item(cmd_key, cmd_idx)
		_command_keys.append(cmd_key)
		cmd_idx += 1
	if _command_btn.item_count > 0:
		_on_command_selected(0)


func _on_command_selected(idx: int) -> void:
	if idx < 0 or idx >= _command_keys.size():
		return
	command = _command_keys[idx]
	_rebuild_params()


func _select_category(cat: String) -> void:
	var keys: Array = CATEGORIES.keys()
	var idx: int = keys.find(cat)
	if idx >= 0 and _category_btn:
		_category_btn.selected = idx
		_on_category_selected(idx)


func _select_command(cmd: String) -> void:
	var idx: int = _command_keys.find(cmd)
	if idx >= 0 and _command_btn:
		_command_btn.selected = idx
		command = cmd
		_rebuild_params()


# ── Dynamic parameter widgets ──

func set_step(n: int) -> void:
	step_number = n
	if step_number >= 0:
		title = "#%d %s" % [step_number, CATEGORIES.get(category, {}).get("label", "")]
	else:
		title = CATEGORIES.get(category, {}).get("label", "COMANDO")


func _rebuild_params() -> void:
	if _params_container == null:
		return
	# Remove old children immediately (not deferred) so size recalculates correctly
	for child in _params_container.get_children():
		_params_container.remove_child(child)
		child.free()

	var cat_data: Dictionary = CATEGORIES.get(category, {})
	var cmd_params: Dictionary = cat_data.get("commands", {}).get(command, {})

	# Show description for parameterless commands
	if cmd_params.is_empty() and CMD_DESCRIPTIONS.has(command):
		var desc_lbl := Label.new()
		desc_lbl.text = CMD_DESCRIPTIONS[command]
		desc_lbl.add_theme_font_size_override("font_size", 10)
		desc_lbl.add_theme_color_override("font_color", GraphThemeC.COLOR_TEXT_DIM)
		_params_container.add_child(desc_lbl)

	for param_name in cmd_params:
		var param_type: String = cmd_params[param_name]
		var current_val = params.get(param_name, "")
		_add_param_widget(param_name, param_type, current_val)

	# Force GraphNode to shrink to fit content
	size = Vector2.ZERO
	reset_size()


func _add_param_widget(param_name: String, param_type: String, current_val) -> void:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 4)

	var lbl := Label.new()
	lbl.text = param_name
	lbl.custom_minimum_size.x = 60
	lbl.add_theme_font_size_override("font_size", 10)
	lbl.add_theme_color_override("font_color", GraphThemeC.COLOR_TEXT_DIM)
	hbox.add_child(lbl)

	if param_type == "char" or param_type == "char_opt":
		var opt := OptionButton.new()
		opt.add_theme_font_size_override("font_size", 10)
		opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if param_type == "char_opt":
			opt.add_item("(ninguno)")
		for ch in available_characters:
			opt.add_item(ch.display_name if ch.display_name != "" else ch.character_id)
		# Select current
		var cur: String = str(current_val)
		for i in range(opt.item_count):
			if opt.get_item_text(i) == cur or (i < available_characters.size() and available_characters[i].character_id == cur):
				opt.selected = i
				break
		var pname: String = param_name
		opt.item_selected.connect(func(i: int):
			var offset: int = 1 if param_type == "char_opt" else 0
			var idx: int = i - offset
			if idx >= 0 and idx < available_characters.size():
				params[pname] = available_characters[idx].character_id
			elif param_type == "char_opt":
				params[pname] = "")
		hbox.add_child(opt)

	elif param_type == "text" or param_type == "text_short":
		if param_type == "text":
			# Multilínea para diálogos
			var vbox := VBoxContainer.new()
			vbox.add_theme_constant_override("separation", 2)
			var lbl2 := Label.new()
			lbl2.text = param_name
			lbl2.add_theme_font_size_override("font_size", 10)
			lbl2.add_theme_color_override("font_color", GraphThemeC.COLOR_TEXT_DIM)
			vbox.add_child(lbl2)

			var edit := TextEdit.new()
			edit.text = str(current_val)
			edit.add_theme_font_size_override("font_size", 10)
			edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			edit.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
			edit.custom_minimum_size = Vector2(140, 60)
			edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
			var pname: String = param_name
			edit.text_changed.connect(func(): params[pname] = edit.text)
			vbox.add_child(edit)

			# Hint de tags disponibles
			var hint := Label.new()
			hint.text = "{b} {i} {shake} {wave} {rainbow}"
			hint.add_theme_font_size_override("font_size", 9)
			hint.add_theme_color_override("font_color", GraphThemeC.COLOR_TEXT_DIM)
			vbox.add_child(hint)

			vbox.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
			_params_container.add_child(vbox)
			return  # Para "text" no agregar hbox al final
		else:
			# Texto corto: una línea
			var edit := LineEdit.new()
			edit.text = str(current_val)
			edit.add_theme_font_size_override("font_size", 10)
			edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var pname: String = param_name
			edit.text_changed.connect(func(val: String): params[pname] = val)
			hbox.add_child(edit)

	elif param_type == "position":
		var opt := OptionButton.new()
		opt.add_theme_font_size_override("font_size", 10)
		for p in POSITIONS_LIST:
			opt.add_item(p)
		var cur: String = str(current_val)
		var idx: int = POSITIONS_LIST.find(cur)
		if idx >= 0:
			opt.selected = idx
		var pname: String = param_name
		opt.item_selected.connect(func(i: int): params[pname] = POSITIONS_LIST[i])
		hbox.add_child(opt)

	elif param_type == "direction":
		var opt := OptionButton.new()
		opt.add_theme_font_size_override("font_size", 10)
		for d in DIRECTIONS:
			opt.add_item(d if d != "" else "(auto)")
		var cur: String = str(current_val)
		var idx: int = DIRECTIONS.find(cur)
		if idx >= 0:
			opt.selected = idx
		var pname: String = param_name
		opt.item_selected.connect(func(i: int): params[pname] = DIRECTIONS[i])
		hbox.add_child(opt)

	elif param_type.begins_with("float:"):
		var parts: PackedStringArray = param_type.split(":")
		var min_v: float = float(parts[1]) if parts.size() > 1 else 0.0
		var max_v: float = float(parts[2]) if parts.size() > 2 else 1.0
		var slider := HSlider.new()
		slider.min_value = min_v
		slider.max_value = max_v
		slider.step = 0.05
		slider.value = float(current_val) if str(current_val) != "" else (min_v + max_v) / 2.0
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slider.custom_minimum_size.x = 60
		var pname: String = param_name
		slider.value_changed.connect(func(val: float): params[pname] = val)
		hbox.add_child(slider)

	elif param_type.begins_with("option:"):
		var options: PackedStringArray = param_type.substr(7).split(",")
		var opt := OptionButton.new()
		opt.add_theme_font_size_override("font_size", 10)
		for o in options:
			opt.add_item(o.strip_edges())
		var cur: String = str(current_val)
		for i in range(opt.item_count):
			if opt.get_item_text(i) == cur:
				opt.selected = i
				break
		var pname: String = param_name
		opt.item_selected.connect(func(i: int): params[pname] = opt.get_item_text(i))
		hbox.add_child(opt)

	elif param_type == "expr":
		# Expression dropdown populated from selected character
		var opt := OptionButton.new()
		opt.add_theme_font_size_override("font_size", 10)
		opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		opt.add_item("neutral")
		var char_id: String = params.get("character", "")
		for ch in available_characters:
			if ch.character_id == char_id:
				opt.clear()
				for expr_name in ch.expressions:
					opt.add_item(expr_name)
				break
		var cur: String = str(current_val)
		for i in range(opt.item_count):
			if opt.get_item_text(i) == cur:
				opt.selected = i
				break
		var pname: String = param_name
		opt.item_selected.connect(func(i: int): params[pname] = opt.get_item_text(i))
		hbox.add_child(opt)

	elif param_type == "pose_select":
		# Pose dropdown populated from selected character
		var opt := OptionButton.new()
		opt.add_theme_font_size_override("font_size", 10)
		opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		opt.add_item("idle")
		var char_id: String = params.get("character", "")
		for ch in available_characters:
			if ch.character_id == char_id:
				opt.clear()
				for pose_name in ch.poses:
					opt.add_item(pose_name)
				if opt.item_count == 0:
					opt.add_item("idle")
				break
		var cur: String = str(current_val)
		for i in range(opt.item_count):
			if opt.get_item_text(i) == cur:
				opt.selected = i
				break
		var pname: String = param_name
		opt.item_selected.connect(func(i: int): params[pname] = opt.get_item_text(i))
		hbox.add_child(opt)

	elif param_type == "audio_music" or param_type == "audio_sfx":
		# Audio dropdown + play button
		var audio_hbox := HBoxContainer.new()
		audio_hbox.add_theme_constant_override("separation", 4)
		var opt := OptionButton.new()
		opt.add_theme_font_size_override("font_size", 10)
		opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		# Scan audio directory
		var dir_path: String = "res://audio/music" if param_type == "audio_music" else "res://audio/sfx"
		var dir := DirAccess.open(dir_path)
		if dir:
			dir.list_dir_begin()
			var fname: String = dir.get_next()
			while fname != "":
				if not fname.ends_with(".import") and not fname.begins_with("."):
					opt.add_item(fname)
				fname = dir.get_next()
		var cur: String = str(current_val)
		for i in range(opt.item_count):
			if opt.get_item_text(i) == cur or cur.ends_with(opt.get_item_text(i)):
				opt.selected = i
				break
		var pname: String = param_name
		opt.item_selected.connect(func(i: int): params[pname] = opt.get_item_text(i))
		audio_hbox.add_child(opt)
		# Play button
		var play_btn := Button.new()
		play_btn.text = ">"
		play_btn.add_theme_font_size_override("font_size", 10)
		play_btn.custom_minimum_size = Vector2(24, 0)
		play_btn.pressed.connect(func():
			var selected_file: String = opt.get_item_text(opt.selected) if opt.selected >= 0 else ""
			if selected_file != "":
				var full_path: String = dir_path + "/" + selected_file
				if ResourceLoader.exists(full_path):
					var stream = load(full_path)
					if stream:
						_stop_audio_preview()
						var player := AudioStreamPlayer.new()
						player.stream = stream
						player.bus = "Master"
						add_child(player)
						_audio_preview_player = player
						player.finished.connect(func():
							if player == _audio_preview_player:
								_audio_preview_player = null
							if is_instance_valid(player):
								player.queue_free())
						player.play())
		audio_hbox.add_child(play_btn)
		var stop_btn := Button.new()
		stop_btn.text = "■"
		stop_btn.add_theme_font_size_override("font_size", 10)
		stop_btn.custom_minimum_size = Vector2(24, 0)
		stop_btn.pressed.connect(_stop_audio_preview)
		audio_hbox.add_child(stop_btn)
		hbox.add_child(audio_hbox)

	_params_container.add_child(hbox)


func _stop_audio_preview() -> void:
	if _audio_preview_player == null or not is_instance_valid(_audio_preview_player):
		_audio_preview_player = null
		return
	_audio_preview_player.stop()
	_audio_preview_player.queue_free()
	_audio_preview_player = null
