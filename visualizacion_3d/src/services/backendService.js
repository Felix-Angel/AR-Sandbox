import { API_BASE_URL, API_ROUTES } from '../config/api.js'

const buildUrl = (path) => `${API_BASE_URL}${path}`
const REQUEST_TIMEOUT_MS = 5000

async function requestJson(url, options = {}) {
  const { signal: signalExterna, ...opcionesFetch } = options
  const controller = new AbortController()
  let timeoutAlcanzado = false
  const timeoutId = setTimeout(() => {
    timeoutAlcanzado = true
    controller.abort()
  }, REQUEST_TIMEOUT_MS)
  const cancelarPorSenalExterna = () => controller.abort(signalExterna.reason)

  if (signalExterna?.aborted) {
    cancelarPorSenalExterna()
  } else {
    signalExterna?.addEventListener('abort', cancelarPorSenalExterna, { once: true })
  }

  try {
    const response = await fetch(url, {
      headers: {
        Accept: 'application/json',
        ...(opcionesFetch.headers || {}),
      },
      ...opcionesFetch,
      signal: controller.signal,
    })

    const text = await response.text()
    let data = null

    if (text) {
      try {
        data = JSON.parse(text)
      } catch {
        data = text
      }
    }

    if (!response.ok) {
      const detail = data?.detail
      const message = typeof detail === 'string'
        ? detail
        : detail?.mensaje || `Error HTTP ${response.status}`

      throw new Error(message)
    }

    return data
  } catch (error) {
    if (timeoutAlcanzado) {
      throw new Error('La solicitud al servidor superó el tiempo límite de 5 segundos')
    }

    throw error
  } finally {
    clearTimeout(timeoutId)
    signalExterna?.removeEventListener('abort', cancelarPorSenalExterna)
  }
}

export const backendService = {
  async healthCheck({ signal } = {}) {
    return requestJson(buildUrl(API_ROUTES.health), { signal })
  },

  async getConfiguracion({ signal } = {}) {
    return requestJson(buildUrl(API_ROUTES.configuracion), { signal })
  },

  async getEstado({ signal } = {}) {
    return requestJson(buildUrl(API_ROUTES.estado), { signal })
  },

  async getSensorEstado({ signal } = {}) {
    return requestJson(buildUrl('/sensor/estado'), { signal })
  },

  async getEstadoProyeccion({ signal } = {}) {
    return requestJson(buildUrl('/proyeccion/estado'), { signal })
  },

  async setEstadoProyeccion(activo) {
    return requestJson(buildUrl('/proyeccion/control'), {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ activo }),
    })
  },

  async getCalibracion({ signal } = {}) {
    return requestJson(buildUrl('/calibracion'), { signal })
  },

  async getConfiguracionSiExiste({ signal } = {}) {
    try {
      return await this.getConfiguracion({ signal })
    } catch (error) {
      if (String(error.message).includes('Todavía no se ha configurado') || String(error.message).includes('404')) {
        return null
      }
      throw error
    }
  },
}
