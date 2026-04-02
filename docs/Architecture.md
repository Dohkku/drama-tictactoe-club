# Architecture

## Layout de Pantalla

```
+-------------------------+-------------------------+
|                         |                         |
|   CINEMATIC STAGE       |      TABLERO 3x3        |
|   (personajes,          |    (juego activo)        |
|    emociones,           |                          |
|    fondo)               |   [fichas en mano]       |
|                         |   [fichas en tablero]    |
|                         |                          |
+--------------------------+-------------------------+
|           CAJA DE DIALOGO (CanvasLayer overlay)    |
+----------------------------------------------------+
|           DEBUG LOG (CanvasLayer, top-right)        |
+----------------------------------------------------+
```

Responsive: `BoxContainer.vertical` cambia segun ancho del viewport (threshold: 800px).

---

## Autoloads (Singletons)

| Singleton | Archivo | Funcion |
|---|---|---|
| **EventBus** | `autoloads/event_bus.gd` | Bus de senales global. Tablero y escena NUNCA se hablan directamente |
| **GameState** | `autoloads/game_state.gd` | Flags narrativos, historial de partidas, afinidad |

---

## Estructura de Archivos

```
res://
├── autoloads/           EventBus, GameState
├── board/
│   ├── board.gd         Control visual del tablero
│   ├── board.tscn
│   ├── board_logic.gd   Logica pura (RefCounted, sin UI)
│   ├── cell.gd          Celda clickeable
│   ├── piece.gd         Pieza visual con emociones
│   ├── ai_player.gd     IA minimax + random
│   ├── game_rules.gd    Reglas configurables por partida
│   ├── placement_style.gd  Estilo de colocacion (Resource)
│   ├── placement_effects.gd  Efectos: slam, shockwave, etc.
│   └── abilities/
│       ├── special_ability.gd   Base class
│       ├── steal_ability.gd     Roba pieza del oponente
│       └── double_play_ability.gd  Turno extra
├── cinematic/
│   ├── cinematic_stage.gd/.tscn  Panel con slots de personaje
│   ├── character_slot.gd/.tscn   Personaje individual
│   ├── dialogue_box.gd           Typewriter + click to advance
│   └── camera_effects.gd         Shake, flash
├── characters/
│   └── character_data.gd         Resource: id, nombre, color, expresiones
├── scene_scripts/                (Phase 3 - vacio)
│   ├── parser/
│   └── scripts/
├── match_system/                 (Phase 4 - vacio)
├── main.gd                      Orquestador principal (temporal)
├── main.tscn
└── docs/                         Este vault de Obsidian
```

---

## Flujo de Senales

```
Click celda → board.gd → board_logic.make_move()
  → EventBus.move_made(cell_index, piece_string)
    → main.gd detecta patron
      → cinematic_stage muestra reaccion
        → dialogue_box avanza con click
          → EventBus.board_input_enabled(true)
            → tablero se reactiva
```

El tablero se **desactiva** durante cinematicas/dialogos.

---

## Patrones de Diseno

- **Event Bus**: Comunicacion desacoplada entre sistemas
- **Resource pattern**: GameRules, PlacementStyle, CharacterData como Resources configurables
- **RefCounted para logica**: BoardLogic, AIPlayer sin dependencia de Node
- **Composable effects**: PlacementStyle define lista de efectos que se ejecutan en secuencia
- **Physical pieces**: Piezas existen en PieceLayer overlay, se mueven con tweens desde "mano" a celda
