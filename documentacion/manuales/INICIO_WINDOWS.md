# AR Sandbox: inicio y preparación para presentación en Windows

Esta guía usa el entorno virtual existente en `backend/venv` y las dependencias instaladas en `visualizacion_3d/node_modules`. Los scripts no instalan paquetes. El acceso directo de inicio levanta FastAPI y Vite, y abre la interfaz de controles en el navegador predeterminado.

## Preparar una vez

1. Confirma que existen `backend/venv/Scripts/python.exe` y `visualizacion_3d/node_modules`.
2. Crea un acceso directo de escritorio para `scripts/start_ar_sandbox.ps1`. En **Destino** usa:

   ```text
   powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\dev\proyectos_flutter\ar_sandbox\scripts\start_ar_sandbox.ps1"
   ```

   Sustituye la ruta si el proyecto está en otra carpeta. En **Iniciar en**, puedes indicar la carpeta raíz del proyecto.
3. Crea otro acceso directo con el mismo procedimiento, pero apuntando a `scripts/stop_ar_sandbox.ps1`.
4. Para asignar el icono incluido: clic derecho en cada acceso directo > **Propiedades > Acceso directo > Cambiar icono...** y selecciona `recursos/ar-sandbox.ico`. Si Windows no lo muestra, escribe la ruta completa, por ejemplo `C:\dev\proyectos_flutter\ar_sandbox\recursos\ar-sandbox.ico`.

## Procedimiento para el día de la exposición

1. Enciende la computadora e inicia sesión en Windows.
2. Conecta el proyector antes de abrir la ventana de proyección.
3. Pulsa **Windows + P** y selecciona **Extender**. En Configuración > Sistema > Pantalla, confirma cuál pantalla es la principal y cuál corresponde al proyector.
4. Haz doble clic en **Iniciar AR Sandbox**. El script comprueba FastAPI en `http://127.0.0.1:8000/health` y Vite en `http://127.0.0.1:5173/`; solo inicia los que no respondan. Espera hasta 30 segundos por cada servicio y abre los controles cuando ambos están disponibles.
5. En controles, pulsa **Abrir ventana de proyección**. La página solicita una ventana emergente desde un clic del usuario, requisito que ayuda a evitar el bloqueo del navegador. Si el navegador la bloquea, permite ventanas emergentes para `localhost` y vuelve a pulsar el botón.
6. Mueve la ventana de proyección al monitor del proyector. Puedes arrastrarla con el mouse o enfocarla y usar **Windows + Shift + Flecha izquierda/derecha** para moverla entre pantallas.
7. En la ventana de proyección, maximízala y pulsa **F11** para pantalla completa. Pulsa F11 otra vez para salir. Si el navegador o su política de pantalla completa lo impide, deja la ventana maximizada.
8. Usa la aplicación Flutter como de costumbre para configurar terreno, color y altura, e iniciar o detener la simulación. La ventana de controles consulta FastAPI; la proyección recibe terreno, calibración y cámara por `BroadcastChannel` y conserva el último estado si pierde contacto.
9. Para terminar, sal de pantalla completa con F11, cierra la ventana de proyección y pulsa **Detener AR Sandbox**. El script detiene los procesos que él mismo inició; no detiene instancias que ya estaban funcionando antes del arranque.

## Qué hace el inicio y qué hace la detención

- FastAPI se ejecuta con `backend/venv/Scripts/python.exe -m uvicorn main:app --host 127.0.0.1 --port 8000`.
- Vite se ejecuta con `npm run dev -- --host 127.0.0.1` desde `visualizacion_3d/`.
- El inicio reutiliza servicios que ya responden y registra los procesos que arranca en `%LOCALAPPDATA%\AR Sandbox\runtime\started-processes.json`.
- Los registros de salida y error están en `%LOCALAPPDATA%\AR Sandbox\runtime\backend.stdout.log`, `backend.stderr.log`, `frontend.stdout.log` y `frontend.stderr.log`.
- La detención valida el PID y su hora de inicio antes de terminar el árbol de procesos. Si Windows no permite detener uno, conserva el registro para volver a intentarlo. Los servicios que ya existían antes se dejan activos.
- Volver a iniciar el backend borra su estado en memoria; después de un reinicio del servidor, vuelve a registrar la configuración desde Flutter.

## Ventanas, proyector y límites del navegador

El navegador no permite abrir de forma fiable una ventana emergente automáticamente al arrancar un proceso externo: normalmente exige un gesto del usuario. Por eso el flujo conserva el botón **Abrir ventana de proyección** en controles en vez de intentar forzar la apertura. La ventana usa `?modo=proyector`, no muestra los paneles y recibe los cambios mediante el canal existente.

El navegador tampoco ofrece una forma universal y fiable para que una página coloque su ventana en un monitor concreto. La ubicación se elige arrastrando la ventana o con **Windows + Shift + Flecha**. La pantalla completa también depende de la acción del usuario; F11 es el método compatible con los navegadores de escritorio habituales. Estas limitaciones evitan que el script mueva ventanas a una pantalla desconectada o fuera del área visible.

## Solución de problemas

### La página de controles no abre

- Confirma que responde `http://127.0.0.1:5173/`.
- Revisa `frontend.stderr.log` y `frontend.stdout.log` en `%LOCALAPPDATA%\AR Sandbox\runtime`.
- Comprueba que Node.js/npm está disponible y que existe `visualizacion_3d/node_modules`. El script no ejecuta `npm install`.
- Si el puerto 5173 está ocupado por otro servidor, ciérralo o revisa qué aplicación lo usa y vuelve a iniciar.

### El estado de FastAPI aparece desconectado

- Abre `http://127.0.0.1:8000/health`.
- Revisa los registros `backend.*.log` en la carpeta runtime.
- Confirma que existe `backend/venv/Scripts/python.exe` y que el puerto 8000 no está ocupado por otro programa.

### No se abre la proyección o se queda esperando

- Permite ventanas emergentes para `localhost` y vuelve a pulsar **Abrir ventana de proyección**.
- Mantén abierta la ventana de controles: es la autoridad de cámara y la única que consulta FastAPI.
- Confirma que ambas ventanas pertenecen al mismo origen (por ejemplo, ambas en `http://127.0.0.1:5173`) para que compartan `BroadcastChannel`.
- Si `BroadcastChannel` no está disponible, usa **Modo proyector** en la página de controles, que proyecta en esa misma ventana.

### La proyección aparece en el monitor equivocado o no llena la pantalla

- Usa **Windows + P > Extender** y mueve la ventana con **Windows + Shift + Flecha izquierda/derecha**.
- Maximiza la ventana y pulsa F11. Si F11 está asignada a una tecla multimedia, prueba **Fn + F11**.
- Si el proyector se conectó después de abrir la ventana, muévela otra vez o ciérrala y ábrela desde controles.

### El script de detención informa que no pudo cerrar un proceso

- Vuelve a ejecutar **Detener AR Sandbox**; el registro se conserva cuando una detención falla.
- Si el proceso se inició desde otra cuenta o con privilegios distintos, Windows puede requerir que cierres esa instancia desde la misma cuenta. No finalices procesos ajenos identificados solo por nombre.

## Validación manual antes de presentar

Antes del evento, ensaya el procedimiento completo con el proyector conectado: arranque desde el acceso directo, apertura de la ventana emergente, movimiento a la pantalla extendida, F11, cambios de terreno/color/altura, rotación y zoom sincronizados, inicio y detención desde Flutter, pérdida y recuperación de conexión, cierre de ventanas y parada de servicios. Esta prueba física es necesaria porque el tamaño, resolución, orden de pantallas, escalado de Windows y políticas del navegador dependen del equipo de presentación.
