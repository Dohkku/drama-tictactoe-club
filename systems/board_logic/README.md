# Sistema 1: Board Logic

Lógica pura del juego. No sabe nada de visuales, animaciones, ni tiempo. Todo es instantáneo y determinista.

**Ubicación canónica**: `systems/board_logic/` — todos los sistemas importan desde aquí.

## Responsabilidades

- Estado del tablero (celdas, turnos, game over)
- Validación de movimientos
- Detección de victoria, empate, patrones
- Reglas configurables (tamaño, fichas para ganar, rotación, N jugadores, celdas bloqueadas/especiales)
- IA con minimax paranoid (funciona para 2-6 jugadores)
- Serialización de estado (save/load para partidas simultáneas)
- Undo/redo

## NO es responsable de

- Animaciones de fichas (→ Board Visuals)
- Delays entre turnos (→ Match Orchestrator)
- Diálogos o reacciones (→ Scene Runner)
- Colores o estilos visuales (→ Board Visuals)

## API Principal

### BoardLogic
```
make_move(index) → MoveResult
get_valid_moves() → Array[int]
reset()
get_state() / load_state(state)
undo() / redo() / can_undo() / can_redo()
get_near_wins(piece) → Array[Dictionary]
check_winner(piece) → bool
check_draw_state() → bool
get_patterns_from_result(result) → Array[String]
detect_patterns(last_move, piece) → Array[String]  # legacy
piece_to_string(piece) → String
piece_color(piece) → Color  (estático, para UI de test)
get_all_players() → Array[int]
```

### MoveResult
```
success: bool
player: int
cell: int
removed_cell: int          # -1 si no hubo rotación
is_win: bool
is_draw: bool
winning_pattern: Array[int]
events: Array[Dictionary]  # Lista tipada de eventos
fail_reason: String        # Vacío si success

add_event(type, data)
has_event(type) → bool
get_events_of_type(type) → Array[Dictionary]
```

**Event types**: `piece_placed`, `piece_rotated`, `near_win`, `fork`, `win`, `draw`, `center_taken`, `corner_taken`, `turn_changed`, `special_cell_triggered`, `bonus_turn`, `skip_turn`

### GameRules
```
num_players: int (2-6)
board_size: int              # Cuadrado por defecto
board_width / board_height   # No-cuadrado (0 = usar board_size)
win_length: int
win_condition: String        # "n_in_row", "control_corners", "most_pieces", "custom_patterns"
max_pieces_per_player: int   # -1 = ilimitado
overflow_mode: String        # "rotate" | "block"
allow_draw: bool
blocked_cells: Array[int]
special_cells: Dictionary    # {index: {type: "bonus"|"trap"|"wild"}}

get_width() / get_height() → int
get_total_cells() → int
get_playable_cells() → int
get_pieces_for(player_id) → int
get_win_patterns() → Array
get_corners() → Array[int]
validate() → Array[String]  # Errores vacío = válido
```

**Presets**: `GameRules.standard()`, `GameRules.rotating_3()`, `GameRules.big_board()`, `GameRules.rectangular(w, h, win_len)`

### AIPlayer
```
difficulty: float (0.0 = random, 1.0 = óptimo)
max_search_depth_override: int (-1 = auto)
choose_move(board) → int
```

### Abilities
```
SpecialAbility (base):  reset(), can_use(board, state) → bool, apply(board, state) → Dictionary
├── StealAbility:       Convierte pieza de oponente (soporta N jugadores)
└── DoublePlayAbility:  Turno extra (skip_turn_switch)
```

## Jugadores

Identificados por enteros: 0 = vacío, -1 = bloqueada, 1..N = jugadores.

| ID | Label | Color |
|----|-------|-------|
| 1  | X     | Azul  |
| 2  | O     | Rojo  |
| 3  | △     | Verde |
| 4  | □     | Morado|
| 5  | ◇     | Naranja|
| 6  | ★     | Cyan  |

## Test Scene

```bash
bash godot.sh --scene res://systems/board_logic/test_scene.tscn
```

- Tablero clickeable con celdas válidas resaltadas
- Configurador de reglas (jugadores, tamaño, rotación, etc.)
- Toggle Human/IA por jugador con slider de dificultad
- Log con patrones detectados y resultado
