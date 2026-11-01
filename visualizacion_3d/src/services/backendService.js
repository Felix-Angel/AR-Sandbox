import { API_BASE_URL, API_ROUTES } from '../config/api.js'

const buildUrl = (path) => `${API_BASE_URL}${path}`
const REQUEST_TIMEOUT_MS = 5000

async function requestJson(url, options = {}) {
  const controller = new AbortController()
  let timeoutAlcanzado = false
  const timeoutId = setTimeout(() => {
    timeoutAlcanzado = true
    controller.abort()
  }, REQUEST_TIMEOUT_MS)

  try {
    const response = await fetch(url, {
      headers: {
        Accept: 'application/json',
        ...(options.headers || {}),
      },
      ...options,
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
  }
}

export const backendService = {
  async healthCheck() {
    return requestJson(buildUrl(API_ROUTES.health))
  },

  async getConfiguracion() {
    return requestJson(buildUrl(API_ROUTES.configuracion))
  },

  async getEstado() {
    return requestJson(buildUrl(API_ROUTES.estado))
  },

  async getConfiguracionSiExiste() {
    try {
      return await this.getConfiguracion()
    } catch (error) {
      if (String(error.message).includes('Todavía no se ha configurado') || String(error.message).includes('404')) {
        return null
      }
      throw error
    }
  },
}
