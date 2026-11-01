<script setup>
import { computed, onMounted, onUnmounted, ref, shallowRef, watch } from 'vue'
import EstadoConexion from './components/EstadoConexion.vue'
import PanelCalibracion from './components/PanelCalibracion.vue'
import PanelInformacion from './components/PanelInformacion.vue'
import VisorTerreno from './components/VisorTerreno.vue'
import { backendService } from './services/backendService.js'
import { crearCanalProyector } from './services/projectorChannel.js'

const esVentanaProyeccion = new URLSearchParams(window.location.search).get('modo') === 'proyector'

const configuracion = ref(null)
const estado = ref('sin_configurar')
const conectado = ref(false)
const cargando = ref(false)
const error = ref('')
const ultimaActualizacion = ref('Sin datos')
const contenedorApp = ref(null)
const modoProyector = ref(false)
const pantallaCompleta = ref(false)
const canalDisponible = ref(true)
const controlConectado = ref(false)
const proyeccionActiva = ref(false)
const errorAperturaProyeccion = ref('')
const ventanaProyeccion = shallowRef(null)
const estadoCamara = ref(null)
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
let canalProyector = null
let intervaloHeartbeatControl = null
let intervaloAnuncioProyeccion = null
let intervaloVigilanciaControl = null
let intervaloCierreVentana = null
let ultimaActividadControl = 0
let ultimaInstantaneaEnviada = ''
let ultimaCamaraEnviada = ''

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

function crearInstantaneaProyeccion() {
  return {
    configuracion: configuracion.value === null
      ? null
      : JSON.parse(JSON.stringify(configuracion.value)),
    estado: estado.value,
    conectado: conectado.value,
    calibracion: JSON.parse(JSON.stringify(calibracion.value)),
    estadoCamara: estadoCamara.value
      ? JSON.parse(JSON.stringify(estadoCamara.value))
      : null,
  }
}

function enviarInstantaneaProyeccion(forzar = false) {
  if (esVentanaProyeccion || !canalProyector) return

  const instantanea = crearInstantaneaProyeccion()
  const serializada = JSON.stringify(instantanea)
  if (!forzar && serializada === ultimaInstantaneaEnviada) return

  ultimaInstantaneaEnviada = serializada
  canalProyector.enviar('state-snapshot', instantanea)
}

function manejarMensajeProyector(mensaje) {
  if (!esVentanaProyeccion) {
    if (mensaje.origen === 'proyeccion' && mensaje.tipo === 'projection-ready') {
      proyeccionActiva.value = true
      enviarInstantaneaProyeccion(true)
    }
    return
  }

  if (mensaje.origen !== 'control') return

  if (mensaje.tipo === 'control-heartbeat') {
    ultimaActividadControl = Date.now()
    controlConectado.value = true
    return
  }

  if (mensaje.tipo === 'camera-update' && mensaje.datos?.estadoCamara) {
    estadoCamara.value = mensaje.datos.estadoCamara
    ultimaActividadControl = Date.now()
    controlConectado.value = true
    return
  }

  if (mensaje.tipo === 'state-snapshot' && mensaje.datos && typeof mensaje.datos === 'object') {
    const datos = mensaje.datos
    if (!('configuracion' in datos) || typeof datos.estado !== 'string'
      || typeof datos.conectado !== 'boolean' || !datos.calibracion) {
      return
    }

    configuracion.value = datos.configuracion
    estado.value = datos.estado
    conectado.value = datos.conectado
    calibracion.value = datos.calibracion
    if (datos.estadoCamara) {
      estadoCamara.value = datos.estadoCamara
    }
    ultimaActividadControl = Date.now()
    controlConectado.value = true

    if (intervaloAnuncioProyeccion !== null) {
      window.clearInterval(intervaloAnuncioProyeccion)
      intervaloAnuncioProyeccion = null
    }
  }
}

function recibirCamaraInicial(estadoRecibido) {
  if (esVentanaProyeccion || !estadoRecibido) return
  const serializado = JSON.stringify(estadoRecibido)
  estadoCamara.value = JSON.parse(serializado)
  ultimaCamaraEnviada = serializado
  enviarInstantaneaProyeccion(true)
}

function publicarCambioCamara(estadoRecibido) {
  if (esVentanaProyeccion || !estadoRecibido) return
  const serializado = JSON.stringify(estadoRecibido)
  if (serializado === ultimaCamaraEnviada) return

  ultimaCamaraEnviada = serializado
  estadoCamara.value = JSON.parse(serializado)
  canalProyector?.enviar('camera-update', { estadoCamara: estadoCamara.value })
}

function abrirVentanaProyeccion() {
  if (ventanaProyeccion.value && !ventanaProyeccion.value.closed) {
    ventanaProyeccion.value.focus()
    return
  }

  errorAperturaProyeccion.value = ''
  const urlProyeccion = new URL(window.location.href)
  urlProyeccion.searchParams.set('modo', 'proyector')
  const ventana = window.open(
    urlProyeccion.toString(),
    'arSandboxProjection',
    'popup,width=1280,height=800,resizable=yes',
  )

  if (!ventana) {
    errorAperturaProyeccion.value = 'El navegador bloqueó la ventana. Permite ventanas emergentes o usa “Modo proyector” en esta página.'
    proyeccionActiva.value = false
    return
  }

  ventanaProyeccion.value = ventana
  proyeccionActiva.value = true
  if (intervaloCierreVentana !== null) window.clearInterval(intervaloCierreVentana)
  intervaloCierreVentana = window.setInterval(() => {
    if (!ventanaProyeccion.value || ventanaProyeccion.value.closed) {
      window.clearInterval(intervaloCierreVentana)
      intervaloCierreVentana = null
      ventanaProyeccion.value = null
      proyeccionActiva.value = false
    }
  }, 750)
}

function cerrarVentanaProyeccion() {
  if (ventanaProyeccion.value && !ventanaProyeccion.value.closed) {
    ventanaProyeccion.value.close()
  }
}

function iniciarAnuncioProyeccion() {
  if (intervaloAnuncioProyeccion !== null || !canalProyector) return
  const anunciarLista = () => canalProyector?.enviar('projection-ready')
  anunciarLista()
  intervaloAnuncioProyeccion = window.setInterval(anunciarLista, 2000)
}

function iniciarCanalProyector() {
  canalProyector = crearCanalProyector(
    esVentanaProyeccion ? 'proyeccion' : 'control',
    manejarMensajeProyector,
  )

  if (!canalProyector) {
    canalDisponible.value = false
    if (!esVentanaProyeccion) {
      errorAperturaProyeccion.value = 'BroadcastChannel no está disponible. Puedes usar “Modo proyector” en esta página.'
    }
    return
  }

  if (esVentanaProyeccion) {
    iniciarAnuncioProyeccion()
    intervaloVigilanciaControl = window.setInterval(() => {
      if (ultimaActividadControl && Date.now() - ultimaActividadControl > 10000) {
        controlConectado.value = false
        iniciarAnuncioProyeccion()
      }
    }, 2500)
    return
  }

  const enviarLatido = () => canalProyector?.enviar('control-heartbeat')
  enviarLatido()
  intervaloHeartbeatControl = window.setInterval(enviarLatido, 2500)
}

watch(
  [configuracion, estado, conectado, calibracion],
  () => enviarInstantaneaProyeccion(),
  { deep: true },
)

onMounted(() => {
  iniciarCanalProyector()

  if (esVentanaProyeccion) return

  document.addEventListener('fullscreenchange', sincronizarPantallaCompleta)
  document.addEventListener('keydown', manejarTecla)
  consultarBackend()
  intervaloActualizacion = window.setInterval(() => consultarBackend({ silenciosa: true }), 2000)
})

onUnmounted(() => {
  componenteActivo = false
  document.removeEventListener('fullscreenchange', sincronizarPantallaCompleta)
  document.removeEventListener('keydown', manejarTecla)

  for (const intervalo of [
    intervaloHeartbeatControl,
    intervaloAnuncioProyeccion,
    intervaloVigilanciaControl,
    intervaloCierreVentana,
  ]) {
    if (intervalo !== null) window.clearInterval(intervalo)
  }

  if (intervaloActualizacion !== null) {
    window.clearInterval(intervaloActualizacion)
    intervaloActualizacion = null
  }

  consultaActiva?.abort()
  canalProyector?.cerrar()
  canalProyector = null
})
</script>

<template>
  <div
    ref="contenedorApp"
    class="app-shell"
    :class="{
      'projector-mode': !esVentanaProyeccion && modoProyector,
      'standalone-projection': esVentanaProyeccion,
    }"
  >
    <header v-if="!esVentanaProyeccion" class="topbar">
      <div>
        <p class="eyebrow">AR Sandbox</p>
        <h1>Visualización 3D</h1>
      </div>
      <div class="topbar-actions">
        <button
          class="projector-button"
          type="button"
          :disabled="!canalDisponible"
          @click="proyeccionActiva ? cerrarVentanaProyeccion() : abrirVentanaProyeccion()"
        >
          {{ proyeccionActiva ? 'Cerrar ventana de proyección' : 'Abrir ventana de proyección' }}
        </button>
        <button class="projector-button" @click="activarModoProyector">Modo proyector</button>
        <button class="refresh-button" @click="consultarBackend" :disabled="cargando">
          {{ cargando ? 'Consultando...' : 'Actualizar' }}
        </button>
      </div>
    </header>

    <p v-if="errorAperturaProyeccion && !esVentanaProyeccion" class="projection-open-error" role="status">
      {{ errorAperturaProyeccion }}
    </p>

    <button
      v-if="modoProyector && !esVentanaProyeccion"
      class="projector-exit-button"
      type="button"
      :aria-pressed="pantallaCompleta"
      @click="salirModoProyector"
    >
      {{ pantallaCompleta ? 'Salir de pantalla completa' : 'Volver al modo control' }}
    </button>

    <main class="layout-grid" :class="{ 'projection-layout': esVentanaProyeccion }">
      <section class="viewer-zone">
        <VisorTerreno
          :terreno="configuracion?.terreno || 'montanas'"
          :color="configuracion?.color || 'Verde bosque'"
          :altura="Number(configuracion?.altura ?? 0)"
          :estado="estado"
          :configurado="configurado"
          :calibracion="calibracion"
          :estado-camara="esVentanaProyeccion ? estadoCamara : null"
          @camera-ready="recibirCamaraInicial"
          @camera-change="publicarCambioCamara"
        />
      </section>

      <aside v-if="!esVentanaProyeccion" class="side-panel">
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

    <div v-if="esVentanaProyeccion && !controlConectado" class="projection-status" role="status">
      <template v-if="!canalDisponible">
        BroadcastChannel no está disponible. Usa el modo proyector de la ventana de control.
      </template>
      <template v-else-if="configurado">
        Ventana de control desconectada. Se conserva el último terreno recibido.
      </template>
      <template v-else>
        Esperando conexión con la ventana de control…
      </template>
    </div>
  </div>
</template>
