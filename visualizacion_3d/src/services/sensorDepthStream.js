import { API_BASE_URL } from '../config/api.js'

const MAGIC = [0x41, 0x52, 0x4b, 0x44]
const HEADER_BYTES = 30
const MAX_WIDTH = 640
const MAX_HEIGHT = 480

export function parseDepthPacket(buffer) {
  if (!(buffer instanceof ArrayBuffer) || buffer.byteLength < HEADER_BYTES) {
    throw new Error('El fotograma de profundidad está incompleto.')
  }

  const view = new DataView(buffer)
  const magicValid = MAGIC.every((byte, index) => view.getUint8(index) === byte)
  const version = view.getUint8(4)
  const width = view.getUint16(6, true)
  const height = view.getUint16(8, true)
  const frameId = view.getUint32(10, true)
  const capturedAtMs = Number(view.getBigUint64(14, true))
  const minDepthMm = view.getUint16(22, true)
  const maxDepthMm = view.getUint16(24, true)
  const validPixels = view.getUint32(26, true)
  const pixelCount = width * height

  if (!magicValid || version !== 1
    || width < 1 || width > MAX_WIDTH
    || height < 1 || height > MAX_HEIGHT
    || validPixels > pixelCount
    || maxDepthMm < minDepthMm
    || buffer.byteLength !== HEADER_BYTES + pixelCount * 2) {
    throw new Error('El fotograma de profundidad no cumple el formato ARKD v1.')
  }

  return {
    buffer,
    payloadOffset: HEADER_BYTES,
    width,
    height,
    frameId,
    capturedAtMs,
    minDepthMm,
    maxDepthMm,
    validPixels,
  }
}

export function crearStreamProfundidad({ onFrame, onConnection, onError }) {
  const url = new URL(API_BASE_URL)
  url.protocol = url.protocol === 'https:' ? 'wss:' : 'ws:'
  url.pathname = `${url.pathname.replace(/\/$/, '')}/ws/sensor/stream`
  url.search = ''

  let socket = null
  let temporizadorReconexion = null
  let reintentoMs = 1000
  let cerrado = false

  const conectar = () => {
    if (cerrado) return

    try {
      socket = new WebSocket(url)
      socket.binaryType = 'arraybuffer'
    } catch (error) {
      onError?.(error)
      programarReconexion()
      return
    }

    socket.addEventListener('open', () => {
      reintentoMs = 1000
      onConnection?.(true)
    })

    socket.addEventListener('message', (event) => {
      try {
        onFrame?.(parseDepthPacket(event.data))
      } catch (error) {
        onError?.(error)
      }
    })

    socket.addEventListener('error', () => {
      onError?.(new Error('No se pudo mantener el flujo de profundidad de FastAPI.'))
      socket?.close()
    })

    socket.addEventListener('close', () => {
      onConnection?.(false)
      programarReconexion()
    })
  }

  const programarReconexion = () => {
    if (cerrado || temporizadorReconexion !== null) return
    temporizadorReconexion = window.setTimeout(() => {
      temporizadorReconexion = null
      conectar()
    }, reintentoMs)
    reintentoMs = Math.min(reintentoMs * 2, 5000)
  }

  conectar()

  return {
    cerrar() {
      cerrado = true
      if (temporizadorReconexion !== null) {
        window.clearTimeout(temporizadorReconexion)
        temporizadorReconexion = null
      }
      socket?.close(1000, 'Vista cerrada')
      socket = null
    },
  }
}
