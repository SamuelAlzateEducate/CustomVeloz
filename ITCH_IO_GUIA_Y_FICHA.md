# Guía Completa de Publicación y Ficha para itch.io
## Proyecto: CustomVeloz · Arcade Time-Trial

Esta guía contiene la **ficha de texto lista para copiar y pegar** en itch.io, los parámetros recomendados para la página y el paso a paso para compilar la versión Web (HTML5) en Godot 4.

---

## 1. Ficha Técnica de la Página (Metadatos de itch.io)

| Campo en itch.io | Valor Recomendado |
| :--- | :--- |
| **Title** | `CustomVeloz: Arcade Time-Trial` |
| **Short description or tagline** | `Adrenalina pura, derrapes a fondo y turbo con estelas neón estilo Burnout en un cañón retro-futurista.` |
| **Classification** | `Games` |
| **Kind of project** | `HTML (You have a ZIP or HTML file that will be played in the browser)` |
| **Release status** | `Released` o `In development` |
| **Pricing** | `$0 or donate` |
| **Suggested donation** | `$2.00` |
| **Community** | `Comments` |
| **Tags** | `Racing`, `3D`, `Arcade`, `Low-poly`, `Retro`, `Time Attack`, `Godot`, `Fast-Paced`, `Drifting`, `Synthwave`, `Cyberpunk`, `WebGL` |

---

## 2. Texto de la Descripción (Copiar y pegar en itch.io)

```markdown
# ⚡ CustomVeloz: Arcade Time-Trial

**CustomVeloz** es un juego de carreras arcade frenético en 3D Low-Poly inspirado en la velocidad implacable de *Burnout*, la precisión milimétrica de *Trackmania* y la atmósfera visual de los clásicos synthwave retrofuturistas.

Conduce al límite, domina el derrape en curvas cerradas, encadena turbos con estelas de luz neón y bate tus propios récords en cada vuelta con nuestro sistema de **splits y deltas en tiempo real**.

---

### 🏁 Características Principales

* ⏱️ **Modo Time Trial Competitivo**: Sistema de cronometraje progresivo con precisión de centésimas. Guarda automáticamente tu **Récord Personal (PB)** y registra deltas intermedios en cada checkpoint (**verde si vas mejorando, rojo si te quedas atrás**).
* 🔥 **Turbo Nitro & Estelas Burnout**: Desata el turbo para alcanzar los 120 km/h con deformación dinámica de cámara (FOV Warp), chispas de escape de alta energía y estelas luminosas continuas en los faros traseros.
* ⚡ **Mejoras Físicas en Pista**: Recoge las esferas esmeralda para ganar alerones aerodinámicos temporales (+15 km/h extra de velocidad máxima) y esferas doradas para recargar tu barra de nitro al instante.
* 🏎️ **Físicas Arcade & Derrape Ágil**: Inclinación reactiva de chasis (Roll en curvas centrífugas y Pitch al acelerar/frenar), agarre dinámico y giro potenciado al derrapar con la barra espaciadora.
* 🌌 **Atmósfera Crepuscular Procedural**: Pista cerrada modelada con curvas suaves Catmull-Rom, vallas de neón cian, cañón montañoso facetado y postes luminosos reactivos.
* 🔄 **Reinicio Ultrarrápido**: Presiona **[R]** en cualquier momento para reiniciar tu intento al instante sin tiempos de carga molestos.

---

### 🎮 Controles

| Acción | Teclado | Gamepad / Control |
| :--- | :--- | :--- |
| **Acelerar** | `W` o `Flecha Arriba` | `Gatillo Derecho (R2 / RT)` / `Botón A` |
| **Frenar / Reversa** | `S` o `Flecha Abajo` | `Gatillo Izquierdo (L2 / LT)` / `Botón B` |
| **Girar Izquierda / Derecha** | `A` / `D` o `Flechas` | `Stick Izquierdo` / `D-Pad` |
| **Derrapar (Drift)** | `Barra Espaciadora` | `Botón X / Cuadrado` o `L1` |
| **Turbo Nitro** | `Shift Izquierdo` | `R1 / RB` |
| **Reiniciar Carrera** | `R` | `Select / Back` |

---

### 💡 Consejos de Conducción ("Pro Tips")

1. **Entra derrapando a las curvas**: Mantén presionada la **Barra Espaciadora** justo antes de doblar; tu carro rotará más rápido sin perder inercia y evitará que choques contra el muro exterior.
2. **Encadena el Turbo en rectas**: Usa el nitro al salir de la horquilla este para aprovechar la máxima aceleración y batir tu split intermedio.
3. **Cuidado con los conos naranjas**: Golpear un cono frenará tu bólido de golpe y arruinará tu récord de vuelta.
4. **Fíjate en el Delta**: Si el cartel central parpadea en **verde**, mantén la trazada limpia hasta la meta para coronar un **¡NUEVO RÉCORD!**

---

### 🛠️ Ficha Técnica de Desarrollo

* **Motor**: Godot Engine 4 (Compatibilidad WebGL 2 / OpenGL 3.3).
* **Físicas**: Jolt Physics 3D con integración matemática personalizada.
* **Audio**: Síntesis procedural de revoluciones del motor reactiva a la velocidad.
* **Desarrollo**: Proyecto de Ingeniería de Software y Videojuegos.
```

---

## 3. Configuración del Reproductor Web en itch.io

Al editar el juego en itch.io, baja hasta la sección **Embed options**:

1. **Frame dimensions**:
   - Width: `1280` px
   - Height: `720` px
2. **Orientation**: `Landscape`
3. **Automatically start on page load**: Activado (o desactivado si prefieres que el usuario haga clic en "Run Game").
4. **Fullscreen button**: `Enable fullscreen button` (Marcado con check ✅).
5. **SharedArrayBuffer support (experimental)**:
   - *Nota importante*: En Godot 4 Web export, si exportas en modo single-threaded no es obligatorio, pero si usas threads en WebGL marca esta casilla para máxima compatibilidad con el navegador.

---

## 4. Paso a Paso para Exportar y Subir a itch.io

1. **Abrir el Proyecto en Godot 4**:
   - Ve a `Proyecto > Exportar...` (Project > Export).
2. **Seleccionar el Preset "Web"**:
   - Ya dejamos preconfigurado el archivo `export_presets.cfg` con el preset **Web**.
   - Si Godot te pide descargar las plantillas de exportación, haz clic en *Descargar e Instalar* (Download & Install templates).
3. **Exportar el Proyecto**:
   - Haz clic en **Exportar Proyecto** (Export Project).
   - Crea una carpeta llamada `builds/web` dentro del proyecto.
   - Guarda el archivo con el nombre exacto: `index.html`.
4. **Crear el Archivo ZIP**:
   - Ve a la carpeta `builds/web/` donde Godot generó los archivos (`index.html`, `index.js`, `index.wasm`, `index.pck`, etc.).
   - Selecciona **todos los archivos** dentro de esa carpeta.
   - Haz clic derecho > *Comprimir en archivo ZIP* (o usa 7-Zip / WinRAR) y nómbralo `customveloz_web.zip`.
   - *Regla de oro de itch.io*: El archivo `index.html` debe estar en la raíz del ZIP, no dentro de una subcarpeta.
5. **Subir a itch.io**:
   - En tu panel de juego de itch.io, sube `customveloz_web.zip`.
   - Marca la casilla: **"This file will be played in the browser"**.
   - Haz clic en **Save & View Page** y ¡a jugar!
