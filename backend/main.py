from fastapi import FastAPI


# Aplicación principal y metadatos de la documentación automática.
app = FastAPI(
    title="AR Sandbox API",
    description="Primer servidor del proyecto AR Sandbox.",
    version="1.0.0",
)


@app.get("/")
async def inicio():
    """Devuelve información básica del backend."""
    return {
        "mensaje": "Backend de AR Sandbox funcionando correctamente",
        "proyecto": "AR Sandbox",
        "estado": "activo",
    }


@app.get("/health")
async def health():
    """Confirma que el servidor está disponible."""
    return {
        "estado": "activo",
        "mensaje": "El servidor está funcionando correctamente",
    }
