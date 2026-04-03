# HOWTO - Drama Tic Tac Toe Club

## Ejecutar el juego

```bash
bash godot.sh
```

## Dev Menu (testear sistemas por separado)

```bash
bash godot.sh --scene res://systems/dev_menu.tscn
```

## Escenas específicas

```bash
# Editor de proyecto
bash godot.sh --scene res://editor/editor_main.tscn

# Juego completo (carga la historia)
bash godot.sh --scene res://main.tscn

# Test de un sistema concreto
bash godot.sh --scene res://systems/board_logic/test_scene.tscn
```

## Tests automatizados

```bash
# Tests de lógica del tablero
bash godot.sh --script board/test_board_logic.gd

# Tests de integración (flujo completo, IA, parser, etc.)
bash godot.sh --script board/test_game_flow.gd
```

## Verificar que no hay errores de parseo

```bash
bash godot.sh --headless --quit-after 3
```

## Verificar una escena sin ventana

```bash
bash godot.sh --headless --scene res://systems/dev_menu.tscn --quit-after 3
```
