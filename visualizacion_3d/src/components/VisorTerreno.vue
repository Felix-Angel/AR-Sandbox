<script setup>
import { onBeforeUnmount, onMounted, ref, watch } from 'vue'
import { crearEscena } from '../three/escena.js'

const props = defineProps({
  terreno: {
    type: String,
    default: 'montanas',
  },
  color: {
    type: String,
    default: 'Verde bosque',
  },
  altura: {
    type: Number,
    default: 50,
  },
  estado: {
    type: String,
    default: 'sin_configurar',
  },
  configurado: {
    type: Boolean,
    default: false,
  },
  fotogramaProfundidad: {
    type: Object,
    default: null,
  },
  sensorCapturando: {
    type: Boolean,
    default: false,
  },
  configuracionFisica: {
    type: Object,
    default: () => ({ caja: { anchoCm: 80, profundidadCm: 80 } }),
  },
  calibracion: {
    type: Object,
    default: () => ({}),
  },
  estadoCamara: {
    type: Object,
    default: null,
  },
})

const emit = defineEmits(['camera-ready', 'camera-change'])

const contenedor = ref(null)
let escena = null
let ultimoEstadoCamaraEmitido = ''
let ultimoEstadoCamaraAplicado = ''

const emitirEstadoCamara = () => {
  if (!escena) return
  const estadoCamara = escena.obtenerEstadoCamara()
  const serializado = JSON.stringify(estadoCamara)
  if (serializado === ultimoEstadoCamaraEmitido) return

  ultimoEstadoCamaraEmitido = serializado
  emit('camera-change', estadoCamara)
}

const actualizarVisualizacion = () => {
  if (!escena) {
    return
  }

  if (props.fotogramaProfundidad) {
    escena.actualizarMapaProfundidad(
      props.fotogramaProfundidad,
      props.configuracionFisica.caja,
      props.calibracion,
    )
    return
  }

  escena.actualizarMapaProfundidad(null)
  if (!props.configurado) {
    escena.limpiarTerreno()
    return
  }

  escena.actualizarTerreno({
    terreno: props.terreno,
    color: props.color,
    altura: props.altura,
  })
}

const restablecerCamara = () => escena?.restablecerCamara()

const sincronizarInteraccionCamara = () => {
  if (escena) {
    escena.controls.enabled = props.estado !== 'detenida'
  }
}

onMounted(() => {
  if (contenedor.value) {
    escena = crearEscena(contenedor.value, {
      terreno: props.terreno,
      color: props.color,
      altura: props.altura,
    })
    sincronizarInteraccionCamara()
    escena.actualizarCalibracion(props.calibracion)
    actualizarVisualizacion()
    escena.controls.addEventListener('change', emitirEstadoCamara)
    emit('camera-ready', escena.obtenerEstadoCamara())
  }
})

watch(
  () => props.estado,
  sincronizarInteraccionCamara,
)

watch(
  () => [
    props.terreno,
    props.color,
    props.altura,
    props.configurado,
    props.fotogramaProfundidad,
    props.configuracionFisica.caja.anchoCm,
    props.configuracionFisica.caja.profundidadCm,
  ],
  () => {
    actualizarVisualizacion()
  },
  { deep: true },
)

watch(
  () => props.calibracion,
  (calibracion) => {
    escena?.actualizarCalibracion(calibracion)
    if (props.fotogramaProfundidad) {
      escena?.actualizarMapaProfundidad(
        props.fotogramaProfundidad,
        props.configuracionFisica.caja,
        calibracion,
      )
    }
  },
  { deep: true },
)

watch(
  () => props.estadoCamara,
  (estadoCamara) => {
    if (!escena || !estadoCamara) return
    const serializado = JSON.stringify(estadoCamara)
    if (serializado === ultimoEstadoCamaraAplicado) return

    if (escena.aplicarEstadoCamara(estadoCamara)) {
      ultimoEstadoCamaraAplicado = serializado
    }
  },
  { deep: true },
)

onBeforeUnmount(() => {
  if (escena) {
    escena.controls.removeEventListener('change', emitirEstadoCamara)
    escena.dispose()
    escena = null
  }
})
</script>

<template>
  <div class="viewer-panel">
    <div class="viewer-header">
      <div class="viewer-title-group">
        <span class="viewer-icon" aria-hidden="true">◈</span>
        <div>
          <div class="viewer-title">Vista del terreno</div>
          <div class="viewer-hint">Arrastra para orbitar · usa la rueda para acercar</div>
        </div>
      </div>
      <span :class="['badge', props.sensorCapturando || (!props.fotogramaProfundidad && props.estado === 'en_ejecucion') ? 'success' : 'neutral']" aria-live="polite">
        {{ props.fotogramaProfundidad ? props.sensorCapturando ? 'Kinect en vivo' : 'Última captura' : props.estado === 'en_ejecucion' ? 'En ejecución' : props.estado || 'Sin configurar' }}
      </span>
      <button
        class="viewer-action"
        type="button"
        :disabled="props.estado === 'detenida'"
        @click="restablecerCamara"
        aria-label="Restablecer encuadre de cámara"
      >
        <span aria-hidden="true">↺</span> Centrar cámara
      </button>
    </div>
    <div ref="contenedor" class="viewer-canvas" role="img" aria-label="Vista interactiva del terreno en tres dimensiones" />
    <div v-if="props.fotogramaProfundidad" class="viewer-empty-message depth-live-message">
      Profundidad recibida · {{ props.fotogramaProfundidad.width }} × {{ props.fotogramaProfundidad.height }} ·
      {{ props.fotogramaProfundidad.minDepthMm }}–{{ props.fotogramaProfundidad.maxDepthMm }} mm
    </div>
    <div v-else-if="!props.configurado" class="viewer-empty-message">
      Actualmente no hay una configuración guardada.
    </div>
  </div>
</template>
