# AVF Framework MP — Migration Notes

Migración del mod **Armed Vehicles Framework (AVF)** a la API oficial de
Multiplayer de Teardown (parche del 12 de marzo de 2026).

Estado: **Fases 0–2 implementadas (mecánica + bootstrap).** Fase 3 (estado
replicado vía `shared`) documentada pero NO implementada — requiere datos de
test in-game.

---

## Resumen de cambios aplicados

### Fase 0 — Bootstrap mínimo

* `info.txt`: añadida línea `version = 2` al principio, quitado `[noupload]`,
  renombrado a `Armed Vehicles Framework (AVF) MP`.
* `#version 2` añadido como primera línea de los `.lua` que son entry-points
  (cargados directamente como `<script>` o por convención).
* `#version 2` deliberadamente **NO** añadido a archivos que solo son
  pulled in por `#include`, para evitar directivas duplicadas en el texto
  preprocesado final.

### Fase 1 — Wrapping de callbacks SP → `client.*`

En MP v2, el motor solo invoca callbacks bajo las tablas `server.*` y
`client.*`. Las funciones top-level `init()`, `tick(dt)`, `update(dt)` y
`draw()` que AVF define a nivel de archivo **no son llamadas automáticamente**.

Al final de cada entry-point con callbacks top-level se ha añadido:

```lua
if client then
    if init   then function client.init()     init()     end end
    if tick   then function client.tick(dt)   tick(dt)   end end
    if update then function client.update(dt) update(dt) end end
    if draw   then function client.draw()     draw()     end end
end
```

Esto enruta los callbacks legacy al contexto cliente. UMF (`umf/core/detouring.lua`)
sigue funcionando porque `_G.init`/`_G.tick`/etc. son metafunciones (DETOURed)
y la wrapper las lee dinámicamente en tiempo de llamada.

### Fase 2 — Wrapping paralelo a `server.*`

Bloque adicional al final de cada entry-point:

```lua
if server then
    if init   then function server.init()     init()     end end
    if tick   then function server.tick(dt)   tick(dt)   end end
    if update then function server.update(dt) update(dt) end end
end
```

Esto permite que el contexto servidor del host ejecute las llamadas
server-only (`Shoot`, `MakeHole`, `Explosion`, `SetProperty`,
`SetBodyTransform`, `Spawn`, `Delete`, `Paint`).

**Limitaciones conscientes:**

* Recursos cargados en `init()` (`LoadSound`, `LoadSprite`) corren en
  AMBOS contextos. El servidor no tiene renderer; los handles que devuelve
  en server-side son inválidos. Audio y visuales solo funcionarán en la
  copia client-side.
* `tick`/`update` se ejecutan dos veces en el host. Esto es desperdicio de
  CPU y puede causar divergencia de estado en sesiones largas (dos copias
  de `vehicles[]`, `weapons[]`, etc. en estados ligeramente distintos).
* `draw` NO se enruta a `server.*` porque el motor no expone `server.draw`.
* Las llamadas server-only desde contexto cliente (`DrawSprite` en
  `tick()` mezclado con `Shoot()`) seguirán fallando o siendo no-op
  cuando el contexto client intente ejecutarlas. Lo aceptamos para esta
  iteración.

### Fase 3 — Estado replicado (NO implementado)

Lo que falta para verdadero MP:

1. **Definir `shared.avf` en `server.init`** del Framework con la
   estructura mínima:
   ```lua
   function server.init()
       shared.avf = {
           vehicles = {},   -- [vehicleId] = { turret_yaw, gun_pitch, ammo, hp, ... }
           players  = {},   -- [playerId]  = { vehicleId, weaponGroup, sniperMode, ... }
       }
       init()
   end
   ```
2. **Poblar `shared.avf` desde `server.update`** copiando los campos
   relevantes del estado interno de AVF (objeto `vehicle`, `weapons`,
   `playerState`).
3. **Refactorizar reads en client.\***: cambiar
   `vehicle.turret.angle` → `shared.avf.vehicles[id].turret_yaw` en cada
   sitio de dibujo/UI/audio.
4. **Eliminar el `server.*` wrapper actual** una vez todo el estado fluya
   por `shared` — la lógica completa debe vivir en server, el cliente
   solo debe leer/renderizar.

Esto es un refactor invasivo (cientos de sitios) y no se debe hacer
"en seco". Iterar con feedback de testing.

---

## Cómo probarlo

### Instalación local (Windows)

Copiar o symlinkar ambas carpetas a:

```
%LOCALAPPDATA%\Teardown\mods\
```

Steam reconocerá los mods locales sin necesidad de subir al Workshop.

### Activación

1. Lanzar Teardown.
2. Mod Manager → activar **Armed Vehicles Framework (AVF) MP** y
   **AVF Vehicles MP**.
3. Probar en este orden:
   * **SP sandbox** — carga una mapa cualquiera, AVF debería detectar
     un vehículo y mostrar HUD. Validamos que carga sin crashear.
   * **MP solo-host** — crear sesión privada, sin invitar. El host corre
     `server.*` Y `client.*`, simulando el escenario completo.
   * **MP con segundo jugador** — solo cuando los pasos anteriores
     funcionen. Aquí pillaremos los bugs de sincronización.

### Qué esperar

| Funcionalidad         | SP                | MP host solo      | MP cliente (2º jugador) |
|-----------------------|-------------------|-------------------|-------------------------|
| Mod carga             | ✅                | ✅                | ✅                      |
| HUD / retículas       | ✅                | ✅                | ⚠️  posible             |
| Sonido de motor       | ✅                | ✅                | ⚠️  posible             |
| Disparar              | ✅                | ✅ (server.tick)  | ❌                      |
| Daño al terreno       | ✅                | ✅ (server.tick)  | ❌                      |
| Explosiones           | ✅                | ✅                | ❌                      |
| IA enemiga            | ✅                | ✅                | ⚠️                      |
| Torreta apuntando     | ✅                | ✅                | ❌ (no sincronizado)    |
| Munición HUD          | ✅                | ✅                | ❌ (estado local)       |
| Vehículo conducible   | ✅                | ✅                | ✅ (Teardown lo hace)   |

Es esperado y normal que el cliente joiner NO vea torreta sincronizada o
HUD de munición funcional — eso lo arregla Fase 3.

### Errores conocidos a vigilar en `%LOCALAPPDATA%\Teardown\teardown.log`

* `"function X is SERVER ONLY"` — confirma que la llamada se hizo desde
  client. Esperado si el host está corriendo client.tick y choca contra
  `SetProperty`/`MakeHole`/etc. NO es bloqueante: server.tick ejecutará
  la misma llamada con éxito.
* `"attempt to index nil"` sobre `LoadSound`/`LoadSprite` desde server
  context — esperado, ignorable, el cliente carga los recursos OK.
* Cualquier error con stack que apunte a `umf/` — UMF puede tener
  incompatibilidades con v2 que no detectamos sin testear.
* Errores con `quickSetupXMLTags` o XML parsing — Fase 0 no toca XML,
  cualquier error aquí es del mod original.

### Si Teardown rechaza el mod silenciosamente

Síntoma: el mod aparece en la lista pero al activarlo no pasa nada y
no hay error visible.

Posibles causas y diagnóstico:

1. `version = 2` mal escrito en `info.txt`. Verificar que es la primera
   línea (después del UTF-8 BOM si lo hay).
2. Algún `.lua` entry-point sin `#version 2`. El motor desactiva
   silenciosamente esos scripts. Buscar:
   ```bash
   for f in $(find AVF-Framework-MP -name "*.lua"); do
       head -1 "$f" | grep -q "^#version 2" || echo "MISSING: $f"
   done
   ```
   y compararlo contra la lista de entry-points definida abajo.
3. `#version 2` duplicado en el texto preprocesado (porque algún archivo
   `#include`d todavía lo tiene). En Fase 0 se quitó de los archivos
   solo-incluidos, pero podría quedar alguno. Si el log lo menciona,
   re-correr `fix_version_headers.py`.

### Reglas de oro al iterar

* **Cambiar UNA cosa por vez** y volver a probar. Si has cambiado N
  archivos y algo falla, te toca bisección.
* **No tocar `umf/`**. Es código de terceros, lo tratamos como caja
  negra. Si UMF falla en v2, la solución es desactivar UMF (parchear
  `main.lua` para no incluirlo), no arreglar UMF.
* **Guardar el `teardown.log` después de cada test**. Es la única
  fuente fiable de diagnóstico.

---

## Lista de entry-points (con `#version 2` aplicado)

### AVF-Framework-MP

* `main.lua` (entry-point por convención)
* `scripts/shell_casing_lifespan.lua` (loaded dinámicamente desde main.lua:2572)
* `avf/scripts/Immersive_Tank.lua`, `simple_avf_tank.lua`
* `avf/prefabs/*/Tiger131.lua`, `cromwell_V.lua`, `t90.lua`, etc.
* `avf/conquest/scripts/AVF_conquest_manager.lua`, `capture_area*.lua`
* `options.lua`, `pathfinding.lua`, `pathfinding/*` (huérfanos —
  conservan `#version 2` por precaución)

### AVF-Vehicles-MP

* Todos los scripts en `avf/prefabs/*/*.lua`
* Todos los scripts en `avf/scripts/*.lua`
* `avf/conquest/scripts/*.lua`
* `target_tracks/moving_range_target.lua`
* `voxscript/ground.lua`

---

## Plan de Fase 3 (para post-test)

Cuando Fases 0–2 estén verificadas y queramos sincronización real:

1. **Decidir el shape de `shared.avf`** — qué campos por vehículo, qué
   campos por jugador, frecuencia de actualización (cada `update`
   probablemente).
2. **Inventariar mutadores de estado**: buscar en main.lua todos los
   sitios donde `vehicle.turret.angle`, `vehicle.weapons.equippedGroup`,
   `weapon.currentAmmo`, etc. se asignan. Esos sitios pasan a escribir
   en `shared.avf`.
3. **Inventariar lectores**: dónde se leen esos campos para dibujar HUD,
   apuntar reticles, mostrar munición. Esos pasan a leer de `shared.avf`.
4. **Mover gameplay logic 100% a `server.*`**. Quitar `client.tick = tick`,
   dejar solo `client.draw` (y `client.tick` para audio si fuera necesario).
5. **Input multi-jugador**: cambiar `InputDown("usetool")` →
   `InputDown("usetool", playerId)` en server-side. Iterar
   `GetAllPlayers()` en server.update.
6. **Asignación de torretas**: cuando dos jugadores quieren controlar la
   misma torreta, decidir política (primero llega gana / rotación / etc).
   Guardar en `shared.avf.vehicles[vid].controllers[seatId] = playerId`.

Estimación honesta: 3–10 días de trabajo concentrado con testing en cada
paso. Empezar por un solo vehículo (p.ej. el Tiger 131) hasta que
funcione, después generalizar.

---

## Reverting (si todo se rompe)

Las modificaciones son aditivas: bloques al final de archivos +
`#version 2` al principio + 4 líneas en `info.txt`. No se ha tocado lógica
de AVF. Para deshacer manualmente:

```bash
# Quitar #version 2 de todos los .lua (revert Fase 0)
find . -name "*.lua" -exec sed -i '' '/^#version 2$/d' {} +

# Quitar bloques wrapper (revert Fases 1+2)
# Buscar por sentinela: "MP callback wrappers (added for Teardown v2 multiplayer)"
# y "Phase 2: server.* wrappers" — eliminar a partir de esas líneas.
```

O simplemente borrar las carpetas `-MP` y clonar de nuevo los originales.
