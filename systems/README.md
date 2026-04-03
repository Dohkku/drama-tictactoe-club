# Arquitectura de Sistemas

El juego está dividido en 6 sistemas independientes. Cada uno tiene su propia carpeta, su escena de test, y una responsabilidad clara. Se pueden desarrollar y probar por separado.

```
systems/
├── dev_menu.tscn          ← Menú para lanzar cada sistema
├── board_logic/           ← Sistema 1: Lógica pura
├── board_visuals/         ← Sistema 2: Tablero visual
├── cinematic/             ← Sistema 3: Personajes y cámara
├── layout/                ← Sistema 4: Gestión de paneles
├── scene_runner/          ← Sistema 5: Motor de scripts DSL
└── match/                 ← Sistema 6: Orquestador de partidas
```

## Principios

- **Sin dependencias cruzadas durante testing**: cada test scene funciona sola.
- **EventBus solo en integración final**: los sistemas se comunican por API directa en desarrollo.
- **Cada sistema exporta una API pública clara**: métodos documentados, sin acceder a estado interno de otros.
- **Los sistemas de arriba no saben de los de abajo**: Board Logic no sabe que existen visuales. Cinematic no sabe que existe un tablero.

## Flujo de datos en el juego final

```
Match Orchestrator (6)
  ├── Scene Runner (5)  ← ejecuta scripts .dscn
  │     ├── Cinematic (3)  ← personajes, cámara, diálogos
  │     └── Board Visuals (2)  ← animaciones de fichas
  ├── Board Logic (1)  ← estado del juego, IA
  └── Layout (4)  ← transiciones de paneles
```
