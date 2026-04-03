# Sistema 6: Match Orchestrator

El director de orquesta. Controla el flujo de un torneo: secuencia de cinemáticas y partidas, partidas simultáneas, reacciones, y el ritmo entre turnos.

## Responsabilidades

- Secuenciar eventos del torneo (cinemática → partida → cinemática → ...)
- Configurar el tablero para cada partida (reglas, colores, estilos)
- Ejecutar scripts de intro y reacciones por partida
- Gestionar el hook pre-move de la IA (esperar reacciones, delays)
- Modo simultáneo: rotar entre tableros, save/load estado por oponente
- Limpiar escena entre eventos
- Registrar resultados en GameState

## NO es responsable de

- Lógica del tablero (→ Board Logic)
- Visuales del tablero (→ Board Visuals)
- Ejecutar scripts (→ Scene Runner, que él invoca)
- Renderizar personajes (→ Cinematic)

## Flujo de una partida

```
1. Match Orchestrator recibe config de partida
2. Limpia escena, oculta tablero
3. Configura Board Logic con las reglas
4. Configura Board Visuals con colores del personaje
5. Ejecuta script de intro via Scene Runner
6. Habilita input del jugador
7. Por cada movimiento:
   a. Jugador coloca ficha → Board Logic valida
   b. Board Visuals anima la ficha
   c. Scene Runner ejecuta reacciones de patrones
   d. Match Orchestrator espera que las reacciones terminen
   e. Scene Runner ejecuta reacción pre-move de IA
   f. Board Logic calcula movimiento de IA
   g. Board Visuals anima ficha de IA
8. Al terminar: ejecuta reacción de victoria/derrota/empate
9. Registra resultado, avanza al siguiente evento
```

## Estado: PENDIENTE
