class_name GraphTheme
extends RefCounted

## Shared constants for the node-based graph editor.

# ── Port type IDs (used by GraphEdit for connection validation) ──
const PORT_FLOW := 0
const PORT_CHARACTER := 1
const PORT_BOARD_CONFIG := 2
const PORT_SCRIPT := 3

# ── Port colors ──
const COLOR_FLOW := Color(0.85, 0.85, 0.9)
const COLOR_CHARACTER := Color(1.0, 0.65, 0.2)
const COLOR_BOARD_CONFIG := Color(0.3, 0.85, 0.9)
const COLOR_SCRIPT := Color(0.4, 0.85, 0.4)

# ── Node border accent colors ──
const COLOR_START := Color(0.3, 0.8, 0.35)
const COLOR_END := Color(0.85, 0.25, 0.25)
const COLOR_MATCH := Color(0.9, 0.25, 0.2)
const COLOR_CUTSCENE := Color(0.2, 0.45, 0.9)
const COLOR_BOARD := Color(0.3, 0.85, 0.9)
const COLOR_CHARACTER_NODE := Color(1.0, 0.65, 0.2)
const COLOR_SIMULTANEOUS := Color(0.65, 0.25, 0.85)
const COLOR_CANVAS_INSTANCE := Color(0.9, 0.75, 0.2)
const COLOR_COMMENT := Color(0.5, 0.5, 0.5)

# ── Validation ──
const COLOR_VALIDATION_ERROR := Color(0.9, 0.2, 0.2, 0.35)
const COLOR_VALIDATION_WARNING := Color(0.95, 0.7, 0.15, 0.3)
const COLOR_VALIDATION_OK := Color(0.3, 0.8, 0.4)
const COLOR_VALIDATION_PROBLEM := Color(0.95, 0.7, 0.15)

# ── Editor background ──
const COLOR_BG := Color(0.1, 0.1, 0.14)
const COLOR_PANEL_BG := Color(0.14, 0.15, 0.19)
const COLOR_NODE_BG := Color(0.18, 0.19, 0.24)
const COLOR_NODE_BG_SELECTED := Color(0.22, 0.23, 0.30)

# ── Text ──
const COLOR_TEXT := Color(0.9, 0.9, 0.92)
const COLOR_TEXT_DIM := Color(0.55, 0.55, 0.6)
const COLOR_TEXT_HEADER := Color(1.0, 1.0, 1.0)
const FONT_SIZE_HEADER := 15
const FONT_SIZE_NORMAL := 13
const FONT_SIZE_SMALL := 11

# ── Layout ──
const NODE_MIN_WIDTH := 180
const SNAP_DISTANCE := 20
const NODE_SEPARATION_X := 300
const NODE_SEPARATION_Y := 120


static func port_color(type: int) -> Color:
	match type:
		PORT_FLOW: return COLOR_FLOW
		PORT_CHARACTER: return COLOR_CHARACTER
		PORT_BOARD_CONFIG: return COLOR_BOARD_CONFIG
		PORT_SCRIPT: return COLOR_SCRIPT
	return COLOR_TEXT_DIM


static func node_style(accent_color: Color, selected: bool = false) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_NODE_BG_SELECTED if selected else COLOR_NODE_BG
	style.border_color = accent_color
	style.set_border_width_all(1)
	style.border_width_left = 4
	style.set_corner_radius_all(6)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style


static func titlebar_style(accent_color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = accent_color.darkened(0.6)
	style.border_color = accent_color
	style.set_border_width_all(0)
	style.border_width_bottom = 1
	style.set_corner_radius_all(0)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	return style
