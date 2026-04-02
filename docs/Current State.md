# Current State

> Ultima actualizacion: 2026-03-23

## Estado General

**Phase 2 completada.** El juego es jugable con piezas fisicas animadas, efectos de colocacion, reacciones narrativas (hardcodeadas), y habilidades especiales.

---

## Lo que funciona

### Tablero
- Grid 3x3 con celdas clickeables (mouse + touch)
- Piezas fisicas (X azul, O roja) con emociones que cambian color
- Piezas en "mano" debajo/arriba del tablero, se animan al colocar
- IA con dificultad configurable (minimax + random blend)
- Deteccion de victoria, empate, patrones (centro, esquina, near win, fork)

### Efectos de colocacion
- **Slam**: escala 1.5x y rebota
- **Rotate**: gira durante movimiento
- **Vibrate**: sacudida rapida
- **Bounce**: rebote vertical
- **Shockwave**: empuje radial de todas las piezas cercanas + spring back elastico
- Cada personaje tiene su estilo (Player: slam, Akira: spinning)
- Override por movimiento (ej: Akira usa dramatic cuando se enoja)

### Cinematicas
- Personajes entran/salen con tweens
- Expresiones cambian color del slot
- Dialogo con typewriter effect, avanza con click/touch
- Camera shake y flash
- Sincronizacion de emociones entre personaje y sus piezas

### Reglas configurables (preparado, no activado)
- `game_rules.gd` soporta: board_size variable, win_length, max_pieces (rotacion), overflow_mode, allow_overwrite, custom_win_patterns
- Presets: `standard()`, `rotating_3()`, `big_board()`
- board_logic.gd y board.gd ya usan GameRules

### Habilidades (demo)
- Steal: roba pieza oponente (Akira)
- Double Play: turno extra (Player)
- No hay UI para activarlas aun

---

## Lo que falta (proximo)

- **DSL de escenas** — todo esta hardcoded en main.gd
- **Sistema de partidas** — solo hay una partida que se repite
- **UI de habilidades** — existen pero no se pueden activar
- **Mas oponentes** — solo Akira
- **Audio** — silencio total
- **Arte** — rectangulos de colores

---

## Bugs conocidos / Notas

- `test_board_logic.gd` roto (make_move ahora retorna Dictionary, no bool)
- AI minimax manipula cells directamente, no soporta rotacion — suficiente para standard, necesita rewrite para rotating mode
- `ObjectDB instances leaked` warning al cerrar con --quit (normal, no es bug real)
