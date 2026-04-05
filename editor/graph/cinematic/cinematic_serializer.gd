class_name CinematicSerializer
extends RefCounted

## Bidirectional serialization between .dscn text and cinematic sub-canvas graph.

const SceneParserScript = preload("res://systems/scene_runner/scene_parser.gd")
const CmdNodeScript = preload("res://editor/graph/cinematic/cinematic_command_node.gd")
const StartNodeScript = preload("res://editor/graph/nodes/start_node.gd")
const EndNodeScript = preload("res://editor/graph/nodes/end_node.gd")
const GraphThemeC = preload("res://editor/graph/graph_theme.gd")

# Maps parser command types to category + command in CinematicCommandNode
const CMD_MAP := {
	"dialogue": ["dialogue", "dialogue"],
	"choose": ["dialogue", "choose"],
	"enter": ["char_action", "enter"],
	"exit": ["char_action", "exit"],
	"move": ["char_action", "move"],
	"expression": ["char_state", "expression"],
	"pose": ["char_state", "pose"],
	"look_at": ["char_state", "look_at"],
	"depth": ["char_state", "depth"],
	"focus": ["camera", "focus"],
	"clear_focus": ["camera", "clear_focus"],
	"close_up": ["camera", "close_up"],
	"pull_back": ["camera", "pull_back"],
	"camera_reset": ["camera", "camera_reset"],
	"camera_mode": ["camera", "camera_mode"],
	"camera_snap": ["camera", "camera_snap"],
	"shake": ["effect", "shake"],
	"flash": ["effect", "flash"],
	"layout": ["layout", "layout_%s"],  # mode appended
	"music": ["audio", "music"],
	"sfx": ["audio", "sfx"],
	"stop_music": ["audio", "stop_music"],
	"board_enable": ["board", "board_enable"],
	"board_disable": ["board", "board_disable"],
	"set_style": ["board", "set_style"],
	"set_emotion": ["board", "set_emotion"],
	"if_flag": ["logic", "if_flag"],
	"else": ["logic", "else"],
	"end_if": ["logic", "end_if"],
	"set_flag": ["logic", "set_flag"],
	"clear_flag": ["logic", "clear_flag"],
	"title_card": ["ui", "title_card"],
	"background": ["ui", "background"],
	"wait": ["ui", "wait"],
}


## Load .dscn text into graph nodes. Returns scene metadata {name, background}.
static func dscn_to_graph(text: String, graph_edit: GraphEdit, characters: Array) -> Dictionary:
	var data: Dictionary = SceneParserScript.parse(text)
	var commands: Array = data.get("commands", [])
	var meta := {"name": data.get("name", ""), "background": data.get("background", "")}

	# Create start node
	var start := StartNodeScript.new()
	start.position_offset = Vector2(50, 200)
	start.name = StringName(start.node_id)
	graph_edit.add_child(start)

	var prev_name: StringName = start.name
	var x: float = 350.0

	for cmd in commands:
		var cmd_type: String = cmd.get("type", "")
		if not CMD_MAP.has(cmd_type):
			continue

		var mapping: Array = CMD_MAP[cmd_type]
		var cat: String = mapping[0]
		var cmd_name: String = mapping[1]

		# Special case: layout commands
		if cmd_type == "layout":
			cmd_name = "layout_%s" % cmd.get("mode", "fullscreen")

		# Extract params (everything except "type")
		var params: Dictionary = {}
		for key in cmd:
			if key != "type":
				params[key] = cmd[key]

		var node := CmdNodeScript.new()
		node.category = cat
		node.command = cmd_name
		node.params = params
		node.available_characters = characters
		node.position_offset = Vector2(x, 200)
		node.name = StringName(node.node_id)
		graph_edit.add_child(node)

		# Connect flow
		graph_edit.connect_node(prev_name, 0, node.name, 0)
		prev_name = node.name
		x += 250.0

	# Create end node
	var end_node := EndNodeScript.new()
	end_node.position_offset = Vector2(x, 200)
	end_node.name = StringName(end_node.node_id)
	graph_edit.add_child(end_node)
	graph_edit.connect_node(prev_name, 0, end_node.name, 0)

	return meta


## Serialize graph nodes back to .dscn text.
static func graph_to_dscn(graph_edit: GraphEdit, scene_name: String, background: String) -> String:
	var lines: PackedStringArray = []
	lines.append("@scene %s" % scene_name)
	if background != "":
		lines.append("")
		lines.append("[background %s]" % background)
	lines.append("")

	# Walk flow from start node
	var start_node: GraphNode = null
	for child in graph_edit.get_children():
		if child is StartNodeScript:
			start_node = child
			break

	if start_node == null:
		return "\n".join(lines)

	var current_name: StringName = start_node.name
	var visited: Dictionary = {}

	while current_name != StringName(""):
		if visited.has(current_name):
			break
		visited[current_name] = true

		# Find next flow connection
		var next_name: StringName = StringName("")
		for conn in graph_edit.get_connection_list():
			if conn.from_node == current_name:
				next_name = conn.to_node
				break

		if next_name == StringName(""):
			break

		var node := graph_edit.get_node(String(next_name))
		if node is CmdNodeScript:
			var line: String = _node_to_dscn_line(node)
			if line != "":
				lines.append(line)

		current_name = next_name

	return "\n".join(lines) + "\n"


static func _node_to_dscn_line(node) -> String:
	var cmd: String = node.command
	var p: Dictionary = node.params

	match cmd:
		"dialogue":
			var line: String = p.get("character", "???")
			var expr: String = p.get("expression", "")
			if expr != "":
				line += " \"%s\"" % expr
			var target: String = p.get("target", "")
			if target != "":
				line += " -> %s" % target
			line += ": %s" % p.get("text", "...")
			return line
		"enter":
			return "[enter %s %s %s]" % [p.get("character", ""), p.get("position", "center"), p.get("enter_from", "")]
		"exit":
			return "[exit %s %s]" % [p.get("character", ""), p.get("direction", "")]
		"move":
			return "[move %s %s]" % [p.get("character", ""), p.get("position", "center")]
		"expression":
			return "[expression %s %s]" % [p.get("character", ""), p.get("expression", "neutral")]
		"pose":
			return "[pose %s %s]" % [p.get("character", ""), p.get("state", "idle")]
		"look_at":
			return "[look_at %s %s]" % [p.get("character", ""), p.get("target", "center")]
		"depth":
			return "[depth %s %s %s]" % [p.get("character", ""), p.get("depth", 1.0), p.get("duration", 0.4)]
		"focus":
			var ch: String = p.get("character", "")
			return "[focus %s]" % ch if ch != "" else "[focus]"
		"clear_focus": return "[clear_focus]"
		"close_up":
			return "[close_up %s %s %s]" % [p.get("character", ""), p.get("zoom", 1.4), p.get("duration", 0.5)]
		"pull_back":
			return "[pull_back %s %s %s]" % [p.get("character", ""), p.get("zoom", 0.8), p.get("duration", 0.5)]
		"camera_reset":
			return "[camera_reset %s]" % p.get("duration", 0.4)
		"camera_mode":
			return "[camera_mode %s]" % p.get("mode", "smooth")
		"camera_snap":
			return "[camera_snap %s %s]" % [p.get("character", ""), p.get("zoom", 1.4)]
		"shake":
			return "[shake %s %s]" % [p.get("intensity", 0.5), p.get("duration", 0.3)]
		"flash":
			return "[flash %s %s]" % [p.get("color", "white"), p.get("duration", 0.3)]
		"layout_fullscreen": return "[fullscreen]"
		"layout_split": return "[split]"
		"layout_board_only": return "[board_only]"
		"music": return "[music %s]" % p.get("track", "")
		"sfx": return "[sfx %s]" % p.get("sound", "")
		"stop_music": return "[stop_music]"
		"board_enable": return "[board_enable]"
		"board_disable": return "[board_disable]"
		"set_style": return "[set_style %s %s]" % [p.get("target", "player"), p.get("style", "slam")]
		"set_emotion": return "[set_emotion %s %s]" % [p.get("target", "player"), p.get("emotion", "neutral")]
		"if_flag": return "[if flag %s]" % p.get("flag", "")
		"else": return "[else]"
		"end_if": return "[end_if]"
		"set_flag": return "[set_flag %s]" % p.get("flag", "")
		"clear_flag": return "[clear_flag %s]" % p.get("flag", "")
		"title_card":
			var t: String = p.get("title", "")
			var s: String = p.get("subtitle", "")
			if s != "":
				return "[title_card %s | %s]" % [t, s]
			return "[title_card %s]" % t
		"background": return "[background %s]" % p.get("source", "")
		"wait": return "[wait %s]" % p.get("duration", 1.0)

	return ""
