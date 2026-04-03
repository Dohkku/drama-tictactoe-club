# Sistema 5: Scene Runner

Motor de ejecución de scripts narrativos (.dscn). Parsea el DSL y ejecuta comandos secuencialmente contra los sistemas de Cinematic y Board.

## Responsabilidades

- Parser de archivos .dscn (cinemáticas y reacciones)
- Ejecución secuencial de comandos con await
- Control de flujo: if/else/end_if, choose/end_choose, set_flag/clear_flag
- Comandos de personaje: enter, exit, move, expression, pose, look_at, focus
- Comandos de cámara: shake, flash, close_up, pull_back, camera_reset
- Comandos de layout: fullscreen, split, board_only
- Comandos de tablero: board_enable, board_disable, set_style, set_emotion
- Comandos de audio: music, sfx, stop_music
- Title cards: title_card
- Sistema de reacciones (event → command array)

## NO es responsable de

- Decidir CUÁNDO ejecutar scripts (→ Match Orchestrator)
- Renderizar personajes (→ Cinematic)
- Lógica del tablero (→ Board Logic)

## DSL Syntax (resumen)

```
@scene nombre              # Modo cinemática
@reactions nombre          # Modo reacciones
personaje "expr": texto    # Diálogo
[enter quien posicion]     # Comando entre corchetes
[title_card Título | Sub]  # Title card
[choose]                   # Elección
> Opción -> flag
[end_choose]
[if flag X] ... [else] ... [end_if]
```

## Estado: PENDIENTE
