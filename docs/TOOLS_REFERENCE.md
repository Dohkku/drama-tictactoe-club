# Cinematic & Board Visuals Tools Reference

Complete API documentation for all tools in the Drama Tic-Tac-Toe Club cinematic, camera, layout, and board visuals systems.

## Table of Contents

1. [Cinematic Stage](#cinematic-stage)
2. [Cinematic Camera](#cinematic-camera)
3. [Character Slot](#character-slot)
4. [Dialogue Box](#dialogue-box)
5. [Layout Manager](#layout-manager)
6. [Scene Runner](#scene-runner)
7. [Scene Parser / DSL](#scene-parser--dsl)
8. [Placement Styles](#placement-styles)
9. [Piece Effects](#piece-effects)
10. [Piece Designs](#piece-designs)
11. [Screen Effects](#screen-effects)
12. [Event Bus](#event-bus)
13. [Game State](#game-state)

---

## Cinematic Stage

**File:** `/systems/cinematic/cinematic_stage.gd`

The central hub for managing character appearances, positions, and cinematic effects. Handles character registration, entrance/exit animations, expressions, body states, and virtual camera control.

### Constants

| Name | Value | Description |
|------|-------|-------------|
| `POSITIONS` | Dict | Named stage positions as fractions (0.0=left, 1.0=right) |
| `CHAR_ASPECT` | 0.60 | Character width/height ratio |
| `CHAR_HEIGHT_RATIO` | 0.92 | Character height as fraction of stage |
| `CHAR_MAX_WIDTH_FRAC` | 0.45 | Maximum character width fraction |
| `MOVE_DURATION` | 0.5 | Default move animation duration |

### Position Names

Available positions in `POSITIONS`:
- `"far_left"` - 0.08
- `"left"` - 0.22
- `"center_left"` - 0.36
- `"center"` - 0.50 (default)
- `"center_right"` - 0.64
- `"right"` - 0.78
- `"far_right"` - 0.92

### Registration Methods

#### `register_character(data: Resource) -> void`
Register a character's data for later reference. Must be called before entering the character on stage.

**Parameters:**
- `data` - CharacterData resource containing display_name, color, expressions, etc.

#### `get_character_data(character_id: String) -> Resource`
Retrieve registered character data.

**Returns:** CharacterData resource or null

### Character Entry/Exit

#### `enter_character(character_id: String, position_name: String = "center", enter_from: String = "") -> void`
Bring a character onto the stage. Automatically determines entry direction based on position if `enter_from` is empty.

**Parameters:**
- `character_id` - Unique identifier for the character
- `position_name` - Position key from POSITIONS dict
- `enter_from` - Override entry direction: `"left"`, `"right"`, or empty for auto

**Behavior:**
- If already on stage, repositions silently
- "player" character_id is skipped (no visual representation)
- Emits `EventBus.character_entered` signal

#### `exit_character(character_id: String, direction: String = "") -> void`
Remove a character from the stage with an exit animation.

**Parameters:**
- `character_id` - Character to remove
- `direction` - Exit direction: `"left"`, `"right"`, or empty for auto

**Behavior:**
- Auto-calculates direction from current position if empty
- Emits `EventBus.character_exited` signal

### Movement

#### `move_character(character_id: String, new_position: String) -> void`
Animate a character to a new stage position.

**Parameters:**
- `character_id` - Character to move
- `new_position` - Target position key from POSITIONS

**Duration:** 0.5 seconds (eased quadratic)

### Depth & Z-Order

#### `set_character_depth(character_id: String, depth: float, duration: float = 0.4) -> void`
Simulate z-depth by scaling and shifting character position.

**Parameters:**
- `character_id` - Target character
- `depth` - Scale multiplier (1.0=normal, >1=closer/larger, <1=farther/smaller)
- `duration` - Animation duration in seconds

**Behavior:**
- `depth > 1.0`: Character appears closer (scaled up, shifted down)
- `depth < 1.0`: Character appears farther (scaled down, shifted up)
- Y-offset calculated as: `(depth - 1.0) * 30.0` pixels
- Z-index set to `int(depth * 10)` for layering

### Expressions & State

#### `set_character_expression(character_id: String, expression: String) -> void`
Change character's facial expression with fade transition.

**Parameters:**
- `expression` - Expression name (e.g., "neutral", "happy", "sad")

**Behavior:**
- Fades to 0.7 alpha, applies new expression image, fades back to 1.0
- Falls back to portrait image if expression not found
- Falls back to character color if no images available

#### `set_character_speaking(character_id: String, speaking: bool) -> void`
Highlight the speaking character and dim others.

**Parameters:**
- `speaking` - true to set as speaker, false to clear

**Behavior:**
- Speaker scales to 1.05x
- Speaker z_index set to 10
- Non-speakers z_index set to 0

#### `set_body_state(character_id: String, state: String) -> void`
Set character's body pose/animation state.

**Parameters:**
- `state` - Body state name (see Character Slot for available states)

#### `set_look_at(character_id: String, target: String) -> void`
Set character's gaze direction.

**Parameters:**
- `target` - Either another character_id or direction: `"left"`, `"right"`, `"away"`, `"center"`

**Behavior:**
- If target is another character on stage, auto-calculates relative direction
- Applies subtle position shift to portrait

#### `set_talk_target(character_id: String, target: String) -> void`
Set who the character is addressing (for directed dialogue).

**Parameters:**
- `target` - Character_id being addressed

**Behavior:**
- Calls `set_look_at()` automatically

### Focus

#### `set_focus(character_id: String) -> void`
Highlight a single character, dimming others for narrative focus.

**Parameters:**
- `character_id` - Character to focus on

**Behavior:**
- Focused character at 1.0 alpha, z_index 10
- Others at 0.5 alpha, z_index 0

#### `clear_focus() -> void`
Restore all characters to normal brightness.

### Camera & Zoom (Virtual Camera)

#### `camera_close_up(character_id: String, zoom: float = 1.4, _duration: float = 0.5) -> void`
Zoom smoothly into a character's face.

**Parameters:**
- `character_id` - Target character
- `zoom` - Scale factor (1.4 = 40% zoom in)
- `_duration` - Not used; timing determined by camera mode

**Behavior:**
- Dims non-target characters to 0.3 alpha
- Uses camera mode's default duration (SMOOTH or SNAPPY)
- Sets `_camera_active = true`

#### `camera_pull_back(character_id: String, zoom: float = 0.8, _duration: float = 0.5) -> void`
Zoom out smoothly from a character.

**Parameters:**
- `character_id` - Target character
- `zoom` - Scale factor (0.8 = zoom out)

#### `camera_snap_to(character_id: String, zoom: float = 1.4) -> void`
Snappy fast zoom into a character with speed lines effect.

**Parameters:**
- `character_id` - Target character
- `zoom` - Scale factor

**Behavior:**
- Uses SNAPPY mode (0.2s duration, EASE_OUT + TRANS_BACK)
- Plays speed lines effect
- Dims non-target characters quickly

#### `camera_reset(_duration: float = 0.4) -> void`
Reset camera to default view (no zoom, centered).

**Duration:** Uses camera mode's default (0.6s SMOOTH or 0.2s SNAPPY)

**Behavior:**
- Restores all characters to 1.0 alpha
- Sets `_camera_active = false`

#### `set_camera_mode(mode_str: String) -> void`
Set camera animation style.

**Parameters:**
- `mode_str` - `"snappy"` (0.2s, bouncy) or `"smooth"` (0.6s, cubic)

#### `get_camera() -> CinematicCamera`
Get the camera instance for direct access.

### Stage Management

#### `set_background(source: Variant) -> void`
Set the stage background.

**Parameters:**
- `source` - Color (as Color) or resource path (as String)

#### `clear_stage() -> void`
Remove all characters and reset camera.

**Behavior:**
- Queues all characters for deletion
- Clears internal dictionaries
- Resets camera to default

#### `get_character_color(character_id: String) -> Color`
Get character's registered color for dialogue box styling.

**Returns:** Color or Color.WHITE if not registered

#### `get_characters_on_stage() -> Array`
Get array of all character_ids currently on stage.

### Title Cards

#### `show_title_card(title: String, subtitle: String = "", duration: float = 2.5) -> void`
Display a centered title card overlay with optional subtitle.

**Parameters:**
- `title` - Main title text (large, 36pt)
- `subtitle` - Optional subtitle (20pt, dimmer)
- `duration` - How long the card stays visible (excluding fade in/out)

**Behavior:**
- Fades in over 0.5s
- Stays visible for `duration` seconds
- Fades out over 0.5s
- Total time = 1.0s + duration

---

## Cinematic Camera

**File:** `/systems/cinematic/cinematic_camera.gd`  
**Class:** `CinematicCamera extends RefCounted`

Virtual camera system that manipulates Control node transforms without requiring Camera2D. Simulates pan/zoom for cinematic focus.

### Enum

```
enum Mode { SMOOTH, SNAPPY }
```

### Constants

| Name | Value | Description |
|------|-------|-------------|
| `SMOOTH_DURATION` | 0.6 | Smooth zoom animation duration |
| `SNAPPY_DURATION` | 0.2 | Fast snap zoom duration |

### Methods

#### `setup(layer: Control, stage: Control) -> void`
Initialize the camera with references to the character layer and stage.

#### `focus_character(char_position: Vector2, char_size: Vector2, zoom: float = 1.3, mode: int = -1) -> void`
Zoom to center on a character.

**Parameters:**
- `char_position` - Character's current position
- `char_size` - Character's size
- `zoom` - Scale factor (1.3 = 30% zoom in)
- `mode` - Optional Mode override (-1 = use current mode)

**Math:** Centers character on screen by adjusting layer pivot_offset and position.

#### `focus_position(world_pos: Vector2, zoom: float = 1.3, mode: int = -1) -> void`
Zoom to an arbitrary position.

**Parameters:**
- `world_pos` - World position within the layer to focus on
- `zoom` - Scale factor
- `mode` - Optional Mode override

#### `reset(mode: int = -1) -> void`
Reset to default view (zoom=1.0, centered).

**Parameters:**
- `mode` - Optional Mode override

#### `set_mode(mode: Mode) -> void`
Set the camera animation style.

#### `get_mode() -> Mode`
Get current camera mode.

#### `is_active() -> bool`
Check if camera is currently zoomed in.

**Returns:** true if scale != (1.0, 1.0)

---

## Character Slot

**File:** `/systems/cinematic/character_slot.gd`  
**Extends:** Control

Represents a single character on stage. Handles portrait rendering, expressions, body states, and animations.

### Signals

```gdscript
signal entrance_finished()
signal exit_finished()
```

### Properties

| Name | Type | Description |
|------|------|-------------|
| `character_data` | Resource | Loaded CharacterData |
| `current_expression` | String | Current expression name |
| `is_speaking` | bool | Whether character is currently speaking |
| `body_state` | String | Current body pose state |
| `look_target` | String | Character being looked at or direction |
| `talk_target` | String | Character being addressed |
| `show_debug_border` | bool | Show green debug outline |

### Constants

| Name | Value |
|------|-------|
| `ENTER_DURATION` | 0.5 |
| `EXIT_DURATION` | 0.4 |
| `EXPRESSION_FADE_DURATION` | 0.15 |

### Entry/Exit Methods

#### `enter_character(data: Resource, from_direction: String = "right") -> void`
Play entry animation for a character.

**Parameters:**
- `data` - CharacterData resource
- `from_direction` - `"left"`, `"right"`, or other (slides in from off-screen)

**Behavior:**
- Sets name_label, applies default pose/look from data
- Slides in from off-screen
- Fades in over 0.3s (duration is 0.5s)
- Emits `entrance_finished` signal

#### `exit_character(to_direction: String = "right") -> void`
Play exit animation.

**Parameters:**
- `to_direction` - Direction to exit toward

**Behavior:**
- Fades out over 0.4s
- Slides off-screen
- Clears all state
- Emits `exit_finished` signal

### Expression & Speaking

#### `set_expression(expr_name: String) -> void`
Change character expression with fade transition.

**Parameters:**
- `expr_name` - Expression name

**Duration:** 0.3s total (0.15s fade out, 0.15s fade in)

#### `set_speaking(speaking: bool) -> void`
Animate speaking state (scale effect).

**Parameters:**
- `speaking` - true to highlight, false to normalize

**Behavior:**
- Scales to 1.05x when speaking, 1.0x when not
- 0.15s duration

### Body States

#### `set_body_state(new_state: String) -> void`
Set the character's body pose/animation.

**Available states:**
- `"idle"` - Default
- `"thinking"` - Darken slightly (introspective)
- `"arms_crossed"` - Scale to 0.95x horizontally
- `"leaning_forward"` - Scale to 1.08x (3 frames)
- `"leaning_back"` - Scale to 0.92x (3 frames)
- `"excited"` - Bouncing loop with bright tint
- `"tense"` - Red tint + micro-vibration
- `"confident"` - Scale to 1.05x + bright tint
- `"defeated"` - Scale down + desaturate

### Look Direction

#### `set_look_direction(target: String) -> void`
Set character's gaze direction.

**Parameters:**
- `target` - Direction: `"left"`, `"right"`, `"away"`, `"center"`, or character_id

**Behavior:**
- Uses subtle position shift (no rotation)
- Shift amount: `size.x * 0.03` pixels
- 0.25s transition

#### `set_talk_to(target: String) -> void`
Set who the character is addressing.

**Parameters:**
- `target` - Character_id being talked to

### Focus

#### `set_focus(focused: bool) -> void`
Highlight or dim this character.

**Parameters:**
- `focused` - true to highlight, false to dim

**Behavior:**
- Focused: alpha 1.0
- Unfocused: alpha 0.5
- 0.2s transition

---

## Dialogue Box

**File:** `/systems/cinematic/dialogue_box.gd`  
**Extends:** PanelContainer

Displays character dialogue with typewriter effect, choices, and character-specific styling.

### Properties

| Name | Type | Description |
|------|------|-------------|
| `is_active` | bool | Dialogue is currently visible/active |
| `is_typing` | bool | Text is currently being typed |
| `name_label` | Label | Speaker name display |
| `text_label` | RichTextLabel | Dialogue text (supports BBCode) |
| `advance_indicator` | Label | "Click to continue" indicator |

### Display Methods

#### `show_dialogue(speaker: String, text: String, speaker_color: Color = Color.WHITE, character_data: Resource = null) -> void`
Display character dialogue with typewriter effect.

**Parameters:**
- `speaker` - Speaker name/title
- `text` - Dialogue text (supports DSL tags: `[wait]`, `[trigger]`)
- `speaker_color` - Speaker name color
- `character_data` - Optional character resource for styling and voice

**Behavior:**
- Processes text through DialogueTextProcessor (handles DSL tags)
- Applies character-specific panel styling (bg_color, border_color)
- Plays typing beeps with character's voice parameters
- Emits `EventBus.dialogue_started(speaker, text)`

#### `hide_dialogue() -> void`
Clear the dialogue box.

**Behavior:**
- Sets visible=false, is_active=false
- Clears character_data reference

### Typing Control

Typing happens automatically when `show_dialogue()` is called. The text progresses character-by-character at `_char_speed` (0.03s per character by default).

**User input:**
- Click/tap while typing: Skip to end (calls `_finish_typing()`)
- Click/tap after typing complete: Hide dialogue and emit `EventBus.dialogue_finished`

### Choices

#### `show_choices(options: Array, speaker_color: Color = Color.WHITE) -> void`
Display choice buttons for player decision.

**Parameters:**
- `options` - Array of {"text": String, "flag": String} dicts
- `speaker_color` - Optional (unused, kept for compatibility)

**Behavior:**
- Creates buttons for each option
- On button click: emits `EventBus.choice_made(flag)`
- Hides choice UI after selection

**Example:**
```gdscript
var options = [
  {"text": "I agree", "flag": "chose_agree"},
  {"text": "I disagree", "flag": "chose_disagree"}
]
dialogue_box.show_choices(options)
var chosen_flag = await EventBus.choice_made
```

### Text DSL Tags

Text can include special tags processed by DialogueTextProcessor:

- `[wait 0.5]` - Pause for 0.5 seconds at this position
- `[trigger ai_move]` - Emit `EventBus.dialogue_trigger("ai_move")`

---

## Layout Manager

**File:** `/systems/layout/layout_manager.gd`  
**Class:** `RefCounted`

Manages transitions between screen layout modes (fullscreen cinematic, split view, board-only).

### Signal

```gdscript
signal transition_finished(mode: String)
```

### Constants

```gdscript
const MODES := ["fullscreen", "split", "board_only"]
```

### Properties

| Name | Type | Description |
|------|------|-------------|
| `split_ratio` | float | Cinematic panel width as fraction (default 0.5) |
| `separator_width` | float | Divider width in pixels (default 6.0) |
| `separator_enabled` | bool | Show divider between panels (default true) |

### Methods

#### `setup(parent: Control, cinematic: Control, board: Control, sep: Control) -> void`
Initialize with panel references.

**Parameters:**
- `parent` - Container holding all panels
- `cinematic` - Cinematic stage panel
- `board` - Board/game panel
- `sep` - Separator divider

**Behavior:**
- Sets `clip_contents=true` on all panels (collapsed panels at width 0 are hidden)
- Connects to parent resize signal

#### `get_current_mode() -> String`
Get currently active layout mode.

#### `is_transitioning() -> bool`
Check if a transition is in progress.

#### `set_instant(mode: String) -> void`
Switch layouts immediately without animation.

**Parameters:**
- `mode` - `"fullscreen"` | `"split"` | `"board_only"`

#### `transition_to(mode: String, duration: float = 0.8) -> void`
Animate transition to a new layout mode.

**Parameters:**
- `mode` - Target mode
- `duration` - Animation duration in seconds

**Layout dimensions:**

| Mode | Cinematic Width | Board Width | Separator |
|------|-----------------|-------------|-----------|
| `fullscreen` | 100% | 0% (hidden) | Hidden (alpha 0) |
| `split` | 50% (adjustable) | 50% | Visible |
| `board_only` | 0% (hidden) | 100% | Hidden (alpha 0) |

**Behavior:**
- Sets `_transitioning=true`
- Animates position and size properties
- Emits `transition_finished(mode)` when complete

---

## Scene Runner

**File:** `/systems/scene_runner/scene_runner.gd`  
**Class:** `RefCounted`

Executes parsed scene commands from .dscn files. Orchestrates dialogue, character movement, camera effects, and board state changes.

### Methods

#### `setup(stage: Control, board: Control, dialogue_box: Control) -> void`
Initialize with scene components.

#### `load_reactions(reactions_dict: Dictionary) -> void`
Load event-triggered reactions.

**Parameters:**
- `reactions_dict` - Dict mapping event names to command arrays

#### `clear_reactions() -> void`
Clear all loaded reactions.

#### `has_reaction(event_name: String) -> bool`
Check if a reaction exists for an event.

#### `execute(data: Dictionary) -> void`
Execute a parsed scene.

**Parameters:**
- `data` - Result from `SceneParser.parse()` or `parse_file()`

**Fields used:**
- `data.background` - Optional background to set
- `data.commands` - Array of command dicts to execute

#### `trigger_reaction(event_name: String) -> void`
Execute a reaction by name if one exists.

### Command Reference

All commands are executed sequentially unless awaited. See [[Scene Parser / DSL](#scene-parser--dsl)] for syntax.

#### Dialogue Commands

- `dialogue` - Show dialogue (with expression, optional target)
- `choose` - Display choices and wait for selection
- `look_at` - Set character's gaze direction
- `pose` - Set character's body state
- `expression` - Change character's expression

#### Character Commands

- `enter` - Bring character onto stage
- `exit` - Remove character from stage
- `move` - Animate character to new position
- `depth` - Adjust z-depth (scale + position shift)
- `focus` - Highlight a character
- `clear_focus` - Restore all characters to normal

#### Camera Commands

- `close_up` - Zoom into character's face
- `pull_back` - Zoom out from character
- `camera_snap` - Fast snappy zoom with speed lines
- `camera_reset` - Return to default view
- `camera_mode` - Set camera animation style ("smooth" or "snappy")

#### Layout Commands

- `layout` - Transition between layout modes
- `fullscreen` - Shortcut for layout fullscreen
- `split` - Shortcut for layout split
- `board_only` - Shortcut for layout board_only

#### Visual Effects

- `shake` - Camera shake
- `flash` - Screen flash
- `wait` - Pause for duration
- `background` - Set background

#### State Management

- `set_flag` - Set a game flag to true
- `clear_flag` - Set a game flag to false
- `if_flag` - Conditional execution (with `else` and `end_if`)
- `board_enable` - Enable board input
- `board_disable` - Disable board input

#### Board Commands

- `set_style` - Set piece placement style for player/opponent
- `set_emotion` - Set piece emotion state
- `override_next_style` - Override next piece's style

#### Audio

- `music` - Play background music track
- `sfx` - Play sound effect
- `stop_music` - Stop current music

#### Other

- `title_card` - Show title card with optional subtitle

---

## Scene Parser / DSL

**File:** `/systems/scene_runner/scene_parser.gd`  
**Class:** `RefCounted static`

Parses text-based .dscn scene files into command arrays for SceneRunner.

### File Format

#### Structure

```
@scene [scene_name]
@background [color_or_path]

[command]
[command]
...

@reactions [reactions_name]
@on [event_name]
  [command]
  [command]
@end_on

@on [event_name2]
  [command]
@end_on
```

#### Methods

##### `static parse_file(path: String) -> Dictionary`
Load and parse a .dscn file.

**Returns:** Parsed result dict

##### `static parse(text: String) -> Dictionary`
Parse scene text.

**Returns:** Dictionary with:
- `type` - `"cutscene"` or `"reactions"`
- `name` - Scene name
- `background` - Background color/path
- `commands` - Array of command dicts
- `reactions` - Dict of event_name → command arrays

### Command Syntax

#### Dialogue

```
character "expression": text
character "expression" -> target: text
player "happy": I think so.
alice "neutral" -> bob: Hello, Bob!
```

#### Character Management

```
[enter character_id position]
[enter character_id position from_direction]
[exit character_id]
[exit character_id direction]
[move character_id position]

[enter alice center left]
[move bob right]
[exit charlie]
```

#### Expressions & States

```
[expression character_id expression_name]
[pose character_id state_name]
[look_at character_id target]

[expression alice angry]
[pose bob thinking]
[look_at charlie left]
```

#### Camera & Focus

```
[close_up character_id]
[close_up character_id zoom]
[close_up character_id zoom duration]
[pull_back character_id]
[pull_back character_id zoom]
[camera_reset]
[camera_mode smooth|snappy]
[camera_snap character_id]
[focus character_id]
[focus ""]

[close_up alice 1.5 0.6]
[camera_snap bob 1.4]
[focus charlie]
[focus ""]
```

#### Layout & Screen Effects

```
[fullscreen]
[split]
[board_only]
[shake intensity]
[shake intensity duration]
[flash color]
[flash color duration]
[wait duration]

[fullscreen]
[shake 0.5 0.3]
[flash red 0.2]
[wait 1.0]
```

#### Choices

```
[choose]
> Choice Text -> flag_name
> Another Choice -> another_flag
[end_choose]
```

#### State & Flags

```
[set_flag flag_name]
[clear_flag flag_name]
[if flag_name]
  [command]
[else]
  [command]
[end_if]
[set_style target style]
[set_emotion target emotion]
[override_next_style style]
```

#### Board Control

```
[board_enable]
[board_disable]
```

#### Audio

```
[music track_path]
[sfx sound_path]
[stop_music]

[music calm_theme]
[sfx impact]
```

#### Title Card

```
[title_card Title Text]
[title_card Title Text | Subtitle Text]
```

#### Depth (Z-ordering)

```
[depth character_id scale]
[depth character_id scale duration]

[depth alice 1.5 0.4]
```

### Parsing Details

**Dialogue format:**
- Character name, optional "expression", optional "-> target", then ": text"
- Expression and target are optional
- Colon separates metadata from text

**Bracket commands:**
- Space-separated parameters
- Numbers are parsed as floats where needed
- String parameters are case-sensitive

**Reactions:**
- Events trigger reactions when SceneRunner.trigger_reaction(event_name) is called
- Typically triggered by dialogue triggers: `[trigger event_name]`

---

## Placement Styles

**File:** `/systems/board_visuals/placement_style.gd`  
**Class:** `PlacementStyle extends Resource`

Configures piece movement animation parameters. Used when pieces are placed on the board.

### Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `lift_height` | float | 8.0 | How high piece lifts before moving |
| `anticipation_factor` | float | 0.3 | Wind-up distance fraction (0-1) |
| `arc_duration` | float | 0.25 | Time to fly to target |
| `settle_duration` | float | 0.1 | Final snap-into-place time |
| `spin_rotations` | float | 0.0 | Full rotations during arc |
| `shake_amount` | float | 0.0 | Pixel jitter on landing |
| `arc_stretch` | float | 0.0 | Stretch factor during flight |
| `impact_squash` | float | 0.0 | Squash factor on landing |
| `spring_bounces` | int | 0 | Spring oscillations (2-4 for bouncy) |

### Static Preset Methods

#### `static gentle() -> Resource`
Slow, delicate placement.

**Values:**
- lift: 6.0, anticipation: 0.1, arc: 0.8, settle: 0.3
- spin: 0, shake: 0, stretch: 0.1, squash: 0.1, bounces: 2

#### `static slam() -> Resource`
Fast, forceful placement.

**Values:**
- lift: 30.0, anticipation: 0.5, arc: 0.2, settle: 0.08
- spin: 0, shake: 0, stretch: 0.3, squash: 0.4, bounces: 3

#### `static spinning() -> Resource`
Spiraling placement with rotation.

**Values:**
- lift: 12.0, anticipation: 0.15, arc: 0.7, settle: 0.2
- spin: 2.0, shake: 0, stretch: 0.15, squash: 0.15, bounces: 2

#### `static dramatic() -> Resource`
High-impact, theatrical placement.

**Values:**
- lift: 50.0, anticipation: 0.6, arc: 0.6, settle: 0.25
- spin: 0, shake: 0, stretch: 0.25, squash: 0.35, bounces: 4

#### `static nervous() -> Resource`
Hesitant, jittery placement.

**Values:**
- lift: 4.0, anticipation: 0.05, arc: 0.35, settle: 0.4
- spin: 0, shake: 3.0, stretch: 0.2, squash: 0.1, bounces: 0

---

## Piece Effects

**File:** `/systems/board_visuals/piece_effect.gd`  
**Class:** `PieceEffect extends Resource`

Configures particle and visual effects for piece placement (trails, impacts, screen flash, propagation).

### Trail Properties

| Property | Type | Description |
|----------|------|-------------|
| `trail_enabled` | bool | Emit trail while flying |
| `trail_color` | Color | Particle color |
| `trail_amount` | int | Particles to emit |
| `trail_lifetime` | float | How long particles persist |
| `trail_spread` | float | Emission spread angle |
| `trail_velocity_min` | float | Particle min speed |
| `trail_velocity_max` | float | Particle max speed |
| `trail_scale` | float | Particle size |
| `trail_gravity` | Vector2 | Particle gravity (0,0 = float) |

### Impact Properties

| Property | Type | Description |
|----------|------|-------------|
| `impact_enabled` | bool | Burst on landing |
| `impact_color` | Color | Particle color |
| `impact_amount` | int | Particles to emit |
| `impact_lifetime` | float | Particle lifetime |
| `impact_spread` | float | Emission spread (180 = all directions) |
| `impact_velocity_min` | float | Min speed |
| `impact_velocity_max` | float | Max speed |
| `impact_scale` | float | Particle size |
| `impact_gravity` | Vector2 | Gravity direction |

### Visual Effects Properties

| Property | Type | Description |
|----------|------|-------------|
| `board_shake_intensity` | float | Board shake on impact (0 = none) |
| `board_shake_duration` | float | Shake duration |
| `screen_flash_enabled` | bool | Flash the screen |
| `screen_flash_color` | Color | Flash color |
| `screen_flash_duration` | float | Flash duration |
| `propagation_enabled` | bool | Expanding ring effect |
| `propagation_color` | Color | Ring color |
| `propagation_duration` | float | Ring duration |

### Static Preset Methods

#### `static none() -> Resource`
No effects.

#### `static fire() -> Resource`
Orange/red trail and impact with screen flash and propagation ring.

**Key settings:**
- Trail: Orange (1.0, 0.5, 0.1), 25 particles
- Impact: Red-orange (1.0, 0.4, 0.0), 40 particles, upward gravity
- Screen: Orange flash 0.08s
- Propagation: Orange ring 0.3s

#### `static sparkle() -> Resource`
Yellow/gold trail and impact with gentle upward gravity.

**Key settings:**
- Trail: Yellow (1.0, 1.0, 0.6), 15 particles
- Impact: Gold (1.0, 0.95, 0.7), 30 particles
- Gentle upward gravity on impact

#### `static smoke() -> Resource`
Gray particles rising upward.

**Key settings:**
- Trail: Gray (0.6, 0.6, 0.6), 12 particles, upward
- Impact: Darker gray (0.5, 0.5, 0.5), 20 particles, upward
- No gravity effects

#### `static shockwave() -> Resource`
Blue/white impact burst with screen flash and propagation.

**Key settings:**
- Trail: Disabled
- Impact: Blue-white (0.9, 0.9, 1.0), 50 particles, omnidirectional
- Screen: Blue flash 0.06s
- Propagation: Blue ring 0.25s
- Board shake: 6.0 intensity

#### `static all_effects() -> Array`
Returns array of all 5 effect presets.

#### `static effect_names() -> PackedStringArray`
Returns Spanish display names: ["Ninguno", "Fuego", "Chispas", "Humo", "Onda"]

---

## Piece Designs

**File:** `/systems/board_visuals/piece_design.gd`  
**Class:** `PieceDesign extends Resource`

Defines piece visual appearance (geometric shapes, text characters, or textures).

### Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `design_name` | String | "" | Display name |
| `design_type` | String | "geometric" | `"geometric"`, `"text"`, or `"texture"` |
| `geometric_shape` | String | "x" | Shape: "x", "o", "triangle", "square", "star", "diamond" |
| `text_character` | String | "" | Unicode character to display |
| `texture_image` | Texture2D | null | Texture for texture type |
| `line_width_factor` | float | 1.0 | Relative thickness |
| `fill` | bool | false | Filled vs outline |
| `body_shape` | String | "circle" | Piece body: "circle", "rounded_square", "hexagon", "diamond_body", "shield" |
| `body_color` | Color | (0,0,0,0) | Body color; transparent = use piece_color |
| `symbol_color` | Color | (0,0,0,0) | Symbol color; transparent = use piece_color |

### Static Preset Methods

#### Geometric Designs

```gdscript
static x_design() -> Resource      # "X" outline
static o_design() -> Resource      # "O" outline
static triangle_design() -> Resource
static square_design() -> Resource
static star_design() -> Resource
static diamond_design() -> Resource
```

#### Text Designs

```gdscript
static text_design(character: String, name: String) -> Resource
```

#### All Presets

```gdscript
static all_designs() -> Array
```

Includes: X, O, Triangle, Square, Star, Diamond, 火 (Fire), 龍 (Dragon), ♠ (Spade), ★ (Star)

### Body Shapes

Available body shapes for piece background:
- `"circle"` - Circular
- `"rounded_square"` - Rounded corners
- `"hexagon"` - Hexagonal
- `"diamond_body"` - Diamond shape
- `"shield"` - Shield shape

```gdscript
static body_shape_names() -> PackedStringArray
static body_shape_labels() -> PackedStringArray  # Spanish labels
```

---

## Screen Effects

**File:** `/systems/board_visuals/screen_effects.gd`  
**Extends:** Control

Screen-level overlay effects for the board. Handles flashes, propagation rings, win lines, and draw effects.

### Methods

#### `flash(color: Color, duration: float = 0.1) -> void`
Flash the screen with a color.

**Parameters:**
- `color` - Flash color
- `duration` - Fade-out duration

**Behavior:**
- Creates overlay that fades to transparent
- Auto-removes after animation

#### `play_win_line(positions: PackedVector2Array, color: Color = Color.WHITE, width: float = 6.0, duration: float = 0.4, glow: bool = true, pulse: bool = true, pulse_speed: float = 1.5) -> Control`
Animate a winning line (connects three pieces).

**Parameters:**
- `positions` - Array of global Vector2 positions (path points)
- `color` - Line color
- `width` - Line thickness
- `duration` - Time to draw the line
- `glow` - Outer glow effect
- `pulse` - Pulsing brightness after drawing
- `pulse_speed` - Pulse animation speed multiplier

**Behavior:**
- Draws progressively from first to last point
- Line pulses (breathes) after fully drawn
- Outer glow layer with partial transparency

**Returns:** The _WinLine control (can call queue_free() to remove early)

#### `propagation_ring(origin: Vector2, color: Color, max_radius: float = 200.0, duration: float = 0.3) -> void`
Play expanding ring effect from a point.

**Parameters:**
- `origin` - Global position (converts to local)
- `color` - Ring color
- `max_radius` - Expansion distance
- `duration` - How long to expand

**Behavior:**
- Ring expands and fades
- Auto-removes after animation

#### `play_draw_effect(board_rect: Rect2, duration: float = 1.2) -> void`
Play "draw" effect (board desaturation with cracks).

**Parameters:**
- `board_rect` - Board area to affect (global coordinates)
- `duration` - Total animation duration

**Phases:**
1. Gray wash fades in (40% of duration)
2. Hold (30% of duration)
3. Fade out (30% of duration)

**Behavior:**
- Overlays gray desaturation on board
- Generates random crack lines
- Auto-removes after animation

---

## Event Bus

**File:** `/autoloads/event_bus.gd`  
**Extends:** Node

Global signal hub for all major game events. Access via `EventBus.signal_name.connect(callback)`.

### Board Events

```gdscript
signal move_made(cell_index: int, piece: String)
signal board_state_changed(board: Array)
signal game_won(winner: String)
signal game_draw()
signal game_started()
signal turn_changed(whose_turn: String)
signal specific_pattern(pattern_name: String)
```

### Cinematic Events

```gdscript
signal dialogue_started(speaker: String, text: String)
signal dialogue_finished()
signal dialogue_trigger(trigger_name: String)      # Custom triggers in dialogue text
signal character_entered(character_id: String)
signal character_exited(character_id: String)
signal scene_script_finished(script_id: String)
```

### Match Management

```gdscript
signal match_started(match_config: Resource)
signal match_ended(result: String)
signal tournament_progressed(match_index: int)
signal before_ai_move()
signal pre_move_complete()
signal sim_board_rotate(opponent_id: String, match_index: int, total: int)
signal choice_made(flag: String)
```

### UI / Layout

```gdscript
signal transition_requested(transition_type: String)
signal board_input_enabled(enabled: bool)
signal layout_transition_requested(mode: String)    # "fullscreen", "split", "board_only"
signal layout_transition_finished()
```

### Debug

```gdscript
signal effect_triggered(effect_name: String, intensity: float)
```

---

## Game State

**File:** `/autoloads/game_state.gd`  
**Extends:** Node

Persistent game state manager. Access globally via `GameState.method_name()`.

### Properties

| Property | Type | Description |
|----------|------|-------------|
| `current_match_index` | int | Current match in tournament |
| `flags` | Dictionary | Game flag states |
| `match_history` | Array | Record of all matches |
| `character_affinity` | Dictionary | Character relationship tracking |

### Methods

#### `set_flag(flag_name: String, value: bool = true) -> void`
Set a game flag.

**Parameters:**
- `flag_name` - Flag identifier
- `value` - true or false

**Example:**
```gdscript
GameState.set_flag("met_alice", true)
GameState.set_flag("defeated_alice", false)
```

#### `get_flag(flag_name: String, default: bool = false) -> bool`
Retrieve a game flag.

**Parameters:**
- `flag_name` - Flag identifier
- `default` - Value if flag not set

**Example:**
```gdscript
if GameState.get_flag("met_alice"):
    print("Already met Alice")
```

#### `record_match(opponent_id: String, result: String) -> void`
Record a completed match.

**Parameters:**
- `opponent_id` - Opponent character_id
- `result` - "win", "loss", or "draw"

**Effect:**
- Appends to match_history array

#### `reset() -> void`
Clear all game state.

**Effect:**
- Resets current_match_index to 0
- Clears flags, match_history, character_affinity

---

## Integration Examples

### Complete Scene with Cinematic Effects

```gdscript
var parsed = SceneParser.parse("""
@scene intro
@background 0.95 0.91 0.85

[enter alice center left]
alice "happy": Hello! What's your name?
[pose bob thinking]
bob "neutral": I'm Bob.
[close_up alice 1.5 0.6]
alice "surprised": Nice to meet you!
[camera_reset 0.4]
[exit alice right]
[wait 1.0]
""")

# Execute the scene
await scene_runner.execute(parsed)
```

### Character Management Flow

```gdscript
# Register character
cinematic_stage.register_character(alice_data)

# Enter on stage
await cinematic_stage.enter_character("alice", "center_left", "left")

# Animate dialogue with expression changes
await cinematic_stage.set_character_expression("alice", "happy")
dialogue_box.show_dialogue("Alice", "Hello!")
await EventBus.dialogue_finished

# Cinematic focus
await cinematic_stage.camera_close_up("alice", 1.4)
dialogue_box.show_dialogue("Alice", "This is important...")
await EventBus.dialogue_finished
await cinematic_stage.camera_reset()

# Exit stage
await cinematic_stage.exit_character("alice", "right")
```

### Layout Transitions

```gdscript
# Start in fullscreen cinematic
layout_manager.set_instant("fullscreen")

# Transition to split for gameplay
await layout_manager.transition_to("split", 0.8)

# Back to cinematic
await layout_manager.transition_to("fullscreen", 0.8)

# Pure board view
await layout_manager.transition_to("board_only", 0.8)
```

### Piece Placement with Effects

```gdscript
# Apply custom style and effect
var placement_style = PlacementStyle.dramatic()
var piece_effect = PieceEffect.fire()

board.apply_style(placement_style)
board.apply_effect(piece_effect)

# Place piece (triggers animation)
await board.place_piece(cell_index, "player")
```

---

## Cross-System References

### Cinematic → Board

- SceneRunner commands can enable/disable board input
- Dialogue triggers can fire board reactions via EventBus
- Layout transitions show/hide board alongside cinematic

### Board → Cinematic

- Board state changes can trigger scene reactions
- Win/loss conditions can play end-game cinematic

### Camera & Layout

- CinematicCamera adjusts CharacterLayer transforms
- LayoutManager positions cinematic panel
- Resize events trigger repositioning in both

### Dialogue & Characters

- DialogueBox styles from CharacterData
- CharacterSlot voices from CharacterData
- Set_character_speaking highlights speaker

---

## Common Patterns

### Conditional Dialogue

```
[if flag_met_alice]
  alice "happy": Welcome back!
[else]
  alice "neutral": Who are you?
[end_if]
```

### Choice-Driven Branching

```
[choose]
> I agree -> chose_agree
> I disagree -> chose_disagree
[end_choose]

[if flag_chose_agree]
  alice "happy": Wonderful!
[end_if]
```

### Cinematic Sequence

```
[fullscreen]
[enter alice center]
[close_up alice 1.5 0.6]
alice "surprised": What?!
[camera_snap alice 1.4]
[shake 0.8 0.2]
[wait 0.5]
[camera_reset]
```

### Gameplay Flow

```
[split]
[board_enable]
[wait 5.0]  ; Give player time to move
[board_disable]
[fullscreen]
alice "angry": That was foolish!
```

---

**Last Updated:** 2026-04-03  
**Version:** 1.0  
**Format:** Obsidian-compatible Markdown

