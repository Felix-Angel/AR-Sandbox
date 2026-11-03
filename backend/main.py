import sqlite3
from pathlib import Path
from typing import Literal

from fastapi import FastAPI, HTTPException, status
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field, field_validator


# Aplicación principal y metadatos de la documentación automática.
app = FastAPI(
    title="AR Sandbox API",
    description="API inicial para configurar y controlar simulaciones de AR Sandbox.",
    version="1.0.0",
)
app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "http://localhost:5173",
        "http://127.0.0.1:5173",
    ],
    allow_credentials=False,
    allow_methods=["GET", "POST"],
    allow_headers=["Content-Type", "Accept"],
)


Terreno = Literal["montanas", "valles", "volcanes", "llanuras"]
Estado = Literal["sin_configurar", "lista", "en_ejecucion", "detenida"]

COLORES_PERMITIDOS = {
    "Verde bosque",
    "Terracota",
    "Crema",
    "Tinta",
    "Maíz",
    "Turquesa",
    "Bugambilia",
    # También se admiten las opciones adicionales del selector móvil.
    "Café",
    "Gris",
}


class ConfiguracionSimulacion(BaseModel):
    """Parámetros del relieve que se utilizarán en una simulación."""

    terreno: Terreno = Field(description="Tipo de relieve seleccionado.")
    color: str = Field(description="Nombre del color configurado en la aplicación.")
    altura: float = Field(ge=0, le=100, description="Altura del relieve, entre 0 y 100.")

    @field_validator("color")
    @classmethod
    def validar_color(cls, valor: str) -> str:
        """Rechaza nombres vacíos o que no estén en la paleta de la aplicación."""
        color = valor.strip()
        if not color:
            raise ValueError("El color no puede estar vacío.")
        if color not in COLORES_PERMITIDOS:
            raise ValueError("El color seleccionado no está permitido.")
        return color


class RespuestaConfiguracion(BaseModel):
    mensaje: str
    estado: Estado
    configuracion: ConfiguracionSimulacion


class RespuestaEstado(BaseModel):
    estado: Estado
    configuracion: ConfiguracionSimulacion | None


class SolicitudSimulacionGuardada(ConfiguracionSimulacion):
    nombre: str = Field(min_length=1, max_length=60)

    @field_validator("nombre")
    @classmethod
    def validar_nombre(cls, valor: str) -> str:
        nombre = valor.strip()
        if not nombre:
            raise ValueError("El nombre no puede estar vacío.")
        return nombre


class SimulacionGuardada(BaseModel):
    id: int
    nombre: str
    configuracion: ConfiguracionSimulacion


class RespuestaSimulacionGuardada(RespuestaConfiguracion):
    id: int
    nombre: str


# Almacenamiento temporal del último ajuste y estado de la simulación.
configuracion_actual: ConfiguracionSimulacion | None = None
estado_simulacion: Estado = "sin_configurar"
RUTA_BASE_DATOS = Path(__file__).with_name("simulaciones.db")


def conectar_base_datos():
    conexion = sqlite3.connect(RUTA_BASE_DATOS)
    conexion.row_factory = sqlite3.Row
    return conexion


with conectar_base_datos() as conexion:
    conexion.execute(
        """CREATE TABLE IF NOT EXISTS simulaciones_guardadas (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            nombre TEXT NOT NULL,
            terreno TEXT NOT NULL,
            color TEXT NOT NULL,
            altura REAL NOT NULL,
            creada_en TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
        )"""
    )


@app.get("/", tags=["Información"], summary="Información del backend")
async def inicio():
    """Devuelve información básica del backend AR Sandbox."""
    return {
        "mensaje": "Backend de AR Sandbox funcionando correctamente",
        "proyecto": "AR Sandbox",
        "estado": "activo",
    }


@app.get("/health", tags=["Información"], summary="Comprobar disponibilidad")
async def health():
    """Confirma que el servidor está disponible."""
    return {
        "estado": "activo",
        "mensaje": "El servidor está funcionando correctamente",
    }


@app.post(
    "/simulaciones/configuracion",
    response_model=RespuestaConfiguracion,
    status_code=status.HTTP_201_CREATED,
    tags=["Simulaciones"],
    summary="Registrar configuración",
    description="Valida y guarda en memoria el último terreno, color y altura recibidos.",
)
async def registrar_configuracion(configuracion: ConfiguracionSimulacion):
    """Guarda una configuración para poder iniciar una simulación."""
    global configuracion_actual, estado_simulacion

    configuracion_actual = configuracion
    if estado_simulacion != "en_ejecucion":
        estado_simulacion = "lista"

    return {
        "mensaje": "Configuración recibida correctamente",
        "estado": estado_simulacion,
        "configuracion": configuracion_actual,
    }


@app.get(
    "/simulaciones/configuracion",
    response_model=RespuestaConfiguracion,
    tags=["Simulaciones"],
    summary="Consultar configuración",
    description="Devuelve la última configuración registrada en memoria.",
    responses={404: {"description": "Todavía no existe una configuración."}},
)
async def obtener_configuracion():
    """Devuelve la configuración actual o informa que aún no existe."""
    if configuracion_actual is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail={
                "mensaje": "Todavía no se ha configurado ninguna simulación",
                "estado": estado_simulacion,
            },
        )

    return {
        "mensaje": "Configuración actual",
        "estado": estado_simulacion,
        "configuracion": configuracion_actual,
    }


@app.get(
    "/simulaciones/guardadas",
    response_model=list[SimulacionGuardada],
    tags=["Simulaciones"],
    summary="Listar simulaciones guardadas",
)
async def listar_simulaciones_guardadas():
    with conectar_base_datos() as conexion:
        filas = conexion.execute(
            "SELECT id, nombre, terreno, color, altura "
            "FROM simulaciones_guardadas ORDER BY creada_en DESC, id DESC"
        ).fetchall()
    return [
        {
            "id": fila["id"],
            "nombre": fila["nombre"],
            "configuracion": {
                "terreno": fila["terreno"],
                "color": fila["color"],
                "altura": fila["altura"],
            },
        }
        for fila in filas
    ]


@app.post(
    "/simulaciones/guardadas",
    response_model=RespuestaSimulacionGuardada,
    status_code=status.HTTP_201_CREATED,
    tags=["Simulaciones"],
    summary="Guardar simulación con nombre",
)
async def guardar_simulacion(solicitud: SolicitudSimulacionGuardada):
    global configuracion_actual, estado_simulacion

    config = ConfiguracionSimulacion(
        terreno=solicitud.terreno,
        color=solicitud.color,
        altura=solicitud.altura,
    )
    with conectar_base_datos() as conexion:
        cursor = conexion.execute(
            "INSERT INTO simulaciones_guardadas (nombre, terreno, color, altura) "
            "VALUES (?, ?, ?, ?)",
            (solicitud.nombre, config.terreno, config.color, config.altura),
        )
        simulacion_id = cursor.lastrowid

    # Guardar una nueva variante no reemplaza una simulación que ya está corriendo.
    if estado_simulacion != "en_ejecucion":
        configuracion_actual = config
        estado_simulacion = "lista"

    return {
        "id": simulacion_id,
        "nombre": solicitud.nombre,
        "mensaje": f'Simulación "{solicitud.nombre}" guardada correctamente',
        "estado": estado_simulacion,
        "configuracion": configuracion_actual or config,
    }


@app.post(
    "/simulaciones/guardadas/{simulacion_id}/seleccionar",
    response_model=RespuestaConfiguracion,
    tags=["Simulaciones"],
    summary="Seleccionar simulación guardada",
)
async def seleccionar_simulacion(simulacion_id: int):
    global configuracion_actual, estado_simulacion

    if estado_simulacion == "en_ejecucion":
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Detén la simulación actual antes de seleccionar otra.",
        )
    with conectar_base_datos() as conexion:
        fila = conexion.execute(
            "SELECT terreno, color, altura FROM simulaciones_guardadas WHERE id = ?",
            (simulacion_id,),
        ).fetchone()
    if fila is None:
        raise HTTPException(status_code=404, detail="Simulación guardada no encontrada.")

    configuracion_actual = ConfiguracionSimulacion(**dict(fila))
    estado_simulacion = "lista"
    return {
        "mensaje": "Simulación seleccionada y lista para iniciar",
        "estado": estado_simulacion,
        "configuracion": configuracion_actual,
    }


@app.post(
    "/simulaciones/iniciar",
    response_model=RespuestaConfiguracion,
    tags=["Simulaciones"],
    summary="Iniciar simulación local",
    description="Inicia una simulación de prueba con la última configuración registrada.",
    responses={400: {"description": "No hay configuración o ya está en ejecución."}},
)
async def iniciar_simulacion():
    """Inicia una sola simulación cuando existe una configuración válida."""
    global estado_simulacion

    if configuracion_actual is None:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail={
                "mensaje": "Selecciona y registra un terreno antes de iniciar",
                "estado": estado_simulacion,
            },
        )
    if estado_simulacion == "en_ejecucion":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail={
                "mensaje": "Ya hay una simulación en ejecución",
                "estado": estado_simulacion,
            },
        )

    estado_simulacion = "en_ejecucion"
    return {
        "mensaje": "Simulación iniciada correctamente",
        "estado": estado_simulacion,
        "configuracion": configuracion_actual,
    }


@app.post(
    "/simulaciones/detener",
    response_model=RespuestaConfiguracion,
    tags=["Simulaciones"],
    summary="Detener simulación local",
    description="Detiene la simulación si se encuentra en ejecución.",
    responses={400: {"description": "No hay una simulación en ejecución."}},
)
async def detener_simulacion():
    """Detiene una simulación activa e informa si no hay ninguna activa."""
    global estado_simulacion

    if estado_simulacion != "en_ejecucion" or configuracion_actual is None:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail={
                "mensaje": "No hay una simulación activa para detener",
                "estado": estado_simulacion,
            },
        )

    estado_simulacion = "detenida"
    return {
        "mensaje": "Simulación detenida correctamente",
        "estado": estado_simulacion,
        "configuracion": configuracion_actual,
    }


@app.get(
    "/simulaciones/estado",
    response_model=RespuestaEstado,
    tags=["Simulaciones"],
    summary="Consultar estado de simulación",
    description="Devuelve el estado actual y la configuración asociada, si existe.",
)
async def obtener_estado():
    """Informa si la simulación está sin configurar, lista, activa o detenida."""
    return {
        "estado": estado_simulacion,
        "configuracion": configuracion_actual,
    }
