class_name SceneParser
extends RefCounted

## Parses .dscn text files into command arrays.
##
## Returns Dictionary:
##   type: "cutscene" | "reactions"
##   name: String
##   background: String
##   commands: Array[Dictionary]          (cutscene mode)
##   reactions: Dictionary[String, Array] (reactions mode)


static func parse_file(path: String) -> Dictionary:
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		push_error("SceneParser: can't open %s" % path)
		return {"type": "cutscene", "name": "", "background": "", "commands": [], "reactions": {}}
	var text = file.get_as_text()
	file.close()
	return parse(text)


static func parse(text: String) -> Dictionary:
	var result = {
		"type": "cutscene",
		"name": "",
		"background": "",
		"commands": [],
		"reactions": {},
	}

	var is_reaction_mode := false
	var current_event := ""
	var current_cmds: Array = []
	var in_choose := false
	var choose_options: Array = []

	for raw_line in text.split("\n"):
		var line = raw_line.strip_edges()

		# Skip blanks and comments
		if line.is_empty() or line.begins_with("#"):
			continue

		# --- Choose block ---
		if in_choose:
			if line == "[end_choose]":
				in_choose = false
				var cmd = {"type": "choose", "options": choose_options.duplicate()}
				if is_reaction_mode and current_event != "":
					current_cmds.append(cmd)
				elif not is_reaction_mode:
					result.commands.append(cmd)
				choose_options.clear()
				continue
			elif line.begins_with(">"):
				var opt_text = line.substr(1).strip_edges()
				var arrow = opt_text.find("->")
				if arrow >= 0:
					var t = opt_text.substr(0, arrow).strip_edges()
					var f = opt_text.substr(arrow + 2).strip_edges()
					choose_options.append({"text": t, "flag": f})
				continue

		if line == "[choose]":
			in_choose = true
			choose_options.clear()
			continue

		# --- Directives ---
		if line.begins_with("@"):
			if line.begins_with("@scene "):
				result.name = line.substr(7).strip_edges()
				result.type = "cutscene"
			elif line.begins_with("@reactions "):
				result.name = line.substr(11).strip_edges()
				result.type = "reactions"
				is_reaction_mode = true
			elif line.begins_with("@background "):
				result.background = line.substr(12).strip_edges()
			elif line.begins_with("@on "):
				current_event = line.substr(4).strip_edges()
				current_cmds = []
			elif line == "@end_on":
				if current_event != "":
					result.reactions[current_event] = current_cmds.duplicate()
					current_event = ""
					current_cmds.clear()
			elif line == "@end":
				if current_event != "":
					result.reactions[current_event] = current_cmds.duplicate()
					current_event = ""
					current_cmds.clear()
			continue

		# --- Parse command ---
		var cmd = _parse_line(line)
		if cmd.is_empty():
			continue

		if is_reaction_mode and current_event != "":
			current_cmds.append(cmd)
		elif not is_reaction_mode:
			result.commands.append(cmd)

	return result


# ---- Line parsers ----

static func _parse_line(line: String) -> Dictionary:
	if line.begins_with("[") and line.ends_with("]"):
		return _parse_bracket(line.substr(1, line.length() - 2).strip_edges())

	# Dialogue:  character "expression": text
	# Directed:  character "expression" -> target: text
	var colon_pos = line.find(": ")
	if colon_pos > 0:
		return _parse_dialogue(line, colon_pos)

	return {}


static func _parse_bracket(content: String) -> Dictionary:
	var parts = content.split(" ", false)
	if parts.is_empty():
		return {}

	var cmd = parts[0].to_lower()
	match cmd:
		"enter":
			# [enter WHO POSITION] or [enter WHO POSITION FROM_DIR]
			return {"type": "enter", "character": _s(parts, 1), "position": _s(parts, 2, "center"), "enter_from": _s(parts, 3, "")}
		"depth":
			# [depth WHO SCALE DURATION]
			return {"type": "depth", "character": _s(parts, 1), "depth": _f(parts, 2, 1.0), "duration": _f(parts, 3, 0.4)}
		"exit":
			return {"type": "exit", "character": _s(parts, 1), "direction": _s(parts, 2, "")}
		"shake":
			return {"type": "shake", "intensity": _f(parts, 1, 0.5), "duration": _f(parts, 2, 0.3)}
		"flash":
			return {"type": "flash", "color": _s(parts, 1, "white"), "duration": _f(parts, 2, 0.3)}
		"wait":
			return {"type": "wait", "duration": _f(parts, 1, 1.0)}
		"if":
			if parts.size() >= 3 and parts[1] == "flag":
				return {"type": "if_flag", "flag": parts[2]}
		"else":
			return {"type": "else"}
		"end_if":
			return {"type": "end_if"}
		"set_flag":
			return {"type": "set_flag", "flag": _s(parts, 1)}
		"clear_flag":
			return {"type": "clear_flag", "flag": _s(parts, 1)}
		"board_enable":
			return {"type": "board_enable"}
		"board_disable":
			return {"type": "board_disable"}
		"set_style":
			return {"type": "set_style", "target": _s(parts, 1), "style": _s(parts, 2)}
		"set_emotion":
			return {"type": "set_emotion", "target": _s(parts, 1), "emotion": _s(parts, 2)}
		"override_next_style":
			return {"type": "override_next_style", "style": _s(parts, 1)}
		"expression":
			return {"type": "expression", "character": _s(parts, 1), "expression": _s(parts, 2)}
		"music":
			return {"type": "music", "track": _s(parts, 1)}
		"sfx":
			return {"type": "sfx", "sound": _s(parts, 1)}
		"stop_music":
			return {"type": "stop_music"}
		# --- New commands ---
		"look_at":
			return {"type": "look_at", "character": _s(parts, 1), "target": _s(parts, 2, "center")}
		"pose":
			return {"type": "pose", "character": _s(parts, 1), "state": _s(parts, 2, "idle")}
		"move":
			return {"type": "move", "character": _s(parts, 1), "position": _s(parts, 2, "center")}
		"focus":
			return {"type": "focus", "character": _s(parts, 1, "")}
		"clear_focus":
			return {"type": "clear_focus"}
		# --- Layout / Camera ---
		"fullscreen":
			return {"type": "layout", "mode": "fullscreen"}
		"split":
			return {"type": "layout", "mode": "split"}
		"board_only":
			return {"type": "layout", "mode": "board_only"}
		"close_up":
			return {"type": "close_up", "character": _s(parts, 1), "zoom": _f(parts, 2, 1.4), "duration": _f(parts, 3, 0.5)}
		"pull_back":
			return {"type": "pull_back", "character": _s(parts, 1), "zoom": _f(parts, 2, 0.8), "duration": _f(parts, 3, 0.5)}
		"camera_reset":
			return {"type": "camera_reset", "duration": _f(parts, 1, 0.4)}
		"camera_mode":
			return {"type": "camera_mode", "mode": _s(parts, 1, "smooth")}
		"camera_snap":
			return {"type": "camera_snap", "character": _s(parts, 1), "zoom": _f(parts, 2, 1.4)}
		"background":
			return {"type": "background", "source": _s(parts, 1, "")}
		"title_card":
			# [title_card Title Text | Subtitle Text] or [title_card Title Text]
			var full_text = " ".join(parts.slice(1))
			var pipe = full_text.find("|")
			if pipe >= 0:
				return {"type": "title_card", "title": full_text.substr(0, pipe).strip_edges(), "subtitle": full_text.substr(pipe + 1).strip_edges()}
			return {"type": "title_card", "title": full_text.strip_edges(), "subtitle": ""}

	push_warning("SceneParser: unknown command [%s]" % content)
	return {}


static func _parse_dialogue(line: String, colon_pos: int) -> Dictionary:
	var before = line.substr(0, colon_pos).strip_edges()
	var text = line.substr(colon_pos + 2).strip_edges()  # +2 to skip ": "

	var character := ""
	var expression := ""
	var target := ""

	# Check for directed dialogue:  character "expr" -> target
	var arrow_pos = before.find(" -> ")
	if arrow_pos >= 0:
		target = before.substr(arrow_pos + 4).strip_edges()
		before = before.substr(0, arrow_pos).strip_edges()

	# Parse character and expression
	var q1 = before.find("\"")
	if q1 >= 0:
		character = before.substr(0, q1).strip_edges()
		var q2 = before.find("\"", q1 + 1)
		if q2 > q1:
			expression = before.substr(q1 + 1, q2 - q1 - 1)
	else:
		character = before

	var result = {"type": "dialogue", "character": character, "expression": expression, "text": text}
	if target != "":
		result["target"] = target
	return result


# ---- Helpers ----

static func _s(arr: Array, idx: int, fallback: String = "") -> String:
	return arr[idx] if idx < arr.size() else fallback

static func _f(arr: Array, idx: int, fallback: float = 0.0) -> float:
	return float(arr[idx]) if idx < arr.size() else fallback
