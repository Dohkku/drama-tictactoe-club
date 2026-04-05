class_name DetailPanelBuilder
extends RefCounted

## Builds and manages the detail panel content for selected graph nodes.

const GraphThemeC = preload("res://editor/graph/graph_theme.gd")
const CharacterDataScript = preload("res://characters/character_data.gd")
const StartNodeScript = preload("res://editor/graph/nodes/start_node.gd")
const EndNodeScript = preload("res://editor/graph/nodes/end_node.gd")
const CharacterNodeScript = preload("res://editor/graph/nodes/character_node.gd")
const CutsceneNodeScript = preload("res://editor/graph/nodes/cutscene_node.gd")
const MatchNodeScript = preload("res://editor/graph/nodes/match_node.gd")
const BoardConfigNodeScript = preload("res://editor/graph/nodes/board_config_node.gd")
const SimultaneousNodeScript = preload("res://editor/graph/nodes/simultaneous_node.gd")
const CommentNodeScript = preload("res://editor/graph/nodes/comment_node.gd")

var _main: Control  # GraphEditorMain


func _init(main: Control) -> void:
	_main = main


func show_welcome_panel() -> void:
	clear_detail()
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)

	var title := Label.new()
	title.text = "Editor 2.0"
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", GraphThemeC.COLOR_TEXT)
	vbox.add_child(title)

	var desc := Label.new()
	desc.text = "Selecciona un nodo para ver sus propiedades aqui."
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_font_size_override("font_size", 13)
	desc.add_theme_color_override("font_color", GraphThemeC.COLOR_TEXT_DIM)
	vbox.add_child(desc)

	vbox.add_child(HSeparator.new())

	var nav_title := Label.new()
	nav_title.text = "Navegacion"
	nav_title.add_theme_font_size_override("font_size", 15)
	nav_title.add_theme_color_override("font_color", GraphThemeC.COLOR_TEXT)
	vbox.add_child(nav_title)
	_add_help_line(vbox, "Scroll", "Mover canvas arriba/abajo")
	_add_help_line(vbox, "Shift + Scroll", "Mover canvas izquierda/derecha")
	_add_help_line(vbox, "Ctrl + Scroll", "Zoom in/out")
	_add_help_line(vbox, "Minimap", "Arrastra en la esquina inferior derecha")

	vbox.add_child(HSeparator.new())

	var edit_title := Label.new()
	edit_title.text = "Edicion"
	edit_title.add_theme_font_size_override("font_size", 15)
	edit_title.add_theme_color_override("font_color", GraphThemeC.COLOR_TEXT)
	vbox.add_child(edit_title)
	_add_help_line(vbox, "Click derecho", "Menu: agregar nodos")
	_add_help_line(vbox, "Arrastrar puerto", "Crear conexion")
	_add_help_line(vbox, "Click en nodo", "Seleccionar y editar")
	_add_help_line(vbox, "Delete / Supr", "Borrar nodo seleccionado")
	_add_help_line(vbox, "Arrastrar puerto der.", "Desconectar (right_disconnects)")

	vbox.add_child(HSeparator.new())

	var types_title := Label.new()
	types_title.text = "Tipos de nodo"
	types_title.add_theme_font_size_override("font_size", 15)
	types_title.add_theme_color_override("font_color", GraphThemeC.COLOR_TEXT)
	vbox.add_child(types_title)
	_add_help_line(vbox, "INICIO", "Punto de entrada (1 por canvas)")
	_add_help_line(vbox, "CINEMATICA", "Escena de dialogo (.dscn)")
	_add_help_line(vbox, "PARTIDA", "Match vs oponente con IA")
	_add_help_line(vbox, "PERSONAJE", "Definicion de personaje")
	_add_help_line(vbox, "TABLERO", "Config de reglas y visual")
	_add_help_line(vbox, "SIMULTANEA", "Ronda multiple oponentes")
	_add_help_line(vbox, "FIN", "Punto de finalizacion")

	vbox.add_child(HSeparator.new())

	var conn_title := Label.new()
	conn_title.text = "Conexiones"
	conn_title.add_theme_font_size_override("font_size", 15)
	conn_title.add_theme_color_override("font_color", GraphThemeC.COLOR_TEXT)
	vbox.add_child(conn_title)
	_add_help_line(vbox, "Blanco", "Flujo (orden de ejecucion)")
	_add_help_line(vbox, "Naranja", "Personaje → Partida")
	_add_help_line(vbox, "Cyan", "Tablero → Partida")

	margin.add_child(vbox)
	_main.detail_content.add_child(margin)


func show_detail_for_node(node: GraphNode) -> void:
	clear_detail()
	if node == null:
		show_welcome_panel()
		return

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)

	var header := Label.new()
	header.add_theme_font_size_override("font_size", 18)
	header.add_theme_color_override("font_color", GraphThemeC.COLOR_TEXT)

	if node is StartNodeScript:
		header.text = "Nodo Inicio"
		vbox.add_child(header)
		var desc := Label.new()
		desc.text = "Punto de entrada del juego.\nConecta la salida al primer evento."
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.add_theme_font_size_override("font_size", 13)
		desc.add_theme_color_override("font_color", GraphThemeC.COLOR_TEXT_DIM)
		vbox.add_child(desc)

	elif node is EndNodeScript:
		header.text = "Nodo Fin"
		vbox.add_child(header)
		var desc := Label.new()
		desc.text = "Punto de finalizacion del juego."
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.add_theme_font_size_override("font_size", 13)
		desc.add_theme_color_override("font_color", GraphThemeC.COLOR_TEXT_DIM)
		vbox.add_child(desc)

	elif node is CharacterNodeScript:
		header.text = "Personaje"
		vbox.add_child(header)
		_build_character_detail(vbox, node)

	elif node is MatchNodeScript:
		header.text = "Partida"
		vbox.add_child(header)
		_build_match_detail(vbox, node)

	elif node is CutsceneNodeScript:
		header.text = "Cinematica"
		vbox.add_child(header)
		_build_cutscene_detail(vbox, node)

	elif node is BoardConfigNodeScript:
		header.text = "Tablero"
		vbox.add_child(header)
		_build_board_config_detail(vbox, node)

	elif node is SimultaneousNodeScript:
		header.text = "Simultanea"
		vbox.add_child(header)
		_build_simultaneous_detail(vbox, node)

	elif node is CommentNodeScript:
		header.text = "Nota"
		vbox.add_child(header)

	else:
		header.text = "Nodo"
		vbox.add_child(header)

	margin.add_child(vbox)
	_main.detail_content.add_child(margin)


func clear_detail() -> void:
	for child in _main.detail_content.get_children():
		child.queue_free()


func show_stage_settings() -> void:
	clear_detail()
	_main._selected_node = null
	for child in _main.graph_edit.get_children():
		if child is GraphNode:
			child.selected = false

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)

	var header := Label.new()
	header.text = "Ajustes de Escena"
	header.add_theme_font_size_override("font_size", 18)
	header.add_theme_color_override("font_color", GraphThemeC.COLOR_TEXT)
	vbox.add_child(header)

	var viewport_container := SubViewportContainer.new()
	viewport_container.custom_minimum_size = Vector2(0, 200)
	viewport_container.stretch = true
	var viewport := SubViewport.new()
	viewport.size = Vector2i(640, 360)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport_container.add_child(viewport)
	viewport_container.resized.connect(func():
		var s := viewport_container.size
		viewport.size = Vector2i(maxi(1, int(s.x)), maxi(1, int(s.y))))

	var stage_scene = load("res://systems/cinematic/cinematic_stage.tscn")
	var preview_stage: Control = stage_scene.instantiate()
	preview_stage.set_anchors_preset(Control.PRESET_FULL_RECT)
	viewport.add_child(preview_stage)

	var _preview_loaded := false
	var _load_preview := func():
		if _preview_loaded:
			return
		_preview_loaded = true
		for child in _main.graph_edit.get_children():
			if child is CharacterNodeScript and child.character_data:
				preview_stage.register_character(child.character_data)
				preview_stage.enter_character(child.character_data.character_id, "center")
				break

	viewport_container.ready.connect(_load_preview, CONNECT_ONE_SHOT)
	vbox.add_child(viewport_container)

	_add_section_header(vbox, "Tamano de personajes")

	var desc := Label.new()
	desc.text = "Ajusta como se ven los personajes en el escenario."
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_font_size_override("font_size", 12)
	desc.add_theme_color_override("font_color", GraphThemeC.COLOR_TEXT_DIM)
	vbox.add_child(desc)

	var _refresh_preview := func():
		for char_id in preview_stage.characters_on_stage:
			var slot = preview_stage.characters_on_stage[char_id]
			var pos_name = preview_stage._character_positions.get(char_id, "center")
			var frac = preview_stage.POSITIONS.get(pos_name, 0.5)
			preview_stage._apply_slot_position(slot, frac)

	_add_slider_field(vbox, "Altura", _main._stage_height_ratio, 0.5, 1.0, func(val: float):
		preview_stage.char_height_ratio = val
		_main._stage_height_ratio = val
		_refresh_preview.call())

	_add_slider_field(vbox, "Aspecto", _main._stage_aspect, 0.3, 0.8, func(val: float):
		preview_stage.char_aspect = val
		_main._stage_aspect = val
		_refresh_preview.call())

	_add_slider_field(vbox, "Max ancho", _main._stage_max_width, 0.2, 0.6, func(val: float):
		preview_stage.char_max_width_frac = val
		_main._stage_max_width = val
		_refresh_preview.call())

	var apply_info := Label.new()
	apply_info.text = "Los valores se aplican al jugar."
	apply_info.add_theme_font_size_override("font_size", 11)
	apply_info.add_theme_color_override("font_color", GraphThemeC.COLOR_TEXT_DIM)
	vbox.add_child(apply_info)

	margin.add_child(vbox)
	_main.detail_content.add_child(margin)


# ── Detail Builders ──

func _build_character_detail(parent: VBoxContainer, node) -> void:
	if node.character_data == null:
		node.character_data = CharacterDataScript.new()
	var data: Resource = node.character_data

	_add_section_header(parent, "Identidad")
	_add_field(parent, "ID", data.character_id, func(val: String):
		data.character_id = val; node._refresh_display())
	_add_field(parent, "Nombre", data.display_name, func(val: String):
		data.display_name = val; node._refresh_display())
	_add_color_field(parent, "Color", data.color, func(val: Color):
		data.color = val; node._refresh_display())

	_add_section_header(parent, "Retrato")
	var _img_change := func(val: String):
		if ResourceLoader.exists(val):
			data.portrait_image = load(val)
			node._refresh_display()
	_add_file_field(parent, "Imagen", data.portrait_image.resource_path if data.portrait_image else "", _img_change,
		PackedStringArray(["*.png,*.jpg,*.jpeg,*.webp ; Portrait Images"]), "res://")
	var size_hint := Label.new()
	size_hint.text = "Formato: 512x768 px (2:3)"
	size_hint.add_theme_font_size_override("font_size", 10)
	size_hint.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55))
	parent.add_child(size_hint)

	_add_section_header(parent, "Gameplay")
	_add_option_field(parent, "Pieza", data.piece_type, ["X", "O"],
		func(val: String): data.piece_type = val)
	_add_option_field(parent, "Estilo", data.default_style,
		["gentle", "slam", "spinning", "dramatic", "nervous"],
		func(val: String): data.default_style = val)
	_add_field(parent, "Pose default", data.default_pose, func(val: String):
		data.default_pose = val)
	_add_option_field(parent, "Direccion", data.default_look,
		["left", "center", "right", "away"],
		func(val: String): data.default_look = val)

	_add_section_header(parent, "Expresiones (%d)" % data.expressions.size())
	for expr_name in data.expressions:
		var expr_color: Color = data.expressions[expr_name]
		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 4)
		var name_lbl := Label.new()
		name_lbl.text = expr_name
		name_lbl.custom_minimum_size.x = 70
		name_lbl.add_theme_font_size_override("font_size", 12)
		name_lbl.add_theme_color_override("font_color", GraphThemeC.COLOR_TEXT)
		hbox.add_child(name_lbl)
		var color_pick := ColorPickerButton.new()
		color_pick.color = expr_color
		color_pick.custom_minimum_size = Vector2(28, 20)
		var ename_ref: String = expr_name
		color_pick.color_changed.connect(func(c: Color): data.expressions[ename_ref] = c)
		hbox.add_child(color_pick)
		if data.expression_images.has(expr_name) and data.expression_images[expr_name] != null:
			var img_lbl := Label.new()
			img_lbl.text = "img"
			img_lbl.add_theme_font_size_override("font_size", 9)
			img_lbl.add_theme_color_override("font_color", GraphThemeC.COLOR_START)
			hbox.add_child(img_lbl)
		var del_btn := Button.new()
		del_btn.text = "x"
		del_btn.add_theme_font_size_override("font_size", 10)
		del_btn.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))
		del_btn.custom_minimum_size = Vector2(20, 0)
		var del_ename: String = expr_name
		del_btn.pressed.connect(func():
			data.expressions.erase(del_ename)
			data.expression_images.erase(del_ename)
			show_detail_for_node(node))
		hbox.add_child(del_btn)
		parent.add_child(hbox)

	var add_expr_hbox := HBoxContainer.new()
	add_expr_hbox.add_theme_constant_override("separation", 4)
	var new_expr_edit := LineEdit.new()
	new_expr_edit.placeholder_text = "nueva expresion"
	new_expr_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	new_expr_edit.add_theme_font_size_override("font_size", 12)
	add_expr_hbox.add_child(new_expr_edit)
	var add_expr_btn := Button.new()
	add_expr_btn.text = "+"
	add_expr_btn.add_theme_font_size_override("font_size", 12)
	add_expr_btn.pressed.connect(func():
		var ename: String = new_expr_edit.text.strip_edges()
		if ename != "" and not data.expressions.has(ename):
			data.expressions[ename] = data.color
			show_detail_for_node(node))
	add_expr_hbox.add_child(add_expr_btn)
	parent.add_child(add_expr_hbox)

	_add_section_header(parent, "Poses (%d)" % data.poses.size())
	for pose_name in data.poses:
		var pose_hbox := HBoxContainer.new()
		pose_hbox.add_theme_constant_override("separation", 4)
		var pose_lbl := Label.new()
		pose_lbl.text = pose_name
		pose_lbl.custom_minimum_size.x = 100
		pose_lbl.add_theme_font_size_override("font_size", 12)
		pose_lbl.add_theme_color_override("font_color", GraphThemeC.COLOR_TEXT)
		pose_hbox.add_child(pose_lbl)
		var del_pose_btn := Button.new()
		del_pose_btn.text = "x"
		del_pose_btn.add_theme_font_size_override("font_size", 10)
		del_pose_btn.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))
		del_pose_btn.custom_minimum_size = Vector2(20, 0)
		var del_pname: String = pose_name
		del_pose_btn.pressed.connect(func():
			data.poses.erase(del_pname)
			show_detail_for_node(node))
		pose_hbox.add_child(del_pose_btn)
		parent.add_child(pose_hbox)

	var add_pose_hbox := HBoxContainer.new()
	add_pose_hbox.add_theme_constant_override("separation", 4)
	var new_pose_edit := LineEdit.new()
	new_pose_edit.placeholder_text = "nueva pose"
	new_pose_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	new_pose_edit.add_theme_font_size_override("font_size", 12)
	add_pose_hbox.add_child(new_pose_edit)
	var add_pose_btn := Button.new()
	add_pose_btn.text = "+"
	add_pose_btn.add_theme_font_size_override("font_size", 12)
	add_pose_btn.pressed.connect(func():
		var pname: String = new_pose_edit.text.strip_edges()
		if pname != "" and not data.poses.has(pname):
			data.poses[pname] = {"description": "", "energy": 0.5, "openness": 0.5}
			show_detail_for_node(node))
	add_pose_hbox.add_child(add_pose_btn)
	parent.add_child(add_pose_hbox)

	_add_section_header(parent, "Voz")
	_add_slider_field(parent, "Pitch", data.voice_pitch, 50.0, 500.0, func(val: float):
		data.voice_pitch = val)
	_add_slider_field(parent, "Variacion", data.voice_variation, 0.0, 100.0, func(val: float):
		data.voice_variation = val)
	_add_option_field(parent, "Waveform", data.voice_waveform,
		["sine", "square", "triangle"],
		func(val: String): data.voice_waveform = val)

	_add_section_header(parent, "Dialogo")
	_add_color_field(parent, "Fondo", data.dialogue_bg_color, func(val: Color):
		data.dialogue_bg_color = val)
	_add_color_field(parent, "Borde", data.dialogue_border_color, func(val: Color):
		data.dialogue_border_color = val)


func _build_match_detail(parent: VBoxContainer, node) -> void:
	var data: Dictionary = node.match_data

	var preview_btn := Button.new()
	preview_btn.text = "▶ Preview esta partida"
	preview_btn.custom_minimum_size = Vector2(0, 36)
	preview_btn.add_theme_font_size_override("font_size", 14)
	preview_btn.add_theme_color_override("font_color", Color.WHITE)
	var pb_style := StyleBoxFlat.new()
	pb_style.bg_color = Color(0.7, 0.35, 0.15)
	pb_style.set_corner_radius_all(4)
	pb_style.content_margin_left = 12
	pb_style.content_margin_right = 12
	pb_style.content_margin_top = 6
	pb_style.content_margin_bottom = 6
	preview_btn.add_theme_stylebox_override("normal", pb_style)
	var pb_hover := pb_style.duplicate()
	pb_hover.bg_color = Color(0.85, 0.45, 0.2)
	preview_btn.add_theme_stylebox_override("hover", pb_hover)
	preview_btn.pressed.connect(func(): _main._preview_manager.preview_single_match(node))
	parent.add_child(preview_btn)
	parent.add_child(HSeparator.new())

	var diff_val: float = data.get("ai_difficulty", 0.5)
	var diff_label_text: String = "Facil" if diff_val < 0.3 else ("Normal" if diff_val < 0.6 else ("Dificil" if diff_val < 0.85 else "Experto"))
	var diff_info := Label.new()
	diff_info.text = "Nivel: %s (%d%%)" % [diff_label_text, int(diff_val * 100)]
	diff_info.add_theme_font_size_override("font_size", 12)
	diff_info.add_theme_color_override("font_color", GraphThemeC.COLOR_TEXT_DIM)
	parent.add_child(diff_info)

	_add_slider_field(parent, "Dificultad IA", diff_val, 0.0, 1.0, func(val: float):
		data["ai_difficulty"] = val
		diff_info.text = "Nivel: %s (%d%%)" % [
			"Facil" if val < 0.3 else ("Normal" if val < 0.6 else ("Dificil" if val < 0.85 else "Experto")),
			int(val * 100)]
		node._refresh_display())

	_add_option_field(parent, "Empieza", data.get("starting_player", "player"),
		["player", "opponent", "random"],
		func(val: String): data["starting_player"] = val)

	_add_option_field(parent, "Estilo jugador", data.get("player_style", "slam"),
		["gentle", "slam", "spinning", "dramatic", "nervous"],
		func(val: String): data["player_style"] = val; node._refresh_display())

	_add_option_field(parent, "Estilo oponente", data.get("opponent_style", "gentle"),
		["gentle", "slam", "spinning", "dramatic", "nervous"],
		func(val: String): data["opponent_style"] = val; node._refresh_display())

	_add_option_field(parent, "Efecto jugador", data.get("player_effect_name", "none"),
		["none", "fire", "sparkle", "smoke", "shockwave"],
		func(val: String): data["player_effect_name"] = val)

	_add_option_field(parent, "Efecto oponente", data.get("opponent_effect_name", "auto"),
		["none", "auto", "fire", "sparkle", "smoke", "shockwave"],
		func(val: String): data["opponent_effect_name"] = val)

	_add_slider_field(parent, "Imprecision", data.get("placement_offset", 0.0), 0.0, 0.3, func(val: float):
		data["placement_offset"] = val)

	_add_option_field(parent, "Pieza jugador", data.get("player_piece_design", "x"),
		["x", "o", "triangle", "square", "star", "diamond"],
		func(val: String): data["player_piece_design"] = val)

	_add_option_field(parent, "Pieza oponente", data.get("opponent_piece_design", "o"),
		["x", "o", "triangle", "square", "star", "diamond"],
		func(val: String): data["opponent_piece_design"] = val)

	var _tpv_cb := func(val: float): data["turns_per_visit"] = int(val)
	_add_slider_field(parent, "Turnos por visita", float(data.get("turns_per_visit", 1)), 1.0, 5.0, _tpv_cb, 1.0)

	parent.add_child(HSeparator.new())
	var scripts_header := Label.new()
	scripts_header.text = "Scripts"
	scripts_header.add_theme_font_size_override("font_size", 15)
	scripts_header.add_theme_color_override("font_color", GraphThemeC.COLOR_TEXT)
	parent.add_child(scripts_header)

	_add_file_field(parent, "Intro", data.get("intro_script", ""), func(val: String):
		data["intro_script"] = val
		show_detail_for_node(node))
	_add_file_field(parent, "Reacciones", data.get("reactions_script", ""), func(val: String):
		data["reactions_script"] = val
		show_detail_for_node(node))

	_add_inline_script_editor(parent, "Intro (.dscn)", data.get("intro_script", ""))
	_add_inline_script_editor(parent, "Reacciones (.dscn)", data.get("reactions_script", ""))


func _build_cutscene_detail(parent: VBoxContainer, node) -> void:
	var preview_btn := Button.new()
	preview_btn.text = "▶ Preview este nodo"
	preview_btn.custom_minimum_size = Vector2(0, 36)
	preview_btn.add_theme_font_size_override("font_size", 14)
	preview_btn.add_theme_color_override("font_color", Color.WHITE)
	var pb_style := StyleBoxFlat.new()
	pb_style.bg_color = Color(0.7, 0.35, 0.15)
	pb_style.set_corner_radius_all(4)
	pb_style.content_margin_left = 12
	pb_style.content_margin_right = 12
	pb_style.content_margin_top = 6
	pb_style.content_margin_bottom = 6
	preview_btn.add_theme_stylebox_override("normal", pb_style)
	var pb_hover := pb_style.duplicate()
	pb_hover.bg_color = Color(0.85, 0.45, 0.2)
	preview_btn.add_theme_stylebox_override("hover", pb_hover)
	preview_btn.pressed.connect(func(): _main._preview_manager.preview_single_cutscene(node))
	parent.add_child(preview_btn)
	parent.add_child(HSeparator.new())

	var edit_btn := Button.new()
	edit_btn.text = "EDITAR ESCENA EN NODOS"
	edit_btn.custom_minimum_size = Vector2(0, 44)
	edit_btn.add_theme_font_size_override("font_size", 16)
	edit_btn.add_theme_color_override("font_color", Color.WHITE)
	var eb_style := StyleBoxFlat.new()
	eb_style.bg_color = Color(0.25, 0.45, 0.85)
	eb_style.set_corner_radius_all(6)
	eb_style.content_margin_left = 12
	eb_style.content_margin_right = 12
	eb_style.content_margin_top = 8
	eb_style.content_margin_bottom = 8
	edit_btn.add_theme_stylebox_override("normal", eb_style)
	var eb_hover := eb_style.duplicate()
	eb_hover.bg_color = Color(0.35, 0.55, 0.95)
	edit_btn.add_theme_stylebox_override("hover", eb_hover)
	edit_btn.pressed.connect(func(): _main._preview_manager.open_cinematic_editor(node))
	parent.add_child(edit_btn)

	parent.add_child(HSeparator.new())

	_add_file_field(parent, "Script", node.script_path, func(val: String):
		node.set_script_path(val)
		show_detail_for_node(node))

	if node.script_path == "":
		var create_btn := Button.new()
		create_btn.text = "Crear nuevo script"
		create_btn.add_theme_font_size_override("font_size", 13)
		var cs := StyleBoxFlat.new()
		cs.bg_color = GraphThemeC.COLOR_CUTSCENE.darkened(0.4)
		cs.set_corner_radius_all(4)
		cs.content_margin_left = 8
		cs.content_margin_right = 8
		cs.content_margin_top = 4
		cs.content_margin_bottom = 4
		create_btn.add_theme_stylebox_override("normal", cs)
		create_btn.add_theme_color_override("font_color", Color.WHITE)
		create_btn.pressed.connect(func():
			var new_path := "res://scene_scripts/scripts/new_scene_%s.dscn" % node.node_id
			var f := FileAccess.open(new_path, FileAccess.WRITE)
			if f:
				f.store_string("@scene new_scene\n\n[fullscreen]\n[camera_mode smooth]\n\n")
				f.close()
				node.set_script_path(new_path)
				show_detail_for_node(node))
		parent.add_child(create_btn)

	var code: CodeEdit = _add_inline_script_editor(parent, "Editor de Script", node.script_path)
	if code != null:
		_add_section_header(parent, "Comandos rapidos")
		var cmd_grid := GridContainer.new()
		cmd_grid.columns = 3
		cmd_grid.add_theme_constant_override("h_separation", 4)
		cmd_grid.add_theme_constant_override("v_separation", 4)
		var commands := [
			["enter", "[enter char center left]"],
			["exit", "[exit char left]"],
			["expr", "[expression char neutral]"],
			["pose", "[pose char idle]"],
			["focus", "[focus char]"],
			["unfocus", "[clear_focus]"],
			["close_up", "[close_up char 1.3 0.4]"],
			["cam_reset", "[camera_reset 0.3]"],
			["flash", "[flash #ffffff 0.08]"],
			["shake", "[shake 0.3 0.2]"],
			["wait", "[wait 0.5]"],
			["music", "[music bgm_chill.mp3]"],
			["title", "[title_card Titulo | Sub]"],
			["split", "[split]"],
			["full", "[fullscreen]"],
			["flag", "[set_flag flag_name]"],
			["if", "[if flag name]\n\n[end_if]"],
			["choose", "[choose]\n> Opcion -> flag\n[end_choose]"],
		]
		for cmd in commands:
			var btn := Button.new()
			btn.text = cmd[0]
			btn.add_theme_font_size_override("font_size", 10)
			var cmd_text: String = cmd[1]
			btn.pressed.connect(func(): code.insert_text_at_caret(cmd_text + "\n"))
			cmd_grid.add_child(btn)
		parent.add_child(cmd_grid)


func _build_board_config_detail(parent: VBoxContainer, node) -> void:
	var config: Resource = node.board_config
	if config == null:
		return
	var rules = config.get_rules()

	var default_check := CheckBox.new()
	default_check.text = "Default del proyecto"
	default_check.button_pressed = node.is_project_default
	default_check.add_theme_color_override("font_color", GraphThemeC.COLOR_TEXT)
	default_check.add_theme_font_size_override("font_size", 13)
	default_check.toggled.connect(func(pressed: bool):
		node.is_project_default = pressed; node._refresh_display())
	parent.add_child(default_check)

	_add_section_header(parent, "Preset")
	var preset_hbox := HBoxContainer.new()
	preset_hbox.add_theme_constant_override("separation", 4)
	var presets := [["Std 3x3", 3, 3, -1, true], ["Rot 3", 3, 3, 3, false], ["Big 5x5", 5, 4, -1, true]]
	for p in presets:
		var btn := Button.new()
		btn.text = p[0]
		btn.add_theme_font_size_override("font_size", 11)
		var p_ref: Array = p
		btn.pressed.connect(func():
			rules.board_size = p_ref[1]; rules.win_length = p_ref[2]
			rules.max_pieces_per_player = p_ref[3]; rules.allow_draw = p_ref[4]
			if p_ref[3] > 0: rules.overflow_mode = "rotate"
			node._refresh_display(); show_detail_for_node(node))
		preset_hbox.add_child(btn)
	parent.add_child(preset_hbox)

	_add_section_header(parent, "Reglas")
	_add_slider_field(parent, "Tamano", float(rules.board_size), 3.0, 7.0,
		func(val: float): rules.board_size = int(val); node._refresh_display(), 1.0)
	_add_slider_field(parent, "Para ganar", float(rules.win_length), 3.0, 7.0,
		func(val: float): rules.win_length = int(val); node._refresh_display(), 1.0)
	_add_slider_field(parent, "Max piezas", float(rules.max_pieces_per_player), -1.0, 20.0,
		func(val: float): rules.max_pieces_per_player = int(val); node._refresh_display(), 1.0)
	_add_option_field(parent, "Overflow", rules.overflow_mode, ["rotate", "block"],
		func(val: String): rules.overflow_mode = val)

	var draw_check := CheckBox.new()
	draw_check.text = "Permitir empate"
	draw_check.button_pressed = rules.allow_draw
	draw_check.add_theme_color_override("font_color", GraphThemeC.COLOR_TEXT)
	draw_check.add_theme_font_size_override("font_size", 13)
	draw_check.toggled.connect(func(pressed: bool): rules.allow_draw = pressed)
	parent.add_child(draw_check)

	_add_section_header(parent, "Visual")
	_add_color_field(parent, "Celda vacia", config.cell_color_empty, func(val: Color):
		config.cell_color_empty = val; node._refresh_display())
	var checker := CheckBox.new()
	checker.text = "Checkerboard"
	checker.button_pressed = config.checkerboard_enabled
	checker.add_theme_color_override("font_color", GraphThemeC.COLOR_TEXT)
	checker.add_theme_font_size_override("font_size", 13)
	checker.toggled.connect(func(p: bool): config.checkerboard_enabled = p; node._refresh_display())
	parent.add_child(checker)
	if config.checkerboard_enabled:
		_add_color_field(parent, "Celda alt", config.cell_color_alt, func(val: Color):
			config.cell_color_alt = val; node._refresh_display())
	_add_color_field(parent, "Lineas", config.cell_line_color, func(val: Color):
		config.cell_line_color = val; node._refresh_display())
	_add_color_field(parent, "Fondo", config.board_bg_color, func(val: Color):
		config.board_bg_color = val)

	_add_section_header(parent, "Colores Jugadores")
	_add_color_field(parent, "Jugador", config.default_player_color, func(val: Color):
		config.default_player_color = val)
	_add_color_field(parent, "Oponente", config.default_opponent_color, func(val: Color):
		config.default_opponent_color = val)


func _build_simultaneous_detail(parent: VBoxContainer, node) -> void:
	var info := Label.new()
	info.text = "Conecta personajes a los puertos de oponente.\nCada oponente tendra su propia config."
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_theme_font_size_override("font_size", 13)
	info.add_theme_color_override("font_color", GraphThemeC.COLOR_TEXT_DIM)
	parent.add_child(info)

	for i in range(node.opponent_configs.size()):
		parent.add_child(HSeparator.new())
		var opp_header := Label.new()
		opp_header.text = "Oponente %d" % (i + 1)
		opp_header.add_theme_font_size_override("font_size", 14)
		opp_header.add_theme_color_override("font_color", GraphThemeC.COLOR_TEXT)
		parent.add_child(opp_header)
		var opp_data: Dictionary = node.opponent_configs[i]
		_add_slider_field(parent, "Dificultad IA", opp_data.get("ai_difficulty", 0.5), 0.0, 1.0, func(val: float):
			opp_data["ai_difficulty"] = val)


# ── Field Helpers ──

func _add_field(parent: VBoxContainer, label_text: String, value: String, on_change: Callable) -> void:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	var lbl := Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size.x = 90
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", GraphThemeC.COLOR_TEXT_DIM)
	hbox.add_child(lbl)
	var edit := LineEdit.new()
	edit.text = value
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	edit.add_theme_font_size_override("font_size", 13)
	edit.text_changed.connect(on_change)
	hbox.add_child(edit)
	parent.add_child(hbox)


func _add_color_field(parent: VBoxContainer, label_text: String, value: Color, on_change: Callable) -> void:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	var lbl := Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size.x = 90
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", GraphThemeC.COLOR_TEXT_DIM)
	hbox.add_child(lbl)
	var picker := ColorPickerButton.new()
	picker.color = value
	picker.custom_minimum_size = Vector2(40, 28)
	picker.color_changed.connect(on_change)
	hbox.add_child(picker)
	parent.add_child(hbox)


func _add_slider_field(parent: VBoxContainer, label_text: String, value: float, min_val: float, max_val: float, on_change: Callable, step: float = 0.01) -> void:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	var lbl := Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size.x = 90
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", GraphThemeC.COLOR_TEXT_DIM)
	hbox.add_child(lbl)
	var slider := HSlider.new()
	slider.min_value = min_val
	slider.max_value = max_val
	slider.step = step
	slider.value = value
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.custom_minimum_size.x = 80
	slider.value_changed.connect(on_change)
	hbox.add_child(slider)
	var val_label := Label.new()
	val_label.text = "%.2f" % value if step < 1.0 else str(int(value))
	val_label.custom_minimum_size.x = 36
	val_label.add_theme_font_size_override("font_size", 12)
	val_label.add_theme_color_override("font_color", GraphThemeC.COLOR_TEXT_DIM)
	slider.value_changed.connect(func(v: float):
		val_label.text = "%.2f" % v if step < 1.0 else str(int(v)))
	hbox.add_child(val_label)
	parent.add_child(hbox)


func _add_option_field(parent: VBoxContainer, label_text: String, value: String, options: Array, on_change: Callable) -> void:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	var lbl := Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size.x = 90
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", GraphThemeC.COLOR_TEXT_DIM)
	hbox.add_child(lbl)
	var option := OptionButton.new()
	option.add_theme_font_size_override("font_size", 13)
	for opt in options:
		option.add_item(opt)
	var idx := options.find(value)
	if idx >= 0:
		option.selected = idx
	option.item_selected.connect(func(i: int): on_change.call(options[i]))
	hbox.add_child(option)
	parent.add_child(hbox)


func _add_file_field(parent: VBoxContainer, label_text: String, value: String, on_change: Callable, filters: PackedStringArray = PackedStringArray(["*.dscn ; Scene Scripts"]), start_dir: String = "res://scene_scripts/scripts/") -> void:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	var lbl := Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size.x = 90
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", GraphThemeC.COLOR_TEXT_DIM)
	hbox.add_child(lbl)
	var edit := LineEdit.new()
	edit.text = value
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	edit.add_theme_font_size_override("font_size", 12)
	edit.text_changed.connect(on_change)
	hbox.add_child(edit)
	var browse := Button.new()
	browse.text = "..."
	browse.add_theme_font_size_override("font_size", 12)
	var file_dialog = _main._file_dialog
	var local_filters := filters
	var local_start_dir := start_dir
	var _browse_cb := func():
		file_dialog.filters = local_filters
		file_dialog.current_dir = local_start_dir
		var _on_file := func(path: String):
			edit.text = path
			on_change.call(path)
		file_dialog.file_selected.connect(_on_file, CONNECT_ONE_SHOT)
		file_dialog.popup_centered(Vector2i(600, 400))
	browse.pressed.connect(_browse_cb)
	hbox.add_child(browse)
	parent.add_child(hbox)


func _add_inline_script_editor(parent: VBoxContainer, title: String, script_path: String) -> CodeEdit:
	_add_section_header(parent, title)
	if script_path == "" or not FileAccess.file_exists(script_path):
		var empty := Label.new()
		empty.text = "Sin script asignado"
		empty.add_theme_font_size_override("font_size", 11)
		empty.add_theme_color_override("font_color", GraphThemeC.COLOR_TEXT_DIM)
		parent.add_child(empty)
		return null
	var code := CodeEdit.new()
	code.custom_minimum_size = Vector2(0, 260)
	code.size_flags_vertical = Control.SIZE_EXPAND_FILL
	code.text = FileAccess.get_file_as_string(script_path)
	code.add_theme_font_size_override("font_size", 11)
	code.gutters_draw_line_numbers = true
	parent.add_child(code)

	var save_btn := Button.new()
	save_btn.text = "Guardar script"
	save_btn.add_theme_font_size_override("font_size", 13)
	var ss := StyleBoxFlat.new()
	ss.bg_color = Color(0.2, 0.5, 0.3)
	ss.set_corner_radius_all(4)
	ss.content_margin_left = 8
	ss.content_margin_right = 8
	ss.content_margin_top = 4
	ss.content_margin_bottom = 4
	save_btn.add_theme_stylebox_override("normal", ss)
	save_btn.add_theme_color_override("font_color", Color.WHITE)
	var path_ref: String = script_path
	save_btn.pressed.connect(func():
		var f := FileAccess.open(path_ref, FileAccess.WRITE)
		if f:
			f.store_string(code.text)
			f.close()
			print("[GraphEditor] Script guardado: ", path_ref))
	parent.add_child(save_btn)
	return code


func _add_section_header(parent: VBoxContainer, text: String) -> void:
	parent.add_child(HSeparator.new())
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", GraphThemeC.COLOR_TEXT)
	parent.add_child(lbl)


func _add_help_line(parent: VBoxContainer, key: String, desc: String) -> void:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	var key_lbl := Label.new()
	key_lbl.text = key
	key_lbl.custom_minimum_size.x = 100
	key_lbl.add_theme_font_size_override("font_size", 12)
	key_lbl.add_theme_color_override("font_color", GraphThemeC.COLOR_TEXT)
	hbox.add_child(key_lbl)
	var desc_lbl := Label.new()
	desc_lbl.text = desc
	desc_lbl.add_theme_font_size_override("font_size", 11)
	desc_lbl.add_theme_color_override("font_color", GraphThemeC.COLOR_TEXT_DIM)
	hbox.add_child(desc_lbl)
	parent.add_child(hbox)
