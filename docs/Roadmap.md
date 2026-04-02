# Roadmap

## Phase 1: Fundacion (Tablero jugable) ✅

- [x] Configurar project.godot (ventana, autoloads)
- [x] EventBus con senales basicas
- [x] board_logic.gd (logica pura, testeable headless)
- [x] board.tscn + cell.tscn con GridContainer
- [x] main.tscn con split layout + placeholder izquierdo
- [x] AI basica (random + minimax)
- [x] Input tactil (touch + mouse)

**Resultado:** Jugar 3 en raya contra IA en pantalla dividida

---

## Phase 2: Escenario Cinematico ✅

- [x] character_data.gd + personajes placeholder (Akira, Player)
- [x] cinematic_stage.tscn con fondo + 3 slots (left/center/right)
- [x] character_slot.gd con tweens entrada/salida/expresion
- [x] dialogue_box.gd con efecto typewriter
- [x] camera_effects.gd (shake, flash)
- [x] Piezas fisicas con emociones (piece.gd)
- [x] Sistema de efectos composables (placement_effects.gd)
  - [x] Slam, rotate, vibrate, bounce, shockwave (radial)
- [x] PlacementStyle como Resource configurable por personaje
- [x] Sistema de habilidades especiales (steal, double_play)
- [x] GameRules configurable (board_size, rotation, win_length)
- [x] Debug display de efectos en pantalla
- [x] Layout responsive (horizontal/vertical)
- [x] Reacciones narrativas hardcodeadas en main.gd (center taken, near win, game over)

**Resultado:** Personajes aparecen, hablan, reaccionan. Piezas con personalidad.

---

## Phase 3: Sistema de Scripting DSL 🔜

> **EL CORAZON DEL PROYECTO** — Actualmente las escenas estan hardcoded en main.gd. Este sistema permite escribirlas en archivos `.dscn` de texto plano.

- [ ] scene_command.gd — Resource con tipo + parametros
- [ ] scene_script_parser.gd — Parser linea por linea -> Array de SceneCommand
- [ ] scene_runner.gd — VM que ejecuta comandos con await
- [ ] Primer .dscn de prueba (match_01_intro.dscn)
- [ ] Parser de reacciones (@on / @end_on)
- [ ] Condicionales (if_flag / else / end_if)
- [ ] Migrar intro y reacciones de main.gd a archivos .dscn
- [ ] Comandos: enter, exit, shake, wait, flash, music, sfx

**Resultado:** Escenas escritas en .dscn se ejecutan en el juego. Modificar un .dscn cambia la escena sin recompilar.

### Ejemplo de .dscn (cutscene)
```
@scene match_01_intro
@background gym_interior

[enter akira right]
[enter player left]

akira "smirk": Asi que crees que puedes ganarme?
akira "confident": Llevo tres anos como campeon del club.
player "nervous": (No puedo creer que este haciendo esto...)
player "determined": He estado practicando. Vamos.

[shake 0.5]
akira "intense": Entonces demuestralo!
@end
```

### Ejemplo de .dscn (reacciones)
```
@reactions match_01

@on center_taken_by_player
akira "surprised": El centro?!
[shake 0.3]
akira "angry": No creas que eso cambia nada!
@end_on

@on player_near_win
akira "sweating": (No... tengo que bloquear!)
@end_on
@end
```

---

## Phase 4: Sistema de Partidas

- [ ] match_config.gd — Resource: oponente, dificultad IA, scripts intro/reacciones/win/lose, reglas
- [ ] match_manager.gd — Orquesta: cutscene intro -> juego -> reacciones -> cutscene final
- [ ] tournament_manager.gd — Secuencia de partidas, progresion
- [ ] Transiciones entre partidas
- [ ] Dificultad de IA escalable por oponente
- [ ] Multiples oponentes con personalidades distintas

**Resultado:** Secuencia de 2-3 partidas con historia entre ellas

---

## Phase 5: Pulido y Contenido

- [ ] Arte real (reemplazar rectangulos)
- [ ] Audio (musica, SFX, voces)
- [ ] Efectos visuales avanzados
- [ ] Guiones completos para toda la historia
- [ ] Save/Load
- [ ] Menu principal, pausa, settings
- [ ] Localizacion

**Resultado:** Juego completo y pulido
