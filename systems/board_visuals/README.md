# Sistema 2: Board Visuals

Renderizado y animación del tablero. No toma decisiones de juego ni gestiona turnos.

**Ubicación canónica**: `systems/board_visuals/`

## Responsabilidades

- Renderizado de celdas (colores, checkerboard, bordes, hover)
- Renderizado de piezas (X, O, sombra, glow, emociones)
- Animación de colocación (lift → anticipation → arc → settle)
- Hand areas (piezas disponibles arriba/abajo del tablero)
- Reflow de piezas al redimensionar
- Estilos de colocación (gentle, slam, dramatic, nervous, spinning)

## NO es responsable de

- Lógica del juego, turnos, IA (→ Board Logic)
- Flujo de partida, game over, señales (→ Board integration en `board/`)
- Habilidades (→ Board integration)
- Diálogos o reacciones (→ Scene Runner)

## Archivos

| Archivo | Descripción |
|---------|-------------|
| `cell.gd` | Celda individual: renderizado, hover, click, checkerboard |
| `piece.gd` | Pieza individual: renderizado X/O, emociones, animación 4-fases |
| `placement_style.gd` | Resource con parámetros de animación. Presets: gentle, slam, spinning, dramatic, nervous |
| `board_pieces.gd` | Gestión de piezas: creación, hand layout, cell-piece mapping, reflow |

## API

### Cell
```
cell_index: int
is_occupied: bool
checkerboard: bool
color_empty / color_alt / color_hover / color_line: Color
set_occupied(val)
set_input_enabled(val)
clear()
signal cell_clicked(index)
```

### Piece
```
piece_type: int (1=X, 2=O)
character_id: String
emotion: String
piece_color: Color
setup(type, char_id, color, expressions)
set_emotion(emotion)
play_move_to(target_pos, target_size, style, all_pieces)
```

### PlacementStyle
```
lift_height: float
anticipation_factor: float
arc_duration: float
settle_duration: float
Presets: gentle(), slam(), spinning(), dramatic(), nervous()
```

### BoardPieces
```
player_pieces / opponent_pieces: Array[Control]
cell_to_piece: Dictionary
create_all_pieces()
clear_all_pieces()
position_hand_pieces(animate)
snap_layout()
schedule_reflow()
get_cell_size() → Vector2
get_cell_pos_in_layer(index) → Vector2
get_piece_ratio() → float
```

## Test Scene

```bash
# Desde el dev menu o directamente:
godot --scene res://systems/board_visuals/test_scene.tscn
```

- Grid de celdas con click para colocar piezas
- IA oponente configurable
- Selector de estilo de animación (5 estilos)
- Selector de emoción de piezas
- Toggle checkerboard y borde
- Tamaño de tablero y máx fichas configurables
- Log de eventos
