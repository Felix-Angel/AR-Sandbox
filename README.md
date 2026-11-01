# AR Sandbox

## Descripción del proyecto

AR Sandbox es un sistema de simulación y proyección de relieves tridimensionales que permitirá al usuario seleccionar diferentes tipos de terrenos desde una aplicación móvil y visualizar los cambios en una computadora mediante una representación 3D.

El proyecto busca integrar una aplicación móvil, un servicio backend y un módulo de visualización tridimensional, con la posibilidad de proyectar posteriormente los relieves sobre una superficie física con arena.

## Objetivo general

Desarrollar un sistema que permita controlar y visualizar simulaciones de terrenos tridimensionales mediante una aplicación móvil y tecnologías de comunicación entre dispositivos.

## Tecnologías propuestas

- **Flutter y Dart:** desarrollo de la aplicación móvil.
- **Python y FastAPI:** desarrollo del backend y comunicación entre módulos.
- **Vue.js y Three.js:** visualización y generación de terrenos tridimensionales.
- **Git y GitHub:** control de versiones y colaboración del equipo.

## Módulos principales

1. Aplicación móvil.
2. Backend y API.
3. Visualización 3D.
4. Integración y proyección.

## Estado actual

El proyecto ya cuenta con los tres componentes principales desarrollados y conectados al contrato del backend:

- **Aplicación móvil (Flutter/Dart):** desarrollada por el compañero del equipo.
- **Backend (Python/FastAPI):** ya operativo y validado con los endpoints de simulación.
- **Visualización 3D (Vue.js + Three.js):** implementada en `visualizacion_3d/` con render real de terrenos, cámara interactiva y lectura de datos desde FastAPI.

## Estructura del repositorio

```text
AR-Sandbox/
├── aplicacion_movil/
├── backend/
├── visualizacion_3d/
├── documentacion/
├── README.md
├── .gitignore
└── LICENSE
```

## Módulo de visualización 3D

La carpeta `visualizacion_3d/` contiene una aplicación Vue + Vite que renderiza un terreno real con Three.js, soporta los cuatro tipos de relieve definidos por el backend y consume la API del proyecto para mostrar color, altura y estado de simulación.

### Terrenos soportados

- Montañas
- Valles
- Volcanes
- Llanuras

### Comunicación con FastAPI

La visualización consulta:

- `/health`
- `/simulaciones/configuracion`
- `/simulaciones/estado`

La base URL puede configurarse mediante la variable de entorno `VITE_API_BASE_URL`.

## Ejecución rápida

### Backend

```bash
cd backend
py -m uvicorn main:app --host 127.0.0.1 --port 8000 --reload
```

### Frontend 3D

```bash
cd visualizacion_3d
npm install
npm run dev -- --host 0.0.0.0
```

### Aplicación móvil

```bash
cd aplicacion_movil
flutter run
```

## Estado general

El proyecto está preparado para el flujo esperado:

Flutter -> FastAPI -> Vue.js + Three.js

La configuración del terreno se registra desde la app móvil, FastAPI la conserva en memoria y la visualización 3D la representa de forma dinámica.