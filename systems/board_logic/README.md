# Sistema 1: Board Logic

Lógica pura del juego. No sabe nada de visuales, animaciones, ni tiempo. Todo es instantáneo y determinista.

## Responsabilidades

- Estado del tablero (celdas, turnos, game over)
- Validación de movimientos
- Detección de victoria, empate, patrones
- Reglas configurables (tamaño, fichas para ganar, rotación, N jugadores)
- IA con minimax paranoid (funciona para 2-6 jugadores)
- Serialización de estado (save/load para partidas simultáneas)

## NO es responsable de

- Animaciones de fichas (→ Board Visuals)
- Delays entre turnos (→ Match Orchestrator)
- Diálogos o reacciones (→ Scene Runner)
- Colores o estilos visuales (→ Board Visuals)

## API Principal

### BoardLogic
```
make_move(index) → {success, removed_cell}
get_valid_moves() → Array[int]
reset()
get_state() / load_state(state)
detect_patterns(last_move, piece) → Array[String]
piece_to_string(piece) → String
piece_color(piece) → Color  (estático, para UI de test)
get_all_players() → Array[int]
```

### GameRules
```
num_players: int (2-6)
board_size: int
win_length: int
max_pieces_per_player: int (-1 = ilimitado)
overflow_mode: "rotate" | "block"
allow_draw: bool
get_total_cells() → int
get_pieces_for(player_id) → int
get_win_patterns() → Array
```

### AIPlayer
```
difficulty: float (0.0 = random, 1.0 = óptimo)
choose_move(board) → int
```

## Jugadores

Identificados por enteros: 0 = vacío, 1..N = jugadores.

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
