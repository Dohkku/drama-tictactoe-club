# Changelog

## 2026-03-23 — Game Rules + Shockwave Radial

### Added
- `game_rules.gd` — Reglas configurables: board_size, win_length, max_pieces_per_player, overflow_mode, allow_overwrite, allow_draw, custom_win_patterns
- Presets: `GameRules.standard()`, `GameRules.rotating_3()`, `GameRules.big_board()`
- Shockwave radial: todas las piezas empujadas desde el origen simultaneamente, luego spring back elastico
- Debug display (etiqueta verde top-right) mostrando efectos y movimientos
- Signal `effect_triggered` en EventBus

### Changed
- `board_logic.gd` reescrito para usar GameRules (board_size variable, rotacion, win patterns dinamicos)
- `make_move()` ahora retorna `Dictionary {success, removed_cell}` en vez de `bool`
- `board.gd` reescrito: piezas fisicas con mano, soporte rotacion visual, creacion dinamica de piezas segun reglas
- AI: draw check usa `cells.size()` en vez de hardcoded 9
- Shockwave usa single tween con `chain()` en vez de await en static func

---

## 2026-03-23 — Physical Pieces + Effects

### Added
- `piece.gd` — Pieza visual con custom _draw (X/O), emociones que cambian color
- `placement_style.gd` — Resource con estilo de movimiento y efectos
- `placement_effects.gd` — Efectos: slam, rotate, vibrate, bounce, shockwave
- Presets de estilo: gentle, slam, spinning, dramatic, nervous
- PieceLayer overlay para piezas fisicas
- Piezas se animan desde posicion de mano hasta celda del tablero

### Changed
- board.gd: redesenado para piezas fisicas en vez de dibujar en celdas
- cell.gd: simplificado a slot clickeable sin dibujar pieza

---

## 2026-03-23 — Cinematic Stage

### Added
- `cinematic_stage.gd/.tscn` — Panel con 3 slots de personaje
- `character_slot.gd/.tscn` — Tweens de entrada/salida, expresiones, speaking highlight
- `dialogue_box.gd` — Typewriter effect, click/touch to advance
- `camera_effects.gd` — Shake, flash
- `character_data.gd` — Resource para datos de personaje
- Personajes: Akira (rojo, antagonista), Player (azul)
- Reacciones narrativas: center taken, near win, game won/draw
- Habilidades: steal_ability, double_play_ability

---

## 2026-03-23 — Foundation

### Added
- Proyecto Godot 4.6 configurado (1280x720, autoloads, touch input)
- `event_bus.gd` — Bus de senales global
- `game_state.gd` — Estado persistente (flags, historial)
- `board_logic.gd` — Logica pura del juego (RefCounted)
- `board.gd` + `board.tscn` — Tablero visual con GridContainer
- `cell.gd` — Celda clickeable
- `ai_player.gd` — IA minimax con dificultad configurable
- `main.gd` + `main.tscn` — Split layout responsive
