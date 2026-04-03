# Sistema 2: Board Visuals

Renderizado, animación y efectos del tablero. No toma decisiones de juego ni gestiona turnos.

**Ubicación canónica**: `systems/board_visuals/`

## Archivos

| Archivo | Descripción |
|---------|-------------|
| `piece.gd` | Pieza: body shape + símbolo, squash/stretch, selección dormida |
| `piece_design.gd` | Resource: diseño visual (forma, body, colores, texto/textura) |
| `placement_style.gd` | Resource: animación de colocación (5 presets + squash/spring) |
| `piece_effect.gd` | Resource: partículas trail/impact, screen flash, propagation |
| `piece_effect_player.gd` | Runtime: CPUParticles2D para trail e impacto |
| `screen_effects.gd` | Efectos pantalla: flash, propagation ring, win line, draw effect |
| `board_audio.gd` | Audio procedural: SFX por fase, BGM, duck/interrupt, temas |
| `cell.gd` | Celda: renderizado, hover, checkerboard |
| `board_pieces.gd` | Gestor de piezas para el facade de producción (board.gd) |

## API Principal

### Piece
```
setup(design, char_id, color)
set_design(design)
play_move_to(target_pos, target_size, style, all_pieces)
set_selectable(val)   # Infraestructura dormida
set_selected(val)     # Infraestructura dormida

signal phase_started(phase_name)   # lift, anticipation, arc, impact, settle
signal phase_completed(phase_name)
signal move_completed()
signal piece_clicked(piece)        # Si selectable=true
```

### PieceDesign
```
design_type: "geometric" | "text" | "texture"
geometric_shape: "x" | "o" | "triangle" | "square" | "star" | "diamond"
text_character: String (Unicode)
body_shape: "circle" | "rounded_square" | "hexagon" | "diamond_body" | "shield"
body_color / symbol_color: Color (transparent = usar piece_color)
fill: bool
line_width_factor: float

Factorías: x_design(), o_design(), triangle_design(), square_design(),
           star_design(), diamond_design(), text_design(char, name)
all_designs() → Array de 10 presets
```

### PlacementStyle
```
lift_height, anticipation_factor, arc_duration, settle_duration
spin_rotations, shake_amount
arc_stretch, impact_squash, spring_bounces

Presets: gentle(), slam(), spinning(), dramatic(), nervous()
```

### PieceEffect
```
trail_enabled/color/amount/lifetime/spread/velocity/scale/gravity
impact_enabled/color/amount/lifetime/spread/velocity/scale/gravity
board_shake_intensity/duration
screen_flash_enabled/color/duration
propagation_enabled/color/duration

Presets: none(), fire(), sparkle(), smoke(), shockwave()
```

### ScreenEffects
```
flash(color, duration)
propagation_ring(origin, color, max_radius, duration)
play_win_line(positions, color, width, duration, glow, pulse, pulse_speed, particles) → Control
play_draw_effect(board_rect, duration)
```

### BoardAudio
```
play_sfx(name)     # lift, whoosh, impact_light, impact_heavy, win, draw
play_bgm(track)    # Procedural o desde res://audio/music/
stop_bgm()
duck_bgm(duration)
interrupt_bgm(sting_name)
set_sfx_volume(linear) / set_bgm_volume(linear)
apply_theme(idx)   # 0=Clásico, 1=Retro, 2=Suave

Override: soltar .ogg/.wav en res://audio/sfx/ o res://audio/music/
```

## Flujo de animación

```
play_move_to():
  LIFT → visual_scale stretch
  ANTICIPATION → wind-up
  trail starts
  ARC → fly + spin + squash in movement direction
  trail stops, impact particles
  IMPACT → screen flash + propagation + squash on landing
  SETTLE → spring bounces (jelly) + shake → visual_scale = 1,1
```

Cada transición emite `phase_started`/`phase_completed` para hooks externos.

## Selección de piezas (dormida)

Infraestructura lista para fichas con habilidades:
1. `piece.set_selectable(true)` en piezas del hand
2. Conectar `piece_clicked` → guardar `selected_piece`
3. En click celda → usar `selected_piece` en vez de secuencial
4. Tras colocar → `selected_piece = null`
