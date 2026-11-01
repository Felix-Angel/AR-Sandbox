<script setup>
import { computed, onMounted, onUnmounted, ref } from 'vue'
import EstadoConexion from './components/EstadoConexion.vue'
import PanelCalibracion from './components/PanelCalibracion.vue'
import PanelInformacion from './components/PanelInformacion.vue'
import VisorTerreno from './components/VisorTerreno.vue'
import { backendService } from './services/backendService.js'

const configuracion = ref(null)
const estado = ref('sin_configurar')
const conectado = ref(false)
const cargando = ref(false)
const error = ref('')
const ultimaActualizacion = ref('Sin datos')
const contenedorApp = ref(null)
const modoProyector = ref(false)
const pantallaCompleta = ref(false)
const calibracion = ref({
  superficie: 'caja',
  orientacion: 'horizontal',
  ancho: 21.6,
  alto: 21.6,
  desplazamientoX: 0,
  desplazamientoY: 0,
  escala: 1,
  rotacion: 0,
  mostrarCuadricula: false,
})
let intervaloActualizacion = null
let consultaEnCurso = false
let componenteActivo = true
let consultaActiva = null

const configurado = computed(() => Boolean(configuracion.value))

const formatearHora = () =>
  new Date().toLocaleTimeString('es-ES', {
    hour: '2-digit',
    minute: '2-digit',
    second: '2-digit',
  })

async function consultarBackend({ silenciosa = false } = {}) {
  if (!componenteActivo) return

  // Las consultas automáticas no cambian el indicador visible de carga.
  if (consultaEnCurso) {
    if (!silenciosa) cargando.value = true
    return
  }

  consultaEnCurso = true
  const controller = new AbortController()
  consultaActiva = controller
  if (!silenciosa) cargando.value = true
  error.value = ''

  try {
    const health = await backendService.healthCheck({ signal: controller.signal })
    if (!componenteActivo || controller.signal.aborted) return

    conectado.value = health?.estado === 'activo'
    const estadoActual = await backendService.getEstado({ signal: controller.signal })
    if (!componenteActivo || controller.signal.aborted) return

    if (estadoActual?.configuracion) {
      configuracion.value = estadoActual.configuracion
      estado.value = estadoActual.estado || 'lista'
    } else {
      configuracion.value = null
      estado.value = estadoActual?.estado || 'sin_configurar'
    }

    ultimaActualizacion.value = formatearHora()
  } catch (err) {
    if (!componenteActivo || controller.signal.aborted) return

    conectado.value = false
    error.value = err instanceof Error ? err.message : 'No se pudo comunicar con FastAPI.'
  } finally {
    if (consultaActiva === controller) {
      consultaActiva = null
    }
    consultaEnCurso = false
    if (componenteActivo) {
      cargando.value = false
    }
  }
}

async function activarModoProyector() {
  modoProyector.value = true

  const elemento = contenedorApp.value
  if (!elemento || typeof elemento.requestFullscreen !== 'function') {
    pantallaCompleta.value = false
    return
  }

  try {
    await elemento.requestFullscreen()
    pantallaCompleta.value = document.fullscreenElement === elemento
  } catch {
    // El modo proyector sigue disponible aunque el navegador rechace fullscreen.
    pantallaCompleta.value = false
  }
}

function salirModoProyector() {
  modoProyector.value = false
  const salirDePantallaCompleta = document.fullscreenElement === contenedorApp.value
  pantallaCompleta.value = false

  if (salirDePantallaCompleta && typeof document.exitFullscreen === 'function') {
    document.exitFullscreen().catch(() => {})
  }
}

function sincronizarPantallaCompleta() {
  pantallaCompleta.value = document.fullscreenElement === contenedorApp.value

  // Escape u otra salida del modo fullscreen también devuelve la interfaz al modo control.
  if (modoProyector.value && !pantallaCompleta.value) {
    modoProyector.value = false
  }
}

function manejarTecla(evento) {
  if (evento.key === 'Escape' && modoProyector.value) {
    salirModoProyector()
  }
}

function restablecerCalibracion() {
  calibracion.value = {
    superficie: 'caja',
    orientacion: 'horizontal',
    ancho: 21.6,
    alto: 21.6,
    desplazamientoX: 0,
    desplazamientoY: 0,
    escala: 1,
    rotacion: 0,
    mostrarCuadricula: false,
  }
}

onMounted(() => {
  document.addEventListener('fullscreenchange', sincronizarPantallaCompleta)
  document.addEventListener('keydown', manejarTecla)
  consultarBackend()
  intervaloActualizacion = window.setInterval(() => consultarBackend({ silenciosa: true }), 2000)
})

onUnmounted(() => {
  componenteActivo = false
  document.removeEventListener('fullscreenchange', sincronizarPantallaCompleta)
  document.removeEventListener('keydown', manejarTecla)

  if (intervaloActualizacion !== null) {
    window.clearInterval(intervaloActualizacion)
    intervaloActualizacion = null
  }

  consultaActiva?.abort()
})
</script>

<template>
  <div ref="contenedorApp" class="app-shell" :class="{ 'projector-mode': modoProyector }">
    <header class="topbar">
      <div>
        <p class="eyebrow">AR Sandbox</p>
        <h1>Visualización 3D</h1>
      </div>
      <div class="topbar-actions">
        <button class="projector-button" @click="activarModoProyector">Modo proyector</button>
        <button class="refresh-button" @click="consultarBackend" :disabled="cargando">
          {{ cargando ? 'Consultando...' : 'Actualizar' }}
        </button>
      </div>
    </header>

    <button
      v-if="modoProyector"
      class="projector-exit-button"
      type="button"
      :aria-pressed="pantallaCompleta"
      @click="salirModoProyector"
    >
      {{ pantallaCompleta ? 'Salir de pantalla completa' : 'Volver al modo control' }}
    </button>

    <main class="layout-grid">
      <section class="viewer-zone">
        <VisorTerreno
          :terreno="configuracion?.terreno || 'montanas'"
          :color="configuracion?.color || 'Verde bosque'"
          :altura="Number(configuracion?.altura ?? 0)"
          :estado="estado"
          :configurado="configurado"
          :calibracion="calibracion"
        />
      </section>

      <aside class="side-panel">
        <PanelCalibracion
          v-model="calibracion"
          @restablecer="restablecerCalibracion"
        />

        <PanelInformacion
          :configuracion="configuracion"
          :estado="estado"
          :cargando="cargando"
          :conectado="conectado"
          :error="error"
          @actualizar="consultarBackend"
        />

        <EstadoConexion
          :conectado="conectado"
          :cargando="cargando"
          :error="error"
          :ultima-actualizacion="ultimaActualizacion"
        />
      </aside>
    </main>
  </div>
</template>
