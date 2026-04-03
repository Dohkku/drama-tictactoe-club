# Sistema 6: Match Orchestrator

El director de orquesta. Controla el flujo de un torneo: secuencia de cinematicas y partidas, partidas simultaneas, reacciones, y el ritmo entre turnos.

## Archivos

| Archivo | Rol |
|---|---|
| `match_manager.gd` | Orquestador principal (RefCounted) |
| `match_config.gd` | Resource con la configuracion de una partida |
| `match_sandbox.gd/.tscn` | Sandbox interactivo del dev menu |

## API publica (MatchManager)

```gdscript
# Setup: conecta al runner, board, stage, y config de proyecto
func setup(runner: RefCounted, board: Control, stage: Control, project_board_config: Resource = null) -> void

# Agregar eventos al torneo
func add_match(config: MatchConfig) -> void
func add_cutscene(script_path: String) -> void
func add_simultaneous(configs: Array) -> void

# Ejecutar la secuencia de eventos
func start() -> void  # awaitable

# Estado
func get_current_index() -> int
func get_event_count() -> int
```

## MatchConfig (Resource)

```gdscript
@export var match_id: String
@export var opponent_id: String           # character_id en CinematicStage
@export var ai_difficulty: float          # 0.0 - 1.0
@export var game_rules_preset: String     # DEPRECATED - usar board_config
@export var intro_script: String          # path a .dscn cutscene
@export var reactions_script: String      # path a .dscn reactions
@export var player_style: String          # "gentle", "slam", "spinning", etc.
@export var opponent_style: String
@export var turns_per_visit: int          # para modo simultaneo
@export var board_config: Resource        # BoardConfig (null = default del proyecto)
```

## Tipos de evento

| Tipo | Descripcion |
|---|---|
| `match` | Partida individual contra un oponente |
| `cutscene` | Ejecucion de un script .dscn |
| `simultaneous` | Round-robin multi-partida con rotacion de tableros |

## Flujo de una partida (match)

1. `_configure_board(config)` - reset + aplicar reglas, colores, estilos
2. Cargar reactions script del oponente
3. Habilitar `pre_move_hook` para reacciones pre-IA
4. Ejecutar intro cutscene (si hay)
5. Esperar `EventBus.match_ended`
6. Ejecutar reaccion de resultado (player_wins / opponent_wins / draw)
7. `GameState.record_match(opponent_id, result)`

## Flujo simultaneo

1. Ejecutar intros por oponente, guardar estado de cada tablero
2. Precargar reactions por oponente
3. Configurar board en modo externo (`external_input_control`, `auto_ai_enabled=false`)
4. Loop round-robin:
   - Rotar al siguiente oponente no terminado
   - Si la IA tiene turno pendiente, resolverlo
   - Dar al jugador `turns_per_visit` turnos
   - Guardar estado, marcar IA pendiente, rotar
5. Restaurar modo normal del board

## Signals usadas (EventBus)

- `match_ended(result: String)` - resultado de partida
- `turn_changed(whose_turn: String)` - cambio de turno
- `before_ai_move()` - pre-hook antes de turno IA
- `pre_move_complete()` - pre-hook completado
- `sim_board_rotate(opponent_id, match_index, total)` - rotacion en modo simultaneo
- `scene_script_finished(id: String)` - emitido como "tournament_complete" al finalizar

## Dependencias

- **Board** (visual + logic) - el tablero que se juega
- **CinematicStage** - personajes en escena
- **DialogueBox** - dialogos de reacciones e intros
- **SceneRunner / SceneParser** - ejecucion de scripts .dscn
- **GameState** (autoload) - registro de resultados
- **EventBus** (autoload) - comunicacion entre sistemas

## Responsabilidades

- Secuenciar eventos del torneo (cinematica -> partida -> cinematica -> ...)
- Configurar el tablero para cada partida (reglas, colores, estilos)
- Ejecutar scripts de intro y reacciones por partida
- Gestionar el hook pre-move de la IA (esperar reacciones, delays)
- Modo simultaneo: rotar entre tableros, save/load estado por oponente
- Limpiar escena entre eventos
- Registrar resultados en GameState

## NO es responsable de

- Logica del tablero (-> Board Logic)
- Visuales del tablero (-> Board Visuals)
- Ejecutar scripts (-> Scene Runner, que el invoca)
- Renderizar personajes (-> Cinematic)
