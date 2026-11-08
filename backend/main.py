import asyncio
import json
import sqlite3
import struct
import time
from datetime import datetime, timezone
from pathlib import Path
from typing import Literal

from fastapi import FastAPI, HTTPException, WebSocket, WebSocketDisconnect, status
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
    allow_methods=["GET", "POST", "PUT"],
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


class SolicitudControl(BaseModel):
    activo: bool


class AjustesCalibracion(BaseModel):
    superficie: Literal["caja", "pizarron"] = "caja"
    orientacion: Literal["horizontal", "vertical"] = "horizontal"
    ancho: float = Field(default=21.6, ge=1, le=100)
    alto: float = Field(default=21.6, ge=1, le=100)
    desplazamientoX: float = Field(default=0, ge=-10, le=10)
    desplazamientoY: float = Field(default=0, ge=-10, le=10)
    escala: float = Field(default=1, ge=0.1, le=3)
    rotacion: float = Field(default=0, ge=-180, le=180)
    centroSensorX: float = Field(default=50, ge=0, le=100)
    centroSensorY: float = Field(default=50, ge=0, le=100)
    anchoSensor: float = Field(default=100, ge=10, le=100)
    altoSensor: float = Field(default=100, ge=10, le=100)
    mostrarCuadricula: bool = False
    mostrarMalla: bool = False


# Almacenamiento temporal del último ajuste y estado de la simulación.
configuracion_actual: ConfiguracionSimulacion | None = None
estado_simulacion: Estado = "sin_configurar"
RUTA_BASE_DATOS = Path(__file__).with_name("simulaciones.db")

# Paquete binario ARKD v1: cabecera de 30 bytes seguida de profundidad uint16 LE.
FORMATO_CABECERA_PROFUNDIDAD = struct.Struct("<4sBBHHIQHHI")
MAGIA_PAQUETE_PROFUNDIDAD = b"ARKD"
VERSION_PAQUETE_PROFUNDIDAD = 1
MAX_ANCHO_PROFUNDIDAD = 640
MAX_ALTO_PROFUNDIDAD = 480
MAX_TAMANO_PAQUETE_PROFUNDIDAD = FORMATO_CABECERA_PROFUNDIDAD.size + (
    MAX_ANCHO_PROFUNDIDAD * MAX_ALTO_PROFUNDIDAD * 2
)

sensor_conectado = False
sensor_ancho = 0
sensor_alto = 0
sensor_fps = 0.0
sensor_id_fotograma = 0
sensor_marca_tiempo = None
sensor_profundidad_minima = 0
sensor_profundidad_maxima = 0
sensor_pixeles_validos = 0
ultimo_paquete_profundidad: bytes | None = None
ultimo_fotograma_monotonic: float | None = None
captura_solicitada = True
socket_captura_sensor: WebSocket | None = None
proyeccion_solicitada = False
clientes_stream_profundidad: set[WebSocket] = set()
cerrojo_conexion_sensor = asyncio.Lock()
fotogramas_fps = 0
inicio_intervalo_fps = time.monotonic()


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
    conexion.execute(
        "CREATE TABLE IF NOT EXISTS ajustes_sistema (clave TEXT PRIMARY KEY, valores TEXT NOT NULL)"
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


def validar_paquete_profundidad(paquete: bytes) -> dict | None:
    """Valida la cabecera y el tamaño de un fotograma ARKD v1."""
    if len(paquete) < FORMATO_CABECERA_PROFUNDIDAD.size or len(paquete) > MAX_TAMANO_PAQUETE_PROFUNDIDAD:
        return None

    (
        magia,
        version,
        _flags,
        ancho,
        alto,
        id_fotograma,
        marca_tiempo_ms,
        profundidad_minima,
        profundidad_maxima,
        pixeles_validos,
    ) = FORMATO_CABECERA_PROFUNDIDAD.unpack_from(paquete)

    cantidad_pixeles = ancho * alto
    if (
        magia != MAGIA_PAQUETE_PROFUNDIDAD
        or version != VERSION_PAQUETE_PROFUNDIDAD
        or ancho < 1
        or alto < 1
        or ancho > MAX_ANCHO_PROFUNDIDAD
        or alto > MAX_ALTO_PROFUNDIDAD
        or len(paquete) != FORMATO_CABECERA_PROFUNDIDAD.size + cantidad_pixeles * 2
        or pixeles_validos > cantidad_pixeles
        or profundidad_maxima < profundidad_minima
        or (pixeles_validos > 0 and profundidad_minima == 0)
    ):
        return None

    return {
        "ancho": ancho,
        "alto": alto,
        "id_fotograma": id_fotograma,
        "marca_tiempo_ms": marca_tiempo_ms,
        "profundidad_minima_mm": profundidad_minima,
        "profundidad_maxima_mm": profundidad_maxima,
        "pixeles_validos": pixeles_validos,
    }


def obtener_estado_sensor() -> dict:
    """Entrega el estado de la conexión y del último fotograma recibido."""
    capturando = (
        captura_solicitada
        and sensor_conectado
        and ultimo_fotograma_monotonic is not None
        and time.monotonic() - ultimo_fotograma_monotonic <= 2.0
    )
    return {
        "estado": "capturando" if capturando else (
            "conectado_sin_datos" if sensor_conectado else "desconectado"
        ),
        "conectado": sensor_conectado,
        "captura_solicitada": captura_solicitada,
        "capturando": capturando,
        "ancho": sensor_ancho,
        "alto": sensor_alto,
        "fps": sensor_fps if capturando else 0.0,
        "id_fotograma": sensor_id_fotograma,
        "ultimo_fotograma": sensor_marca_tiempo,
        "profundidad_minima_mm": sensor_profundidad_minima,
        "profundidad_maxima_mm": sensor_profundidad_maxima,
        "pixeles_validos": sensor_pixeles_validos,
        "visores_conectados": len(clientes_stream_profundidad),
    }


async def distribuir_paquete_profundidad(paquete: bytes) -> None:
    """Reenvía el fotograma a los visores conectados y limpia los caídos."""
    if not clientes_stream_profundidad:
        return

    async def enviar_a_cliente(cliente: WebSocket) -> None:
        try:
            await cliente.send_bytes(paquete)
        except Exception:
            clientes_stream_profundidad.discard(cliente)

    await asyncio.gather(
        *(enviar_a_cliente(cliente) for cliente in tuple(clientes_stream_profundidad))
    )


@app.get("/sensor/estado", tags=["Sensor"], summary="Consultar estado del Kinect")
async def consultar_estado_sensor():
    return obtener_estado_sensor()


@app.websocket("/ws/sensor/captura")
async def recibir_fotogramas_sensor(websocket: WebSocket):
    """Recibe fotogramas ARKD binarios desde el puente local de Kinect v1."""
    global sensor_conectado, sensor_ancho, sensor_alto
    global sensor_fps, sensor_id_fotograma, sensor_marca_tiempo
    global sensor_profundidad_minima, sensor_profundidad_maxima
    global sensor_pixeles_validos, ultimo_paquete_profundidad, socket_captura_sensor
    global ultimo_fotograma_monotonic, fotogramas_fps, inicio_intervalo_fps

    async with cerrojo_conexion_sensor:
        if sensor_conectado:
            await websocket.close(code=1008, reason="Ya hay un Kinect conectado a este backend.")
            return
        await websocket.accept()
        sensor_conectado = True
        socket_captura_sensor = websocket
        sensor_fps = 0.0
        fotogramas_fps = 0
        inicio_intervalo_fps = time.monotonic()

    try:
        await websocket.send_json({"captura": captura_solicitada})
        while True:
            mensaje = await websocket.receive()
            if mensaje["type"] == "websocket.disconnect":
                break
            paquete = mensaje.get("bytes")
            if paquete is None:
                await websocket.close(code=1003, reason="Se esperaba un fotograma binario ARKD.")
                break
            datos = validar_paquete_profundidad(paquete)
            if datos is None:
                await websocket.close(code=1003, reason="Fotograma ARKD inválido o fuera de tamaño.")
                break

            ahora_monotonic = time.monotonic()
            ahora_utc = datetime.now(timezone.utc)
            sensor_ancho = datos["ancho"]
            sensor_alto = datos["alto"]
            sensor_id_fotograma = datos["id_fotograma"]
            sensor_marca_tiempo = ahora_utc.isoformat()
            sensor_profundidad_minima = datos["profundidad_minima_mm"]
            sensor_profundidad_maxima = datos["profundidad_maxima_mm"]
            sensor_pixeles_validos = datos["pixeles_validos"]
            ultimo_paquete_profundidad = paquete
            ultimo_fotograma_monotonic = ahora_monotonic

            fotogramas_fps += 1
            intervalo = ahora_monotonic - inicio_intervalo_fps
            if intervalo >= 1.0:
                sensor_fps = round(fotogramas_fps / intervalo, 2)
                fotogramas_fps = 0
                inicio_intervalo_fps = ahora_monotonic

            await distribuir_paquete_profundidad(paquete)
    except WebSocketDisconnect:
        pass
    finally:
        async with cerrojo_conexion_sensor:
            sensor_conectado = False
            sensor_fps = 0.0
            if socket_captura_sensor is websocket:
                socket_captura_sensor = None


@app.post("/sensor/captura", tags=["Sensor"], summary="Iniciar o pausar envío de profundidad")
async def controlar_captura_sensor(solicitud: SolicitudControl):
    global captura_solicitada
    captura_solicitada = solicitud.activo
    if socket_captura_sensor is not None:
        try:
            await socket_captura_sensor.send_json({"captura": captura_solicitada})
        except Exception:
            pass
    return {"activo": captura_solicitada, "mensaje": "Captura iniciada" if captura_solicitada else "Captura pausada"}


@app.get("/proyeccion/estado", tags=["Proyección"])
async def consultar_estado_proyeccion():
    return {"activo": proyeccion_solicitada}


@app.post("/proyeccion/control", tags=["Proyección"])
async def controlar_proyeccion(solicitud: SolicitudControl):
    global proyeccion_solicitada
    proyeccion_solicitada = solicitud.activo
    return {"activo": proyeccion_solicitada, "mensaje": "Proyección activada" if proyeccion_solicitada else "Proyección detenida"}


@app.get("/calibracion", tags=["Calibración"])
async def consultar_calibracion():
    with conectar_base_datos() as conexion:
        fila = conexion.execute("SELECT valores FROM ajustes_sistema WHERE clave = 'calibracion'").fetchone()
    return AjustesCalibracion(**json.loads(fila["valores"])) if fila else AjustesCalibracion()


@app.put("/calibracion", tags=["Calibración"])
async def guardar_calibracion(ajustes: AjustesCalibracion):
    valores = json.dumps(ajustes.model_dump(), ensure_ascii=False)
    with conectar_base_datos() as conexion:
        conexion.execute(
            "INSERT INTO ajustes_sistema (clave, valores) VALUES ('calibracion', ?) "
            "ON CONFLICT(clave) DO UPDATE SET valores = excluded.valores",
            (valores,),
        )
    return {"mensaje": "Calibración guardada en el backend", **ajustes.model_dump()}


@app.websocket("/ws/sensor/stream")
async def transmitir_fotogramas_sensor(websocket: WebSocket):
    """Publica fotogramas binarios en vivo para la visualización web."""
    await websocket.accept()
    clientes_stream_profundidad.add(websocket)

    try:
        if ultimo_paquete_profundidad is not None:
            await websocket.send_bytes(ultimo_paquete_profundidad)
        while True:
            mensaje = await websocket.receive()
            if mensaje["type"] == "websocket.disconnect":
                break
    except WebSocketDisconnect:
        pass
    finally:
        clientes_stream_profundidad.discard(websocket)


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
