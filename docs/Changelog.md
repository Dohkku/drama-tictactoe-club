# Changelog

## 2026-03-28 — Phase 5 avances (IA + audio DSL + habilidades UI)

### Added
- UI de habilidades en `board.tscn` + `board.gd` para jugador:
  - Boton `Doble Jugada`
  - Boton `Robo`
- Integracion de habilidades con estado dinamico (enabled/disabled) segun turno/estado de partida.
- Ejecucion de comandos DSL de audio en `SceneRunner`:
  - `music`
  - `sfx`
  - `stop_music`
- Test de regresion para IA en modo rotativo en `board/test_board_logic.gd`.

### Changed
- `ai_player.gd` refactorizado para evaluar arbol usando `make_move()` + snapshot/load_state en vez de mutar `cells` directamente.
- Heuristicas de minimax mejoradas y limite de profundidad adaptable por tamaño/reglas.
- `steal_ability.gd` actualizado para no asumir tablero 3x3 fijo (usa `cells.size()`).

### Verified
- `./godot.sh --headless -s board/test_board_logic.gd` pasa incluyendo test de IA rotativa.
- `./godot.sh --headless --quit` arranca sin errores.

### Windows / cross-platform hardening
- `Settings._apply_window_mode()` actualizado para usar modo borderless consistente (windowed + borderless + maximized) en opcion "Sin Bordes".
- `SceneRunner` ahora normaliza rutas con separadores Windows (`\`) en carga de audio DSL.
- `SceneEditor` normaliza rutas al guardar scripts para evitar fallos por separadores de path.

---

## 2026-03-28 — Audit de estado real + documentacion actualizada

### Verified
- `board/test_board_logic.gd` ejecuta y pasa en headless.
- Startup headless (`./godot.sh --headless --quit`) sin crash.
- `main.gd` ya no depende de escenas hardcodeadas: carga `ProjectData` y delega en `MatchManager` + `SceneRunner`.

### Documented as implemented
- DSL de escenas funcional (`SceneParser` + `SceneRunner`) con cutscenes, reactions, condicionales, choices y comandos de layout/camara.
- Sistema de partidas funcional (`MatchConfig` + `MatchManager`) incluyendo modo simultanea con estado persistente por tablero.
- Editor in-game funcional (`editor_main`, `character_editor`, `tournament_editor`, `scene_editor`) con guardado/carga de proyecto en `user://current_project.tres`.
- Menu principal + settings persistentes (`Settings` autoload).
- Audio procedural de dialogo (`dialogue_audio.gd`) activo durante typewriter.

### Remaining known gaps (confirmados)
- UX del Scene Editor para crear archivo nuevo con nombre/ruta asistida.
- Expandir contenido (mas oponentes, guiones, arte final) y QA integral.

---

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
