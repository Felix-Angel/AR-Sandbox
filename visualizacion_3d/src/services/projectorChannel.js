export const PROJECTOR_CHANNEL_NAME = 'ar-sandbox-projector-v1'

const PROTOCOL_VERSION = 1
const APPLICATION_ID = 'ar-sandbox'

export function crearCanalProyector(rol, alRecibirMensaje) {
  if (typeof window === 'undefined' || typeof window.BroadcastChannel !== 'function') {
    return null
  }

  let canal
  try {
    canal = new window.BroadcastChannel(PROJECTOR_CHANNEL_NAME)
  } catch {
    return null
  }
  const manejarMensaje = (evento) => {
    const mensaje = evento.data
    if (
      mensaje?.aplicacion !== APPLICATION_ID
      || mensaje?.version !== PROTOCOL_VERSION
      || mensaje?.origen === rol
      || typeof mensaje?.tipo !== 'string'
    ) {
      return
    }

    alRecibirMensaje(mensaje)
  }

  canal.addEventListener('message', manejarMensaje)

  return {
    enviar(tipo, datos = {}) {
      canal.postMessage({
        aplicacion: APPLICATION_ID,
        version: PROTOCOL_VERSION,
        origen: rol,
        tipo,
        enviadoEn: Date.now(),
        datos,
      })
    },
    cerrar() {
      canal.removeEventListener('message', manejarMensaje)
      canal.close()
    },
  }
}
