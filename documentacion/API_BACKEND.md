# Contrato JSON del backend de AR Sandbox

## 1. Descripción general

El backend expone una API HTTP para informar si el servicio está disponible, guardar varias simulaciones con nombre, seleccionar una y controlar su estado. También recibe fotogramas de profundidad del Kinect v1 por WebSocket y los reenvía a los visores conectados. La biblioteca se conserva en SQLite; el estado activo y el último fotograma se mantienen en memoria.

La herramienta `sensor_kinect` envía profundidad al backend. Vue recorta el campo del sensor con los ajustes de calibración, genera la malla 3D y presenta el modo de proyección. Flutter consulta el estado del Kinect, controla el envío y la proyección y guarda la calibración.

## 2. Tecnologías

- **Python** como lenguaje del backend.
- **FastAPI** para definir las rutas HTTP y generar la documentación OpenAPI.
- **Pydantic** para validar el cuerpo JSON de configuración y los modelos de respuesta.
- **Uvicorn** como servidor ASGI para ejecutar la aplicación.

## 3. Endpoints disponibles

Los endpoints de negocio implementados en `backend/main.py` son:

| Método | Ruta | Propósito | Códigos de respuesta |
| --- | --- | --- | --- |
| GET | `/` | Información básica del backend y del proyecto. | `200` |
| GET | `/health` | Confirma que el servidor está disponible. | `200` |
| GET | `/sensor/estado` | Consulta conexión, captura, resolución, FPS y estadísticas del último fotograma Kinect. | `200` |
| POST | `/sensor/captura` | Inicia o pausa la captura Kinect con `{"activo": true/false}`. | `200`, `422` |
| GET | `/proyeccion/estado` | Consulta si la proyección está solicitada. | `200` |
| POST | `/proyeccion/control` | Inicia o detiene la proyección con `{"activo": true/false}`. | `200`, `422` |
| GET | `/calibracion` | Recupera los ajustes guardados para la instalación. | `200` |
| PUT | `/calibracion` | Valida y persiste el recorte Kinect y la transformación del proyector. | `200`, `422` |
| POST | `/simulaciones/configuracion` | Valida y guarda la última configuración. | `201`, `422` |
| GET | `/simulaciones/configuracion` | Devuelve la última configuración registrada. | `200`, `404` si todavía no existe |
| POST | `/simulaciones/guardadas` | Guarda una simulación con nombre y la selecciona cuando no hay otra en ejecución. | `201`, `422` |
| GET | `/simulaciones/guardadas` | Lista las simulaciones guardadas de forma persistente. | `200` |
| POST | `/simulaciones/guardadas/{id}/seleccionar` | Carga una simulación guardada para iniciarla o reanudarla. | `200`, `404`, `409` si hay otra en ejecución |
| POST | `/simulaciones/iniciar` | Inicia con la configuración registrada. No acepta cuerpo. | `200`, `400` si falta configuración o ya está en ejecución |
| POST | `/simulaciones/detener` | Detiene una simulación activa. No acepta cuerpo. | `200`, `400` si no hay ejecución activa |
| GET | `/simulaciones/estado` | Consulta el estado y la configuración asociada, si existe. | `200` |

Rutas WebSocket para profundidad:

| Ruta | Dirección | Propósito |
| --- | --- | --- |
| `/ws/sensor/captura` | Puente Kinect → FastAPI | Acepta una conexión de captura y recibe fotogramas binarios ARKD v1. |
| `/ws/sensor/stream` | FastAPI → visor | Envía el último fotograma al conectar y retransmite los siguientes. |

### Estado del sensor

`GET /sensor/estado` devuelve, por ejemplo:

```json
{
  "estado": "capturando",
  "conectado": true,
  "captura_solicitada": true,
  "capturando": true,
  "ancho": 640,
  "alto": 480,
  "fps": 30.0,
  "id_fotograma": 125,
  "ultimo_fotograma": "2026-11-07T12:00:00+00:00",
  "profundidad_minima_mm": 812,
  "profundidad_maxima_mm": 2310,
  "pixeles_validos": 286000,
  "visores_conectados": 1
}
```

`estado` puede ser `desconectado`, `conectado_sin_datos` o `capturando`. La captura se considera activa mientras llega al menos un fotograma cada dos segundos. El estado y el fotograma más reciente se guardan en memoria; se limpian al reiniciar FastAPI.

### Formato del fotograma binario ARKD v1

Cada mensaje binario de `/ws/sensor/captura` y `/ws/sensor/stream` contiene una cabecera little-endian de 30 bytes y una matriz de profundidad sin comprimir:

| Desplazamiento | Tipo | Campo |
| --- | --- | --- |
| 0 | 4 bytes | Firma ASCII `ARKD` |
| 4 | `uint8` | Versión (`1`) |
| 5 | `uint8` | Flags reservados (`0`) |
| 6 | `uint16` | Ancho en píxeles |
| 8 | `uint16` | Alto en píxeles |
| 10 | `uint32` | Número de fotograma |
| 14 | `uint64` | Marca de tiempo UTC Unix en milisegundos |
| 22 | `uint16` | Profundidad válida mínima en milímetros |
| 24 | `uint16` | Profundidad válida máxima en milímetros |
| 26 | `uint32` | Número de píxeles con profundidad válida |
| 30 | `ancho × alto × 2` bytes | Profundidades `uint16` en milímetros, en orden por filas; `0` indica dato inválido |

Se admiten dimensiones de hasta 640 × 480. El backend rechaza paquetes con firma, versión, estadísticas o tamaño incompatibles. Solo se permite un emisor Kinect activo por proceso de FastAPI.

FastAPI también proporciona estas rutas automáticas de documentación:

| Método | Ruta | Propósito | Códigos de respuesta |
| --- | --- | --- | --- |
| GET, HEAD | `/docs` | Interfaz interactiva Swagger UI. | `200` |
| GET, HEAD | `/docs/oauth2-redirect` | Ruta auxiliar que Swagger UI incluye para el flujo OAuth. | `200` |
| GET, HEAD | `/redoc` | Documentación interactiva ReDoc. | `200` |
| GET, HEAD | `/openapi.json` | Esquema OpenAPI generado por FastAPI. | `200` |

Las rutas de interfaz `/docs`, `/docs/oauth2-redirect` y `/redoc` sirven HTML; `/openapi.json` sirve el esquema JSON generado y no tiene un ejemplo reducido aquí porque refleja todas las operaciones y modelos de la API.

Los cuerpos JSON se envían con `Content-Type: application/json`.

## 4. Configuración que envía Flutter

Flutter registra la configuración con `POST /simulaciones/configuracion`. Los tres campos son obligatorios:

```json
{
  "terreno": "montanas",
  "color": "Verde bosque",
  "altura": 75
}
```

### Campos y valores admitidos

| Campo | Tipo JSON | Validación |
| --- | --- | --- |
| `terreno` | string | Debe ser exactamente `montanas`, `valles`, `volcanes` o `llanuras`. |
| `color` | string | Después de quitar espacios al principio y al final, debe coincidir con uno de los nombres admitidos abajo. No puede estar vacío. |
| `altura` | number | Número entre `0` y `100`, incluidos ambos extremos. |

Colores aceptados por `main.py`:

- `Verde bosque`
- `Terracota`
- `Crema`
- `Tinta`
- `Maíz`
- `Turquesa`
- `Bugambilia`
- `Café`
- `Gris`

Los últimos dos corresponden a opciones adicionales del selector móvil contempladas por el backend.

## 5. Ejemplos de respuestas por endpoint

Los ejemplos muestran respuestas correctas. Los valores dinámicos reflejan una configuración con `montanas`, `Verde bosque` y altura `75`.

### GET `/`

HTTP `200`:

```json
{
  "mensaje": "Backend de AR Sandbox funcionando correctamente",
  "proyecto": "AR Sandbox",
  "estado": "activo"
}
```

### GET `/health`

HTTP `200`:

```json
{
  "estado": "activo",
  "mensaje": "El servidor está funcionando correctamente"
}
```

### POST `/simulaciones/configuracion`

HTTP `201` al registrar correctamente:

```json
{
  "mensaje": "Configuración recibida correctamente",
  "estado": "lista",
  "configuracion": {
    "terreno": "montanas",
    "color": "Verde bosque",
    "altura": 75.0
  }
}
```

Si ya había una simulación en ejecución, registrar otra configuración reemplaza la configuración guardada y la respuesta conserva el estado `en_ejecucion`.

### GET `/simulaciones/configuracion`

HTTP `200` cuando existe configuración:

```json
{
  "mensaje": "Configuración actual",
  "estado": "lista",
  "configuracion": {
    "terreno": "montanas",
    "color": "Verde bosque",
    "altura": 75.0
  }
}
```

El campo `estado` puede reflejar el estado actual, por ejemplo `lista`, `en_ejecucion` o `detenida`.

### POST `/simulaciones/iniciar`

No envía cuerpo; utiliza la configuración guardada. HTTP `200`:

```json
{
  "mensaje": "Simulación iniciada correctamente",
  "estado": "en_ejecucion",
  "configuracion": {
    "terreno": "montanas",
    "color": "Verde bosque",
    "altura": 75.0
  }
}
```

### POST `/simulaciones/detener`

No envía cuerpo. Si estaba en ejecución, responde HTTP `200`:

```json
{
  "mensaje": "Simulación detenida correctamente",
  "estado": "detenida",
  "configuracion": {
    "terreno": "montanas",
    "color": "Verde bosque",
    "altura": 75.0
  }
}
```

### GET `/simulaciones/estado`

HTTP `200`; cuando existe configuración:

```json
{
  "estado": "en_ejecucion",
  "configuracion": {
    "terreno": "montanas",
    "color": "Verde bosque",
    "altura": 75.0
  }
}
```

Antes de configurar, la respuesta es:

```json
{
  "estado": "sin_configurar",
  "configuracion": null
}
```

## 6. Estados de simulación

| Estado | Significado |
| --- | --- |
| `sin_configurar` | Estado inicial; aún no existe una configuración. |
| `lista` | Hay configuración y se puede iniciar. También se establece al registrar una configuración si no hay una ejecución activa. |
| `en_ejecucion` | Se inició la simulación lógica local. |
| `detenida` | Se detuvo una simulación que estaba en ejecución; la configuración permanece guardada. |

Al registrar una configuración, el estado pasa a `lista`, salvo que ya sea `en_ejecucion`; en ese caso conserva `en_ejecucion`. Iniciar desde `lista` o `detenida` establece `en_ejecucion`. Detener una ejecución establece `detenida`.

## 7. Errores

Los errores de reglas de negocio usan `HTTPException`; FastAPI coloca su contenido dentro de `detail`.

### Iniciar antes de registrar una configuración — HTTP `400`

```json
{
  "detail": {
    "mensaje": "Selecciona y registra un terreno antes de iniciar",
    "estado": "sin_configurar"
  }
}
```

### Intentar iniciar mientras ya está en ejecución — HTTP `400`

```json
{
  "detail": {
    "mensaje": "Ya hay una simulación en ejecución",
    "estado": "en_ejecucion"
  }
}
```

### Detener cuando no hay una ejecución activa — HTTP `400`

```json
{
  "detail": {
    "mensaje": "No hay una simulación activa para detener",
    "estado": "lista"
  }
}
```

El valor de `estado` en esta respuesta depende del estado real al intentar detener.

### Consultar configuración antes del primer registro — HTTP `404`

```json
{
  "detail": {
    "mensaje": "Todavía no se ha configurado ninguna simulación",
    "estado": "sin_configurar"
  }
}
```

### Cuerpo inválido — HTTP `422`

FastAPI y Pydantic generan automáticamente el detalle de validación. Por ejemplo, con `altura` igual a `101`:

```json
{
  "detail": [
    {
      "type": "less_than_equal",
      "loc": ["body", "altura"],
      "msg": "Input should be less than or equal to 100",
      "input": 101,
      "ctx": {"le": 100}
    }
  ]
}
```

El error se devuelve también si falta un campo, el terreno no está permitido, el color está vacío o no pertenece a la paleta. El detalle concreto depende del campo que no pase la validación.

## 8. Almacenamiento temporal

La biblioteca de simulaciones y la calibración se guardan en `backend/simulaciones.db` mediante SQLite y sobreviven al reinicio del servidor. El estado de ejecución, la captura solicitada y la proyección solicitada siguen en memoria y vuelven a sus valores iniciales al reiniciar. El almacenamiento activo tampoco se comparte entre varios procesos del servidor.

## 9. Integración con Flutter y el módulo 3D

El módulo de visualización 3D podrá consultar:

- `GET /simulaciones/estado` para conocer el estado y la configuración asociada.
- `GET /simulaciones/configuracion` para leer la última configuración; antes del primer registro esta ruta responde `404`.

La información de terreno contiene `terreno`, `color` y `altura`. Flutter controla el estado de simulación, captura y proyección; carga/guarda calibración en `/calibracion`. El puente Kinect envía profundidad a `/ws/sensor/captura`, donde recibe los comandos de pausar y reanudar. Vue consulta la calibración y recibe fotogramas por `/ws/sensor/stream` para actualizar el relieve.

FastAPI conserva la calibración en SQLite y sirve sus valores a Flutter y Vue. La solicitud de proyección controla los visores web abiertos; el navegador todavía puede requerir una acción del usuario para entrar a pantalla completa.

## 10. Ejecutar el backend

Desde PowerShell, entrar a la carpeta `backend` y ejecutar el entorno virtual existente:

```powershell
cd C:\dev\proyectos_flutter\ar_sandbox\backend
.\venv\Scripts\python.exe -m uvicorn main:app --reload
```

Por defecto, Uvicorn escucha en `http://127.0.0.1:8000`. La documentación interactiva está en:

- Swagger UI: `http://127.0.0.1:8000/docs`
- ReDoc: `http://127.0.0.1:8000/redoc`
- Esquema OpenAPI: `http://127.0.0.1:8000/openapi.json`

## 11. Observaciones sobre el contrato actual

- Los errores de validación del cuerpo responden `422` por el comportamiento predeterminado de FastAPI/Pydantic; los errores de operación definidos explícitamente en el código responden `400`.
- `POST /simulaciones/configuracion` se puede llamar durante `en_ejecucion`: reemplaza la configuración guardada y mantiene ese estado. Por eso un `GET /simulaciones/estado` posterior mostrará la nueva configuración junto con `en_ejecucion`; el código actual no conserva una copia separada de la configuración con la que se inició.
- El modelo Pydantic usa su comportamiento predeterminado para campos adicionales: los campos que no aparecen en el modelo se ignoran, no producen un error de validación.
- `GET /simulaciones/configuracion` declara un modelo de respuesta para el caso correcto, pero el caso sin configuración devuelve el error `404` anterior.
