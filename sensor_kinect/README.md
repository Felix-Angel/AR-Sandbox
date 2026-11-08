# Prueba de profundidad para Kinect Xbox 360

Esta aplicación de escritorio comprueba el Kinect v1 (incluido el modelo 1414), presenta en escala de grises sus fotogramas de profundidad y, si FastAPI está disponible en `127.0.0.1:8000`, envía la matriz de profundidad al backend en tiempo real. Muestra FPS, rango de profundidad, cantidad de píxeles válidos y estado de FastAPI.

## Requisitos

- Windows 10/11 para la prueba prevista en este proyecto.
- Kinect Xbox 360 con su adaptador de corriente y conexión USB para PC.
- Kinect for Windows SDK v1.8 y su controlador instalados.
- Visual Studio con desarrollo de escritorio .NET y el paquete de referencia de .NET Framework 4.8.
- FastAPI iniciado en el mismo equipo en `http://127.0.0.1:8000` para transmitir fotogramas al backend. La vista local funciona aunque FastAPI no esté disponible.

El instalador oficial de Kinect SDK 1.8 enumera Windows 7, 8 y 8.1 en sus requisitos publicados. La ejecución en Windows 10/11 debe comprobarse en el equipo real con este sensor y adaptador antes de depender de ella.

## Compilar y ejecutar

Abre `KinectDepthPreview.csproj` en Visual Studio y ejecútalo. El proyecto busca `Microsoft.Kinect.dll` en:

```text
C:\Program Files\Microsoft SDKs\Kinect\v1.8\Assemblies
```

Si el SDK está instalado en otra carpeta, configura la propiedad MSBuild `KinectSdkDir` con la ruta raíz de Kinect SDK v1.8.

## Comprobar el envío a FastAPI

1. En una terminal, inicia FastAPI:

   ```powershell
   cd D:\ProyectosFlutter\AR-Sandbox\backend
   py -m uvicorn main:app --host 127.0.0.1 --port 8000
   ```

2. Ejecuta `KinectDepthPreview` desde Visual Studio con el Kinect conectado.
3. Confirma que la segunda línea de estado indique que FastAPI está conectado.
4. Abre `http://127.0.0.1:8000/sensor/estado`. Debe responder con `"estado": "capturando"`, resolución y estadísticas del fotograma.
5. Desde Flutter > **Sistema**, usa **Pausar captura** y **Iniciar captura**. El estado debe cambiar y el puente Kinect debe detener/reanudar la transmisión de profundidad.

Si FastAPI no estaba iniciado al abrir la herramienta, esta intenta reconectarse cada tres segundos. La vista local del sensor permanece disponible mientras el backend está apagado.

## Qué valida esta etapa

- El controlador reconoce el sensor como conectado.
- El sensor entrega fotogramas de profundidad.
- La vista cambia al mover un objeto o moldear arena dentro de su campo de visión.
- La tasa de fotogramas y el porcentaje de píxeles válidos sirven para evaluar la estabilidad básica de captura.
- El estado de FastAPI cambia a conectado y el backend recibe fotogramas binarios mientras la vista está activa.

La vista web convierte los fotogramas en una malla 3D y permite ajustar el recorte Kinect. Los valores guardados desde Flutter > **Sistema** se aplican al visor web y a la ventana de proyección.
