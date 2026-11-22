# PITCH DECK · CustomVeloz
## Arcade Low-Poly Time-Trial Racer
*Estructura alineada con el framework de Pitch Decks de GLITCH (heyglitch.notion.site)*

---

### SLIDE 1: PORTADA Y HOOK (Título y Logline)

* **Título del Juego**: `CustomVeloz`
* **Subtítulo**: `Arcade Time-Trial Racer`
* **Logline (Gancho en una frase)**:  
  > *"Un arcade racer retrofuturista donde cada milisegundo cuenta: domina el derrape dinámico, encadena turbos con estelas de luz estilo Burnout y bate tus propios récords en un cañón de neón procedural."*
* **Género**: Carreras Arcade / Time Attack / Retro Low-Poly
* **Plataformas**: PC (Windows) y Web (itch.io / HTML5)
* **Motor**: Godot Engine 4 (GL Compatibility / Jolt Physics)
* **Público Objetivo**: Fans de *Burnout*, *Trackmania*, *Horizon Chase Turbo* y speedrunners casuales.

---

### SLIDE 2: EL PROBLEMA Y LA OPORTUNIDAD (The Market Need)

* **El Problema**:
  - Los juegos de carreras modernos tienden hacia simuladores complejos, controles pesados, largos tiempos de carga y barreras mecánicas elevadas.
  - El jugador casual y amante del arcade busca la gratificación instantánea: acelerar, derrapar sin frustración y sentir la velocidad pura.
* **Nuestra Oportunidad**:
  - Rescatar la fórmula dorada de la era arcade de los 2000s (*Burnout 3: Takedown*, *Ridge Racer*) fusionada con la adicción competitiva de *Trackmania* y una estética synthwave moderna.
  - Experiencia inmediata jugable en cualquier navegador web en menos de 5 segundos, con 60 FPS estables y cero fricción.

---

### SLIDE 3: BUCLE CENTRAL DE JUEGO (Core Gameplay Loop)

```
        [Grilla de Largada & Semáforo Secuencial]
                          │
                          ▼
            [Conducción a Fondo en Curvas]
      (Trazado Catmull-Rom con Peraltes y Desniveles)
                          │
          ┌───────────────┴───────────────┐
          ▼                               ▼
 [Derrape Asistido]              [Riesgo vs Recompensa]
 (Boost de giro en curvas        (Esferas de Alerón +15 km/h,
   cerradas con [ESPACIO])        Turbos Dorados y Conos Obstáculo)
          │                               │
          └───────────────┬───────────────┘
                          ▼
      [Sistema de Deltas de Checkpoint en Vivo]
         (Comparación inmediata contra tu PB:
             Verde = Récord | Rojo = Desfase)
                          │
                          ▼
     [Meta: Guardado Persistente & Reintento Instantáneo]
         (Bate tu mejor tiempo o presiona [R] para reiniciar)
```

---

### SLIDE 4: PILARES Y MECÁNICAS DIFERENCIADORAS (Unique Selling Points)

1. **Turbo Sensorial "Burnout-Style"**:
   - Salto instantáneo de 90 a 120 km/h al presionar `Shift`.
   - Fuerte respuesta sensorial: apertura dinámica de campo visual (**FOV Warp 75° → 88°**), microvibración de cámara, partículas de escape de combustión y **estelas de luz neón continuas** (`ImmediateMesh`) proyectadas desde los faros traseros.
2. **Modo Time Trial con Deltas Competitivos**:
   - Competencia sana contra el propio fantasma del jugador en lugar de IAs predecibles o tramposas.
   - Feedback instantáneo por checkpoint: deltas formateados en centésimas de segundo (`-0.34s` en verde esmeralda / `+0.42s` en rojo vibrante).
   - Persistencia completa en disco (`user://records.cfg`).
3. **Físicas Dinámicas de Chasis & Derrape**:
   - Inclinación de suspensión realista en tiempo real: balanceo lateral (*Roll*) en curvas centrífugas y cabeceo (*Pitch*) en aceleraciones y frenadas.
   - Multiplicador de agilidad de giro (`1.35x`) durante el derrape que elimina el subviraje y premia la destreza del piloto.

---

### SLIDE 5: DIRECCIÓN DE ARTE Y AUDIO (Aesthetic & Vibe)

* **Paleta de Color Crepuscular Arcade**:
  - Cielo gradiente azul noche a fucsia cálido (`#0a0818` a `#d6457a`).
  - Asfalto oscuro de alta legibilidad (`#263238`) flanqueado por bordillos de neón cian radiante (`#00E5FF`).
  - Cañón montañoso de bajo poligonaje con niebla suave y pilares de soporte geométricos que enmarcan la pista sin tapar el trazado.
* **Audio Procedural Reactivo**:
  - Motor de audio sintético sintetizado en tiempo real (`audio_carro.gd`) cuyas revoluciones y pitch se adaptan fluidamente a la aceleración, velocidad y estado del turbo.
  - Efectos de sonido punchy para semáforo de salida, recolección de esferas y choques.

---

### SLIDE 6: COMPARABLES DE MERCADO (Market Comps)

| Título Comparable | Fortalezas que Tomamos | Nuestra Diferenciación |
| :--- | :--- | :--- |
| **Trackmania** | Precisión de Time Attack, reintento inmediato con [R], deltas por sector. | Estética retro synthwave, mejoras físicas en pista y turbo coleccionable. |
| **Burnout 3: Takedown** | Sensación de velocidad extrema, turbo explosivo con estelas de luz y cámara warp. | Formato ágil de bajo poligonaje ejecutable directamente en el navegador. |
| **Horizon Chase Turbo** | Paleta arcade vibrante y curvas suaves retro. | Físicas de chasis dinámicas (roll/pitch) y derrape libre sin raíles fijos. |

---

### SLIDE 7: ARQUITECTURA TÉCNICA Y RENDIMIENTO (Tech Stack)

* **Motor**: Godot Engine 4.2+ en modo **GL Compatibility (OpenGL 3.3 / WebGL 2)**.
* **Optimizaciones Clave**:
  - Generación procedimental de geometría de pista y orografía mediante mallas `ArrayMesh` optimizadas en una sola pasada.
  - Estelas luminosas mediante `ImmediateMesh` con coordenadas globales desenrolladas en tiempo real.
  - Partículas ligeras `CPUParticles3D` asegurando total compatibilidad sin caídas de framerate en navegadores.
  - Físicas con pegado al suelo dinámico (`floor_snap_length = 3.0m` + cálculo analítico de pendientes) para evitar que el carro flote en saltos o cambios de rasante.
* **Métricas**:
  - Tamaño total del paquete exportado: **< 35 MB**.
  - Tasa de cuadros: **60+ FPS** estables incluso en gráficas integradas básicas (Intel Iris / AMD Vega) y Web.

---

### SLIDE 8: ROADMAP DE PRODUCCIÓN (Hitos de Desarrollo)

```
[FASE 1: FUNDAMENTOS] ✅ COMPLETADO
├── Trazado cerrado Catmull-Rom paramétrico
├── Físicas de suspensión e interpolación de llantas
└── Sistema de alerones coleccionables (+15 km/h)

[FASE 2: JUGABILIDAD ARCADE & JUICE] ✅ COMPLETADO
├── Partículas de turbo estilo Burnout & Estelas de faros
├── Cámara dinámica con FOV Warp y sacudida
└── Escenario montañoso crepuscular con glow arcade

[FASE 3: TIME TRIAL & PULIDO] ✅ COMPLETADO
├── Sistema de Récords Personales (PB) en user://records.cfg
├── Deltas en tiempo real por checkpoint (-verde / +rojo)
└── Potenciador de giro al derrapar con barra espaciadora

[FASE 4: LANZAMIENTO & COMUNIDAD] 🚀 SIGUIENTE PASO
├── Publicación Web en itch.io (HTML5)
├── Integración de Tabla de Líderes Global (Leaderboards online)
└── Soporte multijugador local en pantalla dividida (2P)
```

---

### SLIDE 9: EQUIPO Y CONCLUSIÓN (The Ask & Vision)

* **Desarrollador**: Estudiante de Ingeniería de Software / Creador Indie en solitario.
* **Propósito**: Demostrar cómo una arquitectura limpia en Godot 4 puede entregar una experiencia de carreras arcade pulida, adictiva y visualmente impactante, cumpliendo con los estándares de diseño y presentación de la industria indie actual.
* **Estado Actual**: Build final lista para jugar y defender ante jurado académico y comunidad de jugadores.
