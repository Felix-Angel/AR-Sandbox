export const CLAVE_CONFIGURACION_FISICA = 'ar-sandbox-configuracion-fisica-v1'

export const CONFIGURACION_FISICA_INICIAL = Object.freeze({
  caja: { anchoCm: 80, profundidadCm: 80 },
  kinect: {
    desplazamientoXCm: 0,
    desplazamientoZCm: 0,
    alturaCm: null,
    inclinacionGrados: 0,
    giroGrados: 0,
  },
  proyector: {
    desplazamientoXCm: 0,
    desplazamientoZCm: 0,
    alturaCm: null,
    inclinacionGrados: 0,
    giroGrados: 0,
  },
})

function numeroOpcion(valor, predeterminado = null) {
  if (valor === null || valor === undefined || valor === '') return predeterminado
  const numero = Number(valor)
  return Number.isFinite(numero) ? numero : predeterminado
}

export function normalizarConfiguracionFisica(datos = {}) {
  const caja = datos.caja || {}
  const kinect = datos.kinect || {}
  const proyector = datos.proyector || {}

  return {
    caja: {
      anchoCm: numeroOpcion(caja.anchoCm, CONFIGURACION_FISICA_INICIAL.caja.anchoCm),
      profundidadCm: numeroOpcion(caja.profundidadCm, CONFIGURACION_FISICA_INICIAL.caja.profundidadCm),
    },
    kinect: normalizarMontaje(kinect),
    proyector: normalizarMontaje(proyector),
  }
}

function normalizarMontaje(montaje = {}) {
  return {
    desplazamientoXCm: numeroOpcion(montaje.desplazamientoXCm, 0),
    desplazamientoZCm: numeroOpcion(montaje.desplazamientoZCm, 0),
    alturaCm: numeroOpcion(montaje.alturaCm),
    inclinacionGrados: numeroOpcion(montaje.inclinacionGrados, 0),
    giroGrados: numeroOpcion(montaje.giroGrados, 0),
  }
}

export function validarConfiguracionFisica(configuracion) {
  const { caja, kinect, proyector } = configuracion
  const dimensionesValidas = [caja.anchoCm, caja.profundidadCm]
    .every((valor) => Number.isFinite(valor) && valor >= 10 && valor <= 500)
  if (!dimensionesValidas) return false

  return [kinect, proyector].every((montaje) => {
    const desplazamientosValidos = [montaje.desplazamientoXCm, montaje.desplazamientoZCm]
      .every((valor) => Number.isFinite(valor) && valor >= -500 && valor <= 500)
    const angulosValidos = [montaje.inclinacionGrados, montaje.giroGrados]
      .every((valor) => Number.isFinite(valor) && valor >= -180 && valor <= 180)
    const alturaValida = montaje.alturaCm === null
      || (Number.isFinite(montaje.alturaCm) && montaje.alturaCm > 0 && montaje.alturaCm <= 1000)
    return desplazamientosValidos && angulosValidos && alturaValida
  })
}

export function cargarConfiguracionFisica() {
  try {
    const guardada = window.localStorage.getItem(CLAVE_CONFIGURACION_FISICA)
    if (!guardada) return null

    const configuracion = normalizarConfiguracionFisica(JSON.parse(guardada))
    return validarConfiguracionFisica(configuracion) ? configuracion : null
  } catch {
    return null
  }
}

export function guardarConfiguracionFisica(configuracion) {
  if (!validarConfiguracionFisica(configuracion)) {
    throw new Error('Revisa las dimensiones y posiciones antes de guardar.')
  }
  window.localStorage.setItem(CLAVE_CONFIGURACION_FISICA, JSON.stringify(configuracion))
}
