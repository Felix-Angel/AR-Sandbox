<script setup>
import { computed, onMounted, onUnmounted, ref } from 'vue'
import EstadoConexion from './components/EstadoConexion.vue'
import PanelInformacion from './components/PanelInformacion.vue'
import VisorTerreno from './components/VisorTerreno.vue'
import { backendService } from './services/backendService.js'

const configuracion = ref(null)
const estado = ref('sin_configurar')
const conectado = ref(false)
const cargando = ref(false)
const error = ref('')
const ultimaActualizacion = ref('Sin datos')
let intervaloActualizacion = null
let consultaEnCurso = false

const configurado = computed(() => Boolean(configuracion.value))

const formatearHora = () =>
  new Date().toLocaleTimeString('es-ES', {
    hour: '2-digit',
    minute: '2-digit',
    second: '2-digit',
  })

async function consultarBackend({ silenciosa = false } = {}) {
  // Las consultas automáticas no cambian el indicador visible de carga.
  if (consultaEnCurso) {
    if (!silenciosa) cargando.value = true
    return
  }

  consultaEnCurso = true
  if (!silenciosa) cargando.value = true
  error.value = ''

  try {
    const health = await backendService.healthCheck()
    conectado.value = health?.estado === 'activo'
    const estadoActual = await backendService.getEstado()

    if (estadoActual?.configuracion) {
      configuracion.value = estadoActual.configuracion
      estado.value = estadoActual.estado || 'lista'
    } else {
      configuracion.value = null
      estado.value = estadoActual?.estado || 'sin_configurar'
    }

    ultimaActualizacion.value = formatearHora()
  } catch (err) {
    conectado.value = false
    error.value = err instanceof Error ? err.message : 'No se pudo comunicar con FastAPI.'
  } finally {
    consultaEnCurso = false
    cargando.value = false
  }
}

onMounted(() => {
  consultarBackend()
  intervaloActualizacion = window.setInterval(() => consultarBackend({ silenciosa: true }), 2000)
})

onUnmounted(() => {
  if (intervaloActualizacion !== null) {
    window.clearInterval(intervaloActualizacion)
    intervaloActualizacion = null
  }
})
</script>

<template>
  <div class="app-shell">
    <header class="topbar">
      <div>
        <p class="eyebrow">AR Sandbox</p>
        <h1>Visualización 3D</h1>
      </div>
      <button class="refresh-button" @click="consultarBackend" :disabled="cargando">
        {{ cargando ? 'Consultando...' : 'Actualizar' }}
      </button>
    </header>

    <main class="layout-grid">
      <section class="viewer-zone">
        <VisorTerreno
          :terreno="configuracion?.terreno || 'montanas'"
          :color="configuracion?.color || 'Verde bosque'"
          :altura="Number(configuracion?.altura ?? 0)"
          :estado="estado"
          :configurado="configurado"
        />
      </section>

      <aside class="side-panel">
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
