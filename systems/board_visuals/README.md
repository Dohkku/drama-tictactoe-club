# Sistema 2: Board Visuals

Representación visual del tablero. Celdas, fichas, animaciones de colocación, hand areas, reflow al redimensionar. No toma decisiones de juego.

## Responsabilidades

- Renderizar celdas (colores, checkerboard, bordes)
- Renderizar fichas (X, O, △, etc.) con colores por jugador
- Animaciones de colocación (lift → anticipation → arc → settle)
- Hand areas (fichas disponibles arriba/abajo del tablero)
- Reflow de piezas al cambiar tamaño
- Aplicar BoardConfig (colores, borde, patrón ajedrez)
- Estilos de colocación (gentle, slam, dramatic, nervous)

## NO es responsable de

- Decidir quién mueve (→ Board Logic / Match Orchestrator)
- IA (→ Board Logic)
- Diálogos o reacciones (→ Scene Runner)

## Estado: PENDIENTE
