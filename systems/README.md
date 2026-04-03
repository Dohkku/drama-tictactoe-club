# Arquitectura de Sistemas

El juego está dividido en 6 sistemas independientes. Cada uno tiene su propia carpeta, su sandbox de test, y una responsabilidad clara. Se pueden desarrollar y probar por separado.

```
systems/
├── dev_menu.tscn               ← Menú para lanzar cada sistema
├── board_logic/                ← Sistema 1: Lógica pura
│   └── test_scene.tscn
├── board_visuals/              ← Sistema 2: Tablero visual
│   └── visual_sandbox.tscn
├── cinematic/                  ← Sistema 3: Personajes y cámara
│   └── cinematic_sandbox.tscn
├── layout/                     ← Sistema 4: Gestión de paneles
│   └── layout_sandbox.tscn
├── scene_runner/               ← Sistema 5: Motor de scripts DSL
│   └── scene_runner_sandbox.tscn
└── match/                      ← Sistema 6: Orquestador de partidas
    └── match_sandbox.tscn
```

## Estado: TODOS MIGRADOS

| # | Sistema | Sandbox | Estado |
|---|---------|---------|--------|
| 1 | Board Logic | test_scene | Completo |
| 2 | Board Visuals | visual_sandbox | Completo |
| 3 | Cinematic | cinematic_sandbox | Completo |
| 4 | Layout | layout_sandbox | Completo |
| 5 | Scene Runner | scene_runner_sandbox | Completo |
| 6 | Match | match_sandbox | Completo |

## Principios

- **Sin dependencias cruzadas durante testing**: cada sandbox funciona solo.
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
