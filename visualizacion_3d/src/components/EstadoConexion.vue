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
})
</script>

<template>
  <div class="status-panel">
    <div class="panel-title">Estado de conexión</div>
    <div class="status-row">
      <span class="status-label">Backend</span>
      <span :class="['badge', props.conectado ? 'success' : 'danger']">
        {{ props.conectado ? 'Conectado' : 'Desconectado' }}
      </span>
    </div>
    <div class="status-row">
      <span class="status-label">Carga</span>
      <span :class="['badge', props.cargando ? 'warning' : 'neutral']">
        {{ props.cargando ? 'Consultando...' : 'Listo' }}
      </span>
    </div>
    <div class="status-row">
      <span class="status-label">Última actualización</span>
      <span class="status-value">{{ props.ultimaActualizacion }}</span>
    </div>
    <p v-if="props.error" class="error-text">{{ props.error }}</p>
  </div>
</template>
