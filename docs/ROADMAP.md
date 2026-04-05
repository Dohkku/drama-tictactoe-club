# Editor 2.0 — Roadmap

## Vision
Un editor visual donde un artista pueda construir una historia interactiva completa
sin tocar codigo. Cada nodo es una herramienta creativa. El canvas ES el juego.

---

## Fase A: Core UX [EN PROGRESO]

### A1. Undo/Redo
- [ ] Sistema UndoRedo de Godot integrado en GraphEdit
- [ ] Ctrl+Z deshacer, Ctrl+Shift+Z rehacer
- [ ] Acciones tracked: crear nodo, borrar nodo, mover nodo, conectar, desconectar
- [ ] Cambios en detail panel tambien deshacibles

### A2. Gestion de conexiones
- [ ] Click en linea de conexion para seleccionarla
- [ ] Delete/Supr borra conexion seleccionada
- [ ] Visual: conexion seleccionada se resalta

### A3. Navegacion refinada
- [x] Scroll = pan, Ctrl+Scroll = zoom
- [x] Minimap funcional
- [x] Panel de ayuda con controles
- [ ] Zoom to fit (ver todo el grafo de golpe)
- [ ] Centrar en nodo seleccionado

---

## Fase B: Profundidad de Nodos [PENDIENTE]

### B1. Nodo PERSONAJE — Editor completo
- [ ] **Retrato**: Browse de imagen, preview con crop (zoom, offset X/Y, reset)
- [ ] **Expresiones**: Lista dinamica — nombre + color + imagen por expresion
- [ ] **Poses**: Lista dinamica — nombre + descripcion + energy + openness
- [ ] **Voz**: Pitch (50-500Hz), variacion, waveform (sine/square/triangle), preview audio
- [ ] **Estilo dialogo**: Color fondo, color borde, preview inline
- [ ] **Pieza default**: Tipo (X/O), estilo (gentle/slam/spinning/dramatic/nervous)
- [ ] **Direccion default**: left/center/right/away
- [ ] Todos los campos de CharacterData editables desde el panel

### B2. Nodo PARTIDA — Config completa
- [x] Dificultad IA (slider 0-100%)
- [x] Estilos jugador/oponente
- [x] Efectos visuales (none/fire/sparkle/smoke/shockwave)
- [x] Diseno de pieza (x/o/triangle/square/star/diamond)
- [x] Offset de colocacion
- [x] Turnos por visita
- [x] Scripts intro/reacciones (file browser)
- [ ] Preview inline del oponente (thumbnail)
- [ ] Indicador visual de scripts asignados en el nodo
- [ ] Quick-create script desde el nodo

### B3. Nodo CINEMATICA — Editor de scripts
- [x] Referencia a .dscn con filename
- [ ] **Editor inline**: CodeEdit con syntax highlighting en detail panel
- [ ] **Command palette**: Botones rapidos para insertar comandos DSL
- [ ] **Preview**: SubViewport con CinematicStage para preview en vivo
- [ ] **Crear nuevo script**: Boton que crea .dscn vacio y lo asigna
- [ ] **Autocompletado**: Nombres de personajes registrados en el proyecto

### B4. Nodo TABLERO — Config visual completa
- [x] Reglas: tamano, win length, max pieces, overflow, draw
- [ ] **Visual completa**: Colores de celda, hover, lineas, checkerboard
- [ ] **Borde**: Enabled/color/width
- [ ] **Sizing**: Max size, margins, hand area, piece ratio
- [ ] **Colores player/opponent**
- [ ] **Test board**: Tablero jugable en el detail panel
- [ ] **Presets**: Boton para cargar standard/rotating/big/custom

### B5. Nodo SIMULTANEA — Config por oponente
- [ ] Lista visual de oponentes conectados
- [ ] Config individual: IA, estilos, efectos por oponente
- [ ] Scripts de reacciones por oponente

---

## Fase C: Historia Demo [EN PROGRESO]

### C1. Narrativa
- [ ] Historia original con 5 personajes, arco narrativo completo
- [ ] 5 capitulos con tension creciente
- [ ] Sistema de flags para decisiones del jugador
- [ ] Dialogos con personalidad unica por personaje
- [ ] Uso de TODAS las funcionalidades cinematicas

### C2. Variedad de partidas
- [ ] Match 1: Tutorial facil (3x3, gentle)
- [ ] Match 2: Desafio medio (3x3, efectos fire)
- [ ] Match 3: Tablero grande (5x5, 4 en raya)
- [ ] Match 4: Rotacion (3 piezas, sin empate)
- [ ] Match 5: Boss final (dificultad maxima, shockwave)

### C3. Personajes con profundidad
- [ ] Sora: 6+ expresiones, 8+ poses, voz aguda sine
- [ ] Ryu: 5+ expresiones, 5+ poses, voz grave triangle
- [ ] Akira: 4+ expresiones, agresiva, voz media square
- [ ] Mei: 4+ expresiones, analitica, voz suave sine
- [ ] Player: Presencia silenciosa con 2 expresiones

---

## Fase D: Polish [FUTURO]

### D1. Experiencia de edicion
- [ ] Drag desde puerto a espacio vacio → auto-crear nodo compatible
- [ ] Doble-click en canvas → crear nodo
- [ ] Copiar/pegar nodos (Ctrl+C/V)
- [ ] Duplicar nodo (Ctrl+D)
- [ ] Alinear nodos (snap to grid mejorado)
- [ ] Auto-layout (organizar grafo automaticamente)

### D2. Canvas como objeto
- [ ] Guardar canvas como .canvas.tres
- [ ] Instanciar canvas dentro de otro
- [ ] Puertos expuestos para sub-grafos
- [ ] Nodo CanvasInstance funcional

### D3. Feedback visual
- [ ] Nodos incompletos resaltados en rojo
- [ ] Indicador de flujo (animacion de particulas en conexiones)
- [ ] Preview de personaje en el nodo al hover
- [ ] Tooltip con resumen al hover sobre nodos

### D4. Integracion runtime
- [ ] Boton "Play from here" en cada nodo
- [ ] Debug overlay: ver que nodo se esta ejecutando
- [ ] Hot reload: cambios en editor se reflejan sin reiniciar

---

## Registro de Progreso

### 2026-04-03
- [x] Editor 2.0 creado con GraphEdit
- [x] 8 tipos de nodo implementados
- [x] Validacion de conexiones 1:1
- [x] Serializacion Graph → ProjectData
- [x] Import legacy funcional
- [x] Nodos compactos
- [x] Panel de ayuda con controles
- [x] Navegacion scroll/zoom
- [x] Tech Demo 2.0 con 9 eventos
- [x] Dev menu con Editor 2.0 prominente
