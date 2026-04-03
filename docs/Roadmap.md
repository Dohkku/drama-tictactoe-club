# Roadmap

## Phase 1: Fundacion (Tablero jugable) ✅

- [x] Configurar `project.godot` (ventana, autoloads)
- [x] `EventBus` con senales base
- [x] `board_logic.gd` (logica pura, testeable headless)
- [x] `board.tscn` + celdas clickeables
- [x] IA base (random + minimax)
- [x] Input tactil (touch + mouse)

**Resultado:** Juego base de 3 en raya funcional.

---

## Phase 2: Escenario Cinematico ✅

- [x] `character_data.gd` + personajes base
- [x] `cinematic_stage` + `character_slot` + `dialogue_box`
- [x] `camera_effects` (shake/flash)
- [x] Piezas fisicas con emociones
- [x] Sistema de efectos de colocacion composables
- [x] `PlacementStyle` por personaje
- [x] Habilidades base (`steal`, `double_play`)
- [x] `GameRules` configurable

**Resultado:** Partida con narrativa y presentacion cinematica.

---

## Phase 3: Sistema de Scripting DSL ✅

- [x] Parser de `.dscn` (`scene_scripts/parser/scene_parser.gd`)
- [x] Runner de comandos (`scene_scripts/scene_runner.gd`)
- [x] Soporte `@scene` y `@reactions`
- [x] Condicionales (`if/else/end_if`) y flags
- [x] Sistema de elecciones (`[choose] ... [end_choose]`)
- [x] Migracion de intro/reacciones a archivos `.dscn`
- [x] Comandos de layout/camara (`fullscreen`, `split`, `board_only`, `close_up`, `pull_back`)
- [x] DSL text tags en dialogo (`{shake}`, `{wave}`, `{trigger:...}`, `{wait:...}`)

**Resultado:** Escenas y reacciones authorables en texto sin tocar `main.gd`.

---

## Phase 4: Sistema de Partidas + Editor ✅ (MVP)

- [x] `match_config.gd` (config por partida)
- [x] `match_manager.gd` (cutscene -> match -> reacciones -> siguiente evento)
- [x] Soporte de eventos de torneo: cutscene, match, simultaneous
- [x] Modo simultanea con rotacion de tableros y estado persistente por oponente
- [x] Editor in-game:
  - [x] Character Editor
  - [x] Tournament Editor
  - [x] Scene Editor con preview/playback
- [x] Persistencia de proyecto en `user://current_project.tres`

**Resultado:** Pipeline completo de autoria -> guardado -> ejecucion en runtime.

---

## Phase 5: Pulido y Contenido 🔜

- [x] Refactor IA para reglas rotativas/overflow (minimax aware de `GameRules`)
- [x] Ejecutar comandos DSL de audio (`music`, `sfx`, `stop_music`) con buses reales
- [x] UI de habilidades en partida (activar `steal` / `double_play`)
- [ ] Mejorar UX del Scene Editor (guardar "nuevo archivo" con nombre)
- [ ] Expandir roster de oponentes y scripts narrativos
- [ ] Integrar arte final
- [ ] QA/estabilidad y testing adicional de flujo completo torneo+editor

**Resultado esperado:** Vertical slice robusto y mas cercano a release interna.
