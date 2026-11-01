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

onMounted(() => {
  if (contenedor.value) {
    escena = crearEscena(contenedor.value, {
      terreno: props.terreno,
      color: props.color,
      altura: props.altura,
    })
    escena.actualizarCalibracion(props.calibracion)
    actualizarVisualizacion()
    escena.controls.addEventListener('change', emitirEstadoCamara)
    emit('camera-ready', escena.obtenerEstadoCamara())
  }
})

watch(
  () => [props.terreno, props.color, props.altura, props.configurado],
  () => {
    actualizarVisualizacion()
  },
  { deep: true },
)

watch(
  () => props.calibracion,
  (calibracion) => {
    escena?.actualizarCalibracion(calibracion)
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
      <span>Visor 3D</span>
      <span :class="['badge', props.estado === 'en_ejecucion' ? 'success' : 'neutral']">
        {{ props.estado || 'sin_configurar' }}
      </span>
    </div>
    <div ref="contenedor" class="viewer-canvas" aria-label="Terreno 3D" />
    <div v-if="!props.configurado" class="viewer-empty-message">
      Actualmente no hay una configuración guardada.
    </div>
  </div>
</template>
