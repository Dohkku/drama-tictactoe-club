# Architecture

## Vista general de runtime

```
MainMenu (run/main_scene)
  ├── Jugar -> main.tscn
  └── Editor -> editor/editor_main.tscn

main.tscn
  ├── CinematicStage (personajes/camara/fondo)
  ├── Board (logica + render + IA)
  ├── DialogueBox (typewriter + choices + triggers)
  └── Debug log/UI
```

`main.gd` carga proyecto desde `user://current_project.tres` (si existe) o fallback a `data/resources/default_project.tres`.

---

## Autoloads

| Singleton | Archivo | Rol |
|---|---|---|
| `EventBus` | `autoloads/event_bus.gd` | Bus global de senales (board, scene runner, layout, match lifecycle) |
| `GameState` | `autoloads/game_state.gd` | Flags narrativos + historial de partidas |
| `Settings` | `autoloads/settings.gd` | Volumen/modo ventana + persistencia en `user://settings.cfg` |

---

## Sistemas principales

### 1) Board System (`board/`)
- `board_logic.gd`: logica pura (RefCounted), soporta `GameRules`, rotacion por overflow, patrones narrativos.
- `board.gd`: capa visual/interactiva, piezas fisicas en overlay, hand areas, AI turn orchestration, save/load board state.
- `ai_player.gd`: seleccion de movimientos por dificultad (random + minimax).
- `game_rules.gd`: presets (`standard`, `rotating_3`, `big_board`) y reglas parametrizables.

### 2) Cinematic System (`cinematic/`)
- `cinematic_stage.gd`: registro de personajes, entradas/salidas, focus/look_at, camara close-up/pull-back/reset.
- `character_slot.gd`: representacion visual de personaje y estados.
- `dialogue_box.gd`: typewriter + choices + tags procesados.
- `dialogue_text_processor.gd`: convierte tags DSL `{...}` a BBCode + triggers + waits.
- `dialogue_audio.gd`: audio procedural de tipeo por personaje.

### 3) Scene Script System (`scene_scripts/`)
- `parser/scene_parser.gd`: parsea `.dscn` (cutscene y reactions).
- `scene_runner.gd`: VM de ejecucion de comandos, integrando board/stage/dialogue.
- `scripts/*.dscn`: contenido narrativo editable.

### 4) Match System (`match_system/`)
- `match_config.gd`: config por partida.
- `match_manager.gd`: orquesta eventos de torneo:
  - `cutscene`
  - `match`
  - `simultaneous` (multi-oponente con rotacion de estado/tablero)

### 5) Editor System (`editor/`)
- `editor_main.gd`: shell con tabs y persistencia del proyecto.
- `character_editor.gd`: authoring de personajes.
- `tournament_editor.gd`: authoring de secuencia de eventos.
- `scene_editor.gd`: edicion + preview/playback de `.dscn`.

---

## Flujo de datos (alto nivel)

1. Usuario define contenido en Editor y guarda `user://current_project.tres`.
2. Runtime (`main.gd`) carga proyecto, registra personajes y crea secuencia de eventos.
3. `MatchManager` ejecuta evento actual:
   - Parsea scripts con `SceneParser`.
   - Ejecuta comandos con `SceneRunner`.
   - Coordina partidas via `Board`.
4. Señales via `EventBus` sincronizan transiciones de layout, dialogo, reacciones y turnos.

---

## Notas tecnicas clave

- Arquitectura desacoplada por señales (EventBus) + Resources serializables.
- `BoardLogic` y `AIPlayer` estan separados de UI (facil testing headless).
- Estado de tablero serializable para modo simultanea (`save_board_state` / `load_board_state`).
- `SceneRunner` soporta control de flujo (flags/if/choose), permitiendo narrativa reactiva.
