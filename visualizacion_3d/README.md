# Módulo de visualización 3D — AR Sandbox

## Tecnologías utilizadas

- Vue.js 3
- Vite
- Three.js
- JavaScript
- HTML y CSS
- Fetch API

## Estructura del módulo

```text
visualizacion_3d/
├── src/
│   ├── components/
│   │   ├── EstadoConexion.vue
│   │   ├── PanelInformacion.vue
│   │   └── VisorTerreno.vue
│   ├── config/
│   │   └── api.js
│   ├── services/
│   │   └── backendService.js
│   ├── three/
│   │   ├── camara.js
│   │   ├── escena.js
│   │   └── terrenos.js
│   ├── App.vue
│   ├── main.js
│   └── style.css
├── index.html
├── package.json
├── vite.config.js
├── public/
└── README.md
```

## Instalación

```bash
cd visualizacion_3d
npm install
```

## Configuración del backend

La URL base está centralizada en `src/config/api.js` y puede sobrescribirse mediante una variable de entorno:

```bash
VITE_API_BASE_URL=http://127.0.0.1:8000
```

Si no se define, se usa por defecto:

```text
http://127.0.0.1:8000
```

## Ejecución

### Desarrollo

```bash
cd visualizacion_3d
npm run dev -- --host 0.0.0.0
```

### Producción

```bash
cd visualizacion_3d
npm run build
npm run preview -- --host 0.0.0.0
```

## Comunicación con FastAPI

El módulo consulta la API existente usando `fetch` desde `src/services/backendService.js`:

- `GET /health`
- `GET /simulaciones/configuracion`
- `GET /simulaciones/estado`

Se manejan errores de conexión, falta de configuración y estados de simulación.

## Generación de terrenos

La escena Three.js genera geometrías reales y modificables mediante `PlaneGeometry` y un sistema de alturas dependiente de la configuración:

- `montanas`: elevaciones irregulares con picos distintos
- `valles`: depresiones con sustratos laterales
- `volcanes`: forma cónica con cráter visible
- `llanuras`: superficie casi plana con pequeñas variaciones

El material adopta el color recibido desde la API, mientras que la altura modifica la amplitud del relieve.

## Pruebas realizadas

Se validó:

- compilación de Vue con `npm run build`
- render de la escena Three.js
- visualización de los cuatro tipos de terreno
- actualización de la geometría a partir de datos del backend
- manejo de estados de conexión y falta de configuración

## Limitaciones actuales

- La visualización depende de la configuración existente en FastAPI.
- Si el backend no está disponible, el visor muestra un estado de desconexión sin cerrar la interfaz.
- Si un navegador accede desde un origen distinto al de FastAPI, puede aparecer un problema de CORS y deberá resolverse en la configuración del backend.

## Ejecución conjunta del equipo

Se recomienda iniciar los tres módulos en paralelo:

```bash
# Backend FastAPI
cd backend
python -m uvicorn main:app --host 127.0.0.1 --port 8000 --reload

# Frontend 3D
cd visualizacion_3d
npm run dev -- --host 0.0.0.0

# Aplicación móvil Flutter
cd aplicacion_movil
flutter run
```

El flujo esperado es:

Flutter -> FastAPI -> Vue.js + Three.js

La configuración del terreno se registra desde Flutter, FastAPI la conserva en memoria y el módulo 3D la consume y representa visualmente en escena.
