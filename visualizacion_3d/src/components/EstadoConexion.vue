<script setup>
const props = defineProps({
  conectado: {
    type: Boolean,
    default: false,
  },
  cargando: {
    type: Boolean,
    default: false,
  },
  error: {
    type: String,
    default: '',
  },
  ultimaActualizacion: {
    type: String,
    default: 'Sin datos',
  },
  sensor: {
    type: Object,
    default: () => ({ estado: 'desconectado', conectado: false, capturando: false }),
  },
})
</script>

<template>
  <div class="status-panel">
    <div class="panel-heading">
      <span class="panel-icon" aria-hidden="true">⌁</span>
      <div>
        <div class="panel-title">Estado de conexión</div>
        <div class="panel-subtitle">Seguimiento del servicio FastAPI</div>
      </div>
    </div>
    <div class="status-row">
      <span class="status-label">Servidor</span>
      <span :class="['badge', props.conectado ? 'success' : 'danger']" aria-live="polite">
        {{ props.conectado ? 'Conectado' : 'Desconectado' }}
      </span>
    </div>
    <div class="status-row">
      <span class="status-label">Consulta</span>
      <span :class="['badge', props.cargando ? 'warning' : 'neutral']">
        {{ props.cargando ? 'Consultando...' : 'En espera' }}
      </span>
    </div>
    <div class="status-row">
      <span class="status-label">Kinect Xbox 360</span>
      <span :class="['badge', props.sensor.capturando ? 'success' : props.sensor.conectado ? 'warning' : 'danger']" aria-live="polite">
        {{ props.sensor.capturando ? 'Capturando' : props.sensor.conectado ? 'Conectado · sin datos' : 'Desconectado' }}
      </span>
    </div>
    <div v-if="props.sensor.ancho && props.sensor.alto" class="status-row">
      <span class="status-label">Profundidad</span>
      <span class="status-value">
        {{ props.sensor.ancho }} × {{ props.sensor.alto }} · {{ Number(props.sensor.fps || 0).toFixed(1) }} FPS
      </span>
    </div>
    <div class="status-row">
      <span class="status-label">Última actualización</span>
      <span class="status-value">{{ props.ultimaActualizacion }}</span>
    </div>
    <p v-if="props.error" class="error-text">{{ props.error }}</p>
  </div>
</template>
