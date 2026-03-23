# DSL Reference

> Referencia del lenguaje de scripting de escenas `.dscn`. **Aun no implementado** — este documento define el diseno objetivo para Phase 3.

---

## Estructura de archivo

```
@scene nombre_escena
@background nombre_fondo

(comandos de escena)

@end
```

## Tipos de archivo

### Cutscenes (lineales)
Se ejecutan de principio a fin. Usadas para intros, outros, transiciones.

### Reacciones (event-driven)
Bloques `@on` que se disparan cuando el tablero emite un patron.

```
@reactions nombre_partida

@on nombre_evento
(comandos)
@end_on

@end
```

---

## Comandos

### Dialogo
```
character_id "expresion": Texto del dialogo aqui.
```
- `character_id`: id registrado en character_data (ej: `akira`, `player`)
- `expresion`: nombre de expresion (ej: `smirk`, `angry`, `neutral`). Vacio `""` para sin cambio
- Pausa la ejecucion hasta que el jugador avance

### Personajes
| Comando | Descripcion |
|---|---|
| `[enter WHO WHERE]` | Personaje entra. WHERE: `left`, `center`, `right` |
| `[exit WHO]` | Personaje sale |
| `[expression WHO EXPR]` | Cambiar expresion sin dialogo |

### Efectos de camara
| Comando | Descripcion |
|---|---|
| `[shake INTENSITY DURATION]` | Sacudir pantalla |
| `[flash COLOR DURATION]` | Flash de pantalla (COLOR: white, red, etc.) |
| `[zoom LEVEL DURATION]` | Zoom (no implementado aun) |

### Timing
| Comando | Descripcion |
|---|---|
| `[wait SECONDS]` | Pausa sin input |

### Audio (futuro)
| Comando | Descripcion |
|---|---|
| `[music TRACK]` | Cambiar musica de fondo |
| `[sfx SOUND]` | Reproducir efecto de sonido |
| `[stop_music]` | Parar musica |

### Tablero
| Comando | Descripcion |
|---|---|
| `[board_enable]` | Activar input del tablero |
| `[board_disable]` | Desactivar input del tablero |
| `[set_style WHO STYLE]` | Cambiar estilo de colocacion |
| `[set_emotion WHO EMOTION]` | Cambiar emocion de piezas |
| `[override_next_style STYLE]` | Override para siguiente movimiento |

### Condicionales
```
[if flag NOMBRE_FLAG]
(comandos si flag es true)
[else]
(comandos si flag es false)
[end_if]
```

### Flags
```
[set_flag NOMBRE_FLAG]
[clear_flag NOMBRE_FLAG]
```

---

## Eventos de tablero (para @on)

| Evento | Cuando se dispara |
|---|---|
| `center_taken_by_player` | Jugador pone pieza en el centro |
| `center_taken_by_opponent` | Oponente pone pieza en el centro |
| `corner_taken_by_player` | Jugador toma una esquina |
| `corner_taken_by_opponent` | Oponente toma una esquina |
| `player_near_win` | Jugador tiene 2 de 3 en una linea |
| `opponent_near_win` | Oponente tiene 2 de 3 en una linea |
| `player_fork` | Jugador crea doble amenaza |
| `opponent_fork` | Oponente crea doble amenaza |
| `player_piece_rotated` | Una pieza del jugador fue rotada (modo rotacion) |
| `opponent_piece_rotated` | Una pieza del oponente fue rotada |
| `move_count_N` | Se llego al movimiento N |
| `player_wins` | Jugador gana |
| `opponent_wins` | Oponente gana |
| `draw` | Empate |

---

## Ejemplo completo

```
@scene match_01_intro
@background gym_interior

[enter akira center]
akira "smirk": Asi que crees que puedes ganarme?
akira "confident": Llevo tres anos como campeon del club.

[enter player left]
player "nervous": (No puedo creer que este haciendo esto...)
player "determined": He estado practicando. Vamos.

[shake 1.0]
akira "intense": Entonces demuestralo!

[board_enable]
@end
```

```
@reactions match_01

@on center_taken_by_player
[board_disable]
[override_next_style dramatic]
[set_emotion opponent angry]
akira "surprised": El centro?!
[shake 0.5]
akira "angry": No creas que eso cambia nada!
[board_enable]
@end_on

@on player_near_win
[board_disable]
[set_emotion opponent surprised]
[override_next_style nervous]
akira "sweating": (No... tengo que bloquear!)
[board_enable]
@end_on

@on player_wins
[if flag chose_aggressive_style]
    player "fierce": Eso pasa cuando me subestimas!
[else]
    player "happy": Fue un juego renido...
[end_if]
akira "shocked": Imposible...!
@end_on
@end
```
