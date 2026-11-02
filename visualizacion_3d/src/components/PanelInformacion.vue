<script setup>
const props = defineProps({
  configuracion: {
    type: Object,
    default: null,
  },
  estado: {
    type: String,
    default: 'sin_configurar',
  },
  cargando: {
    type: Boolean,
    default: false,
  },
  conectado: {
    type: Boolean,
    default: false,
  },
  error: {
    type: String,
    default: '',
  },
})

const emit = defineEmits(['actualizar'])
</script>

<template>
  <aside class="info-panel">
    <div class="panel-header">
      <div class="panel-heading">
        <span class="panel-icon" aria-hidden="true">⌁</span>
        <div>
          <div class="panel-title">Controles del terreno</div>
          <div class="panel-subtitle">Configuración recibida desde FastAPI</div>
        </div>
      </div>
      <button class="update-button" type="button" @click="emit('actualizar')" :disabled="props.cargando">
        <span aria-hidden="true">↻</span>
        {{ props.cargando ? 'Actualizando...' : 'Actualizar datos' }}
      </button>
    </div>

    <div v-if="props.configuracion" class="metrics-grid">
      <div class="metric-card">
        <span class="label">Terreno</span>
        <strong>{{ props.configuracion.terreno }}</strong>
      </div>
      <div class="metric-card">
        <span class="label">Color</span>
        <strong>{{ props.configuracion.color }}</strong>
      </div>
      <div class="metric-card">
        <span class="label">Altura</span>
        <strong>{{ props.configuracion.altura }}%</strong>
      </div>
      <div class="metric-card">
        <span class="label">Estado</span>
        <strong>{{ props.estado }}</strong>
      </div>
    </div>

    <div v-else class="empty-state">
      <p>Todavía no hay un terreno configurado.</p>
      <p>Selecciona y guarda un terreno desde la aplicación Flutter.</p>
    </div>

    <div v-if="props.error" class="error-box">
      {{ props.error }}
    </div>

    <div class="connection-summary">
      <span class="mini-label">Conexión</span>
      <span :class="['badge', props.conectado ? 'success' : 'danger']" aria-live="polite">
        {{ props.conectado ? 'Conectado' : 'Sin conexión' }}
      </span>
    </div>
  </aside>
</template>
