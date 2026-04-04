extends Control

## Board facade: orchestrates modules and exposes the public API.
## All external callers (MatchManager, SceneRunner, BoardEditor) use this interface.

const BoardLogicScript = preload("res://systems/board_logic/board_logic.gd")
const GameRulesScript = preload("res://systems/board_logic/game_rules.gd")
const AIPlayerScript = preload("res://systems/board_logic/ai_player.gd")
const CellScript = preload("res://systems/board_visuals/cell.gd")
const PlacementStyleScript = preload("res://systems/board_visuals/placement_style.gd")
const BoardPiecesScript = preload("res://systems/board_visuals/board_pieces.gd")
const BoardGameControllerScript = preload("res://board/board_game_controller.gd")
const BoardAbilityControllerScript = preload("res://board/board_ability_controller.gd")
const BoardStateManagerScript = preload("res://board/board_state_manager.gd")
const PieceDesignScript = preload("res://systems/board_visuals/piece_design.gd")
const ScreenEffectsScript = preload("res://systems/board_visuals/screen_effects.gd")
const BoardAudioScript = preload("res://systems/board_visuals/board_audio.gd")
const PieceEffectScript = preload("res://systems/board_visuals/piece_effect.gd")
const PieceEffectPlayerScript = preload("res://systems/board_visuals/piece_effect_player.gd")

# --- Core state ---
var logic: RefCounted
var ai: RefCounted
var cells: Array[Control] = []
var player_piece: int = 1
var ai_piece: int = 2
var input_enabled: bool = false  # Starts disabled — MatchManager/SceneRunner enables when ready
var _animating: bool = false

var player_style: Resource = null
var opponent_style: Resource = null
var _next_move_style_override: Resource = null
var _skip_turn_switch: bool = false
var pre_move_hook_enabled: bool = false
var external_input_control: bool = false
var auto_ai_enabled: bool = true

var player_color: Color = Color(0.2, 0.6, 1.0)
var opponent_color: Color = Color(1.0, 0.3, 0.3)
var player_design: Resource = null
var opponent_design: Resource = null

var game_rules: Resource = null

# --- Modules ---
var pieces: RefCounted       # BoardPieces
var game_controller: RefCounted  # BoardGameController
var abilities: RefCounted    # BoardAbilityController
var state_manager: RefCounted    # BoardStateManager

# --- Node references ---
@onready var grid: GridContainer = %GridContainer
@onready var board_frame: PanelContainer = %BoardFrame
@onready var status_label: Label = %StatusLabel
@onready var piece_layer: Control = %PieceLayer
@onready var opponent_hand_area: Control = $"VBoxContainer/OpponentHandArea"
@onready var player_hand_area: Control = $"VBoxContainer/PlayerHandArea"
@onready var ability_bar: HBoxContainer = %AbilityBar

var _board_config: Resource = null
var screen_effects: Control = null
var board_audio: Node = null
var _win_line_node: Control = null


func _ready() -> void:
	# Start invisible — MatchManager fades in after configure
	modulate.a = 0.0
	if game_rules == null:
		game_rules = GameRulesScript.new()
	logic = BoardLogicScript.new(game_rules)
	ai = AIPlayerScript.new()
	ai.difficulty = 0.3

	player_style = PlacementStyleScript.slam()
	opponent_style = PlacementStyleScript.gentle()
	if player_design == null:
		player_design = PieceDesignScript.x_design()
	if opponent_design == null:
		opponent_design = PieceDesignScript.o_design()

	# Initialize modules
	pieces = BoardPiecesScript.new(self)
	game_controller = BoardGameControllerScript.new(self)
	abilities = BoardAbilityControllerScript.new(self)
	state_manager = BoardStateManagerScript.new(self)

	# Screen effects overlay (above piece_layer)
	screen_effects = Control.new()
	screen_effects.set_script(ScreenEffectsScript)
	add_child(screen_effects)

	# Board audio
	board_audio = Node.new()
	board_audio.set_script(BoardAudioScript)
	add_child(board_audio)

	abilities.setup_defaults()
	abilities.connect_ui()

	_create_cells()
	_connect_signals()

	await get_tree().process_frame
	await get_tree().process_frame
	_start_game()

	get_tree().get_root().size_changed.connect(_on_resized)
	resized.connect(_on_resized)


# --- Cell management ---

func _create_cells() -> void:
	var total = game_rules.get_total_cells()
	var cols = game_rules.get_width()
	grid.columns = cols
	for i in range(total):
		var cell = Control.new()
		cell.set_script(CellScript)
		cell.cell_index = i
		cell.custom_minimum_size = Vector2(10, 10)
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.size_flags_vertical = Control.SIZE_EXPAND_FILL
		# Checkerboard: determine if dark cell based on row+col parity
		var row = i / cols
		var col = i % cols
		cell.is_dark_cell = ((row + col) % 2 == 1)
		if _board_config:
			_apply_config_to_cell(cell)
		cell.cell_clicked.connect(_on_cell_clicked)
		grid.add_child(cell)
		cells.append(cell)


func _apply_config_to_cell(cell: Control) -> void:
	cell.color_empty = _board_config.cell_color_empty
	cell.color_alt = _board_config.cell_color_alt
	cell.checkerboard = _board_config.checkerboard_enabled
	cell.color_hover = _board_config.cell_color_hover
	cell.color_line = _board_config.cell_line_color
	cell.line_width = _board_config.cell_line_width


func _connect_signals() -> void:
	EventBus.board_input_enabled.connect(_on_input_toggle)
	EventBus.layout_transition_finished.connect(_on_layout_transition_finished)
	# Reflow pieces on every resize (keeps pieces aligned during layout transitions)
	resized.connect(_on_board_resized)


func _on_board_resized() -> void:
	if cells.is_empty():
		return
	pieces.snap_layout()


func _start_game() -> void:
	game_controller.start_game()


func _on_cell_clicked(index: int) -> void:
	if not input_enabled or _animating or logic.game_over:
		return
	game_controller.handle_cell_click(index)


# --- Public API ---

func apply_board_config(config: Resource) -> void:
	## Apply a BoardConfig resource to update visual settings.
	_board_config = config
	var margin_node = $VBoxContainer/MarginContainer
	if margin_node:
		margin_node.add_theme_constant_override("margin_left", config.margin_h)
		margin_node.add_theme_constant_override("margin_right", config.margin_h)
		margin_node.add_theme_constant_override("margin_top", config.margin_v)
		margin_node.add_theme_constant_override("margin_bottom", config.margin_v)
	var aspect_node = $VBoxContainer/MarginContainer/CenterContainer/AspectRatioContainer
	if aspect_node:
		if config.max_board_size > 0:
			var s: int = config.max_board_size
			aspect_node.custom_minimum_size = Vector2(s, s)
		else:
			aspect_node.custom_minimum_size = Vector2(100, 100)
	if opponent_hand_area:
		opponent_hand_area.custom_minimum_size.y = config.hand_area_height
	if player_hand_area:
		player_hand_area.custom_minimum_size.y = config.hand_area_height
	# Apply board border
	_apply_board_border(config)
	player_color = config.default_player_color
	opponent_color = config.default_opponent_color
	for cell in cells:
		_apply_config_to_cell(cell)
		cell.queue_redraw()
	for p in pieces.player_pieces:
		if is_instance_valid(p):
			p.piece_color = player_color
			p.queue_redraw()
	for p in pieces.opponent_pieces:
		if is_instance_valid(p):
			p.piece_color = opponent_color
			p.queue_redraw()
	if is_inside_tree() and not cells.is_empty():
		call_deferred("_deferred_snap_layout")


func _apply_board_border(config: Resource) -> void:
	if not board_frame:
		return
	if config.board_border_enabled:
		var style = StyleBoxFlat.new()
		style.bg_color = config.board_bg_color
		style.border_color = config.board_border_color
		var bw = int(config.board_border_width)
		style.border_width_left = bw
		style.border_width_right = bw
		style.border_width_top = bw
		style.border_width_bottom = bw
		var cr = max(2, bw / 3)
		style.set_corner_radius_all(cr)
		style.content_margin_left = bw
		style.content_margin_right = bw
		style.content_margin_top = bw
		style.content_margin_bottom = bw
		board_frame.add_theme_stylebox_override("panel", style)
	else:
		var empty_style = StyleBoxFlat.new()
		empty_style.bg_color = Color.TRANSPARENT
		board_frame.add_theme_stylebox_override("panel", empty_style)


func _deferred_snap_layout() -> void:
	pieces.snap_layout()


func full_reset(new_rules: Resource = null) -> void:
	## Tear down and rebuild the board INSTANTLY. No deferred cleanup.
	input_enabled = false
	_animating = false
	if new_rules:
		game_rules = new_rules

	# Clear win line IMMEDIATELY
	if _win_line_node and is_instance_valid(_win_line_node):
		_win_line_node.get_parent().remove_child(_win_line_node)
		_win_line_node.free()
		_win_line_node = null

	# Clear existing pieces (includes effect players) IMMEDIATELY
	pieces.clear_all_pieces()

	# Clear existing cells IMMEDIATELY
	for c in cells:
		if is_instance_valid(c):
			c.get_parent().remove_child(c)
			c.free()
	cells.clear()

	# Rebuild
	logic = BoardLogicScript.new(game_rules)
	_create_cells()
	_start_game()


func setup_rules(rules: Resource) -> void:
	game_rules = rules


func set_player_style(s: Resource) -> void:
	player_style = s


func set_opponent_style(s: Resource) -> void:
	opponent_style = s


func override_next_style(s: Resource) -> void:
	_next_move_style_override = s


func refresh_piece_colors() -> void:
	## Update all existing pieces to match current player/opponent colors.
	for p in pieces.player_pieces:
		if is_instance_valid(p):
			p.piece_color = player_color
			p.queue_redraw()
	for p in pieces.opponent_pieces:
		if is_instance_valid(p):
			p.piece_color = opponent_color
			p.queue_redraw()


func set_piece_emotion(_is_player: bool, _emotion: String) -> void:
	pass  # Deprecated: emotions replaced by PieceDesign system


func trigger_ai_turn() -> void:
	await game_controller.trigger_ai_turn()


func save_board_state() -> Dictionary:
	return state_manager.save()


func load_board_state(state: Dictionary) -> void:
	await state_manager.load_state(state)


func apply_ability(ability: Resource, is_player: bool) -> Dictionary:
	return abilities.apply_ability(ability, is_player)


# --- Resize handling ---

func _on_resized() -> void:
	pieces.schedule_reflow()


func _on_layout_transition_finished() -> void:
	pieces.schedule_reflow()


func _update_input_state() -> void:
	game_controller.update_input_state()


func _on_input_toggle(enabled: bool) -> void:
	input_enabled = enabled
	game_controller.update_input_state()
