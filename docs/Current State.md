# Current State

> Ultima actualizacion: 2026-03-28

## Estado General

**El proyecto ya supero ampliamente Phase 2.** Hoy hay un loop jugable con menu principal, editor de proyecto, sistema DSL funcional, manager de torneo (incluyendo modo simultanea), y guardado/carga de proyecto.

---

## Lo que funciona

### Gameplay de tablero
- Grid configurable por reglas (`GameRules`), no hardcoded a 3x3.
- Piezas fisicas con "mano" superior/inferior, animaciones y reflow responsive en resize/layout transitions.
- Rotacion de piezas implementada visual + logica (`make_move()` retorna `{success, removed_cell}`).
- Deteccion de victoria/empate/patrones narrativos.
- Test headless de `BoardLogic` pasando (incluye modo rotacion).

### IA
- IA con mezcla random + minimax por dificultad.
- Minimax actualizado para simular movimientos con `make_move()` + snapshot/load_state, respetando reglas de rotacion/overflow.
- Se agrego test headless de regresion para IA en modo rotativo.

### DSL de escenas (`.dscn`) — implementado
- Parser real (`scene_scripts/parser/scene_parser.gd`) para cutscenes y reactions.
- Runner real (`scene_scripts/scene_runner.gd`) con `await` y control de flujo.
- Comandos activos:
  - Escena/personajes: `enter`, `exit`, `move`, `pose`, `look_at`, `expression`, `focus`, `clear_focus`
  - Camara/layout: `shake`, `flash`, `close_up`, `pull_back`, `camera_reset`, `fullscreen`, `split`, `board_only`
  - Flujo: `wait`, `if/else/end_if`, `choose`, `set_flag`, `clear_flag`
  - Tablero: `board_enable`, `board_disable`, `set_style`, `set_emotion`, `override_next_style`
  - Otros: `background`
- Reacciones por evento (`@on ... @end_on`) activadas via `EventBus.specific_pattern`.

### Match / Tournament system
- `MatchConfig` y `MatchManager` implementados.
- Pipeline de eventos soportado:
  - Cutscene
  - Match normal
  - Match simultanea (round-robin por tableros, estado persistente por oponente, `turns_per_visit`).
- Carga de reacciones por oponente y disparo de reacciones de fin (`player_wins`, `opponent_wins`, `draw`).
- Registro de historial en `GameState`.

### Editor in-game (funcional)
- Entrada desde menu principal (`Editor`).
- Tabs:
  - **Personajes:** id/nombre/color, expresiones, poses, voz, estilo default, retrato.
  - **Torneo:** secuencia visual de eventos (cutscene/match/simultaneous), reorder, configuracion por match.
  - **Escenas:** editor `.dscn` con lista de archivos, guardado y preview con playback/step.
- Persistencia de proyecto en `user://current_project.tres`.
- Boton **JUGAR** en editor: guarda y lanza `main.tscn`.

### UI base / settings
- Main menu como escena inicial.
- Panel de settings con volumen master y modo de ventana, persistidos en `user://settings.cfg`.
- Modo "Sin Bordes" ajustado para mayor consistencia cross-platform (windowed+borderless+maximized).

### Audio actual
- Audio de dialogo procedural: beeps por caracter con waveform/pitch/variation por personaje (`dialogue_audio.gd` + `dialogue_box.gd`).
- Comandos DSL de audio ahora ejecutan en runtime (`music`, `sfx`, `stop_music`) via `SceneRunner` con `AudioStreamPlayer`.

---

## Estado de contenido actual

- Personajes de data default: `player`, `akira`, `mei`.
- Scripts `.dscn` reales para:
  - Prologo
  - Intro/reacciones match 01
  - Intro/reacciones match 02
  - Intros de modo simultanea
- Proyecto default (`data/resources/default_project.tres`) ya usa esa estructura.

---

## Bugs conocidos / Notas

- `test_board_logic.gd` **ya no esta roto** (actualizado a retorno `Dictionary` y pasando).
- UI de habilidades implementada en tablero para jugador (`Doble Jugada`, `Robo`) con estado habilitado/deshabilitado dinamico.
- Normalizacion basica de rutas con `\` -> `/` en carga de audio DSL y guardado de scripts del Scene Editor.
- Queda pendiente mejorar UX/feedback visual avanzado de habilidades y balance.
