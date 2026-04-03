class_name DialogueTextProcessor
extends RefCounted

## Processes DSL text tags and converts them to Godot BBCode.
##
## Supported tags:
##   {b}...{/b}                -> [b]...[/b]
##   {i}...{/i}                -> [i]...[/i]
##   {color:NAME}...{/color}   -> [color=NAME]...[/color]
##   {shake}...{/shake}        -> [shake rate=20.0 level=5]...[/shake]
##   {wave}...{/wave}          -> [wave amp=50 freq=5]...[/wave]
##   {rainbow}...{/rainbow}    -> [rainbow freq=1.0 sat=0.8 val=0.8]...[/rainbow]
##   {trigger:NAME}            -> stripped from display, stored as trigger
##   {wait:SECONDS}            -> stripped from display, stored as wait


## Tag definitions: maps opening DSL tag patterns to their BBCode equivalents.
## Closing tags are handled generically.
const _TAG_MAP := {
	"b": "[b]",
	"/b": "[/b]",
	"i": "[i]",
	"/i": "[/i]",
	"/color": "[/color]",
	"shake": "[shake rate=20.0 level=5]",
	"/shake": "[/shake]",
	"wave": "[wave amp=50 freq=5]",
	"/wave": "[/wave]",
	"rainbow": "[rainbow freq=1.0 sat=0.8 val=0.8]",
	"/rainbow": "[/rainbow]",
}


## Process raw DSL text and return a result dictionary.
## Returns: { "bbcode": String, "triggers": Array, "waits": Array, "plain_length": int }
func process(raw_text: String) -> Dictionary:
	var bbcode := ""
	var triggers: Array = []
	var waits: Array = []
	var plain_length := 0  # Count of visible characters (no BBCode tags)

	var i := 0
	var length := raw_text.length()

	while i < length:
		if raw_text[i] == "{":
			# Find closing brace
			var close := raw_text.find("}", i)
			if close == -1:
				# No closing brace found; treat as literal
				bbcode += raw_text[i]
				plain_length += 1
				i += 1
				continue

			var tag_content := raw_text.substr(i + 1, close - i - 1)
			i = close + 1

			# Check for trigger tag: {trigger:NAME}
			if tag_content.begins_with("trigger:"):
				var trigger_name := tag_content.substr(8)  # len("trigger:") == 8
				triggers.append({"char_index": plain_length, "action": trigger_name})
				continue

			# Check for wait tag: {wait:SECONDS}
			if tag_content.begins_with("wait:"):
				var duration_str := tag_content.substr(5)  # len("wait:") == 5
				var duration := duration_str.to_float()
				waits.append({"char_index": plain_length, "duration": duration})
				continue

			# Check for color tag: {color:VALUE}
			if tag_content.begins_with("color:"):
				var color_value := tag_content.substr(6)  # len("color:") == 6
				bbcode += "[color=%s]" % color_value
				continue

			# Check static tag map
			if _TAG_MAP.has(tag_content):
				bbcode += _TAG_MAP[tag_content]
				continue

			# Unknown tag — pass through as literal text
			bbcode += "{%s}" % tag_content
			plain_length += tag_content.length() + 2  # +2 for braces
		else:
			bbcode += raw_text[i]
			plain_length += 1
			i += 1

	return {
		"bbcode": bbcode,
		"triggers": triggers,
		"waits": waits,
		"plain_length": plain_length,
	}
