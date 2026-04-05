# DSL Reference

> Referencia del lenguaje de scripting `.dscn` **actualmente implementado** en `scene_parser.gd` + `scene_runner.gd`.

---

## Estructura de archivo

### Cutscene
```text
@scene nombre_escena
@background gym_interior

(comandos)
@end
```

### Reacciones
```text
@reactions nombre_partida

@on evento_nombre
(comandos)
@end_on

@end
```

---

## Dialogo

```text
character_id "expresion": Texto...
character_id "expresion" -> target_id: Texto dirigido...
```

- `target_id` es opcional (hace que el speaker "mire" al target y muestre `A -> B` en nombre).
- El dialogo espera input del jugador (click/touch) para avanzar.

---

## Comandos soportados

### Personajes / escena
| Comando | Descripcion |
|---|---|
| `[enter WHO POSITION]` | Entra personaje |
| `[enter WHO POSITION FROM_DIR]` | Entra desde direccion explicita |
| `[exit WHO]` | Sale personaje |
| `[exit WHO DIRECTION]` | Sale en direccion especifica |
| `[move WHO POSITION]` | Mover personaje en stage |
| `[expression WHO EXPR]` | Cambia expresion |
| `[pose WHO STATE]` | Cambia pose/estado corporal |
| `[look_at WHO TARGET]` | Cambia direccion de mirada |
| `[focus WHO]` | Enfoca un personaje |
| `[clear_focus]` | Limpia enfoque |
| `[background SOURCE]` | Cambia fondo de stage |

### Camara / layout
| Comando | Descripcion |
|---|---|
| `[shake INTENSITY DURATION]` | Shake de camara |
| `[flash COLOR DURATION]` | Flash de pantalla |
| `[depth WHO SCALE DURATION]` | Simula profundidad por escala |
| `[close_up WHO ZOOM DURATION]` | Close-up |
| `[pull_back WHO ZOOM DURATION]` | Pull-back |
| `[camera_reset DURATION]` | Resetea camara |
| `[fullscreen]` | Layout full cinematic |
| `[split]` | Layout split |
| `[board_only]` | Layout solo tablero |

### Flujo
| Comando | Descripcion |
|---|---|
| `[wait SECONDS]` | Pausa |
| `[if flag FLAG]` | Condicional |
| `[else]` | Rama alternativa |
| `[end_if]` | Fin condicional |
| `[set_flag FLAG]` | Setea flag true |
| `[clear_flag FLAG]` | Setea flag false |
| `[choose] ... [end_choose]` | Bloque de elecciones |

Formato de opcion en choose:
```text
> Texto opcion -> flag_resultado
```

### Tablero
| Comando | Descripcion |
|---|---|
| `[board_enable]` | Habilita input de tablero |
| `[board_disable]` | Deshabilita input de tablero |
| `[set_style TARGET STYLE]` | Cambia estilo (`player`/`opponent`) |
| `[set_emotion TARGET EMOTION]` | Cambia emocion de piezas |
| `[override_next_style STYLE]` | Override para siguiente movimiento |
| `[set_difficulty VALUE]` | Dificultad IA en vivo (0.0-1.0). Persiste hasta fin partida |

### Audio
| Comando | Estado |
|---|---|
| `[music TRACK]` | Ejecutado en runner (reproduce `AudioStream`) |
| `[sfx SOUND]` | Ejecutado en runner (one-shot `AudioStream`) |
| `[stop_music]` | Ejecutado en runner (detiene musica actual) |

Notas:
- Acepta rutas directas (`res://...` / `user://...`) o lookup simple por nombre en `res://audio/music/` y `res://audio/sfx/`.
- El volumen usa `Settings.master_volume * Settings.music_volume|sfx_volume`.

---

## Tags de texto en dialogo

Procesadas por `DialogueTextProcessor`:

- `{b}...{/b}`
- `{i}...{/i}`
- `{color:...}...{/color}`
- `{shake}...{/shake}`
- `{wave}...{/wave}`
- `{rainbow}...{/rainbow}`
- `{trigger:accion}` (no visible; emite `EventBus.dialogue_trigger`)
- `{wait:segundos}` (no visible; pausa typewriter)

Implementado en runtime: trigger `ai_move` (hace que board dispare turno AI).

---

## Eventos comunes para `@on`

Emitidos desde patrones del tablero o fin de partida:

- `center_taken_by_player`, `center_taken_by_opponent`
- `corner_taken_by_player`, `corner_taken_by_opponent`
- `player_near_win`, `opponent_near_win`
- `player_fork`, `opponent_fork`
- `player_piece_rotated`, `opponent_piece_rotated`
- `move_count_N` (ej: `move_count_5`)
- `player_wins`, `opponent_wins`, `draw`
- `before_opponent_move` (usado por `MatchManager` antes del turno AI)
