<script setup>
import { computed } from 'vue'
import { validarConfiguracionFisica } from '../services/configuracionFisica.js'

const props = defineProps({
  modelValue: {
    type: Object,
    required: true,
  },
  guardada: {
    type: Boolean,
    default: false,
  },
})

const emit = defineEmits(['update:modelValue', 'guardar'])
const puedeGuardar = computed(() => validarConfiguracionFisica(props.modelValue))

function leerNumero(evento) {
  const valor = evento.target.value
  return valor === '' ? null : Number(valor)
}

function actualizarCaja(campo, evento) {
  emit('update:modelValue', {
    ...props.modelValue,
    caja: { ...props.modelValue.caja, [campo]: leerNumero(evento) },
  })
}

function actualizarMontaje(dispositivo, campo, evento) {
  emit('update:modelValue', {
    ...props.modelValue,
    [dispositivo]: {
      ...props.modelValue[dispositivo],
      [campo]: leerNumero(evento),
    },
  })
}
</script>

<template>
  <section class="calibration-panel physical-setup-panel">
    <div class="panel-header">
      <div class="panel-heading">
        <span class="panel-icon" aria-hidden="true">⌂</span>
        <div>
          <div class="panel-title">Instalación física</div>
          <div class="panel-subtitle">Dimensiones de caja y posición de los equipos.</div>
        </div>
      </div>
    </div>

    <p class="physical-setup-note">
      Medidas iniciales editables. Las posiciones se anotan respecto al centro de la caja;
      todavía no mueven ni calibran el sensor o el proyector.
    </p>

    <div class="physical-section-title">Caja · centímetros</div>
    <div class="calibration-fields-row">
      <label class="calibration-field">
        <span>Ancho interior</span>
        <input
          type="number" min="10" max="500" step="1"
          :value="props.modelValue.caja.anchoCm"
          @input="actualizarCaja('anchoCm', $event)"
        />
      </label>
      <label class="calibration-field">
        <span>Profundidad interior</span>
        <input
          type="number" min="10" max="500" step="1"
          :value="props.modelValue.caja.profundidadCm"
          @input="actualizarCaja('profundidadCm', $event)"
        />
      </label>
    </div>

    <div
      v-for="dispositivo in ['kinect', 'proyector']"
      :key="dispositivo"
      class="physical-device-section"
    >
      <div class="physical-section-title">
        {{ dispositivo === 'kinect' ? 'Kinect Xbox 360' : 'Proyector' }} · montaje
      </div>
      <div class="calibration-fields-row">
        <label class="calibration-field">
          <span>Desplazamiento X (cm)</span>
          <input
            type="number" step="1" min="-500" max="500"
            :value="props.modelValue[dispositivo].desplazamientoXCm"
            @input="actualizarMontaje(dispositivo, 'desplazamientoXCm', $event)"
          />
        </label>
        <label class="calibration-field">
          <span>Desplazamiento Z (cm)</span>
          <input
            type="number" step="1" min="-500" max="500"
            :value="props.modelValue[dispositivo].desplazamientoZCm"
            @input="actualizarMontaje(dispositivo, 'desplazamientoZCm', $event)"
          />
        </label>
      </div>
      <label class="calibration-field">
        <span>Altura sobre el borde (cm)</span>
        <input
          type="number" step="1" min="1" max="1000"
          placeholder="Pendiente de medir"
          :value="props.modelValue[dispositivo].alturaCm ?? ''"
          @input="actualizarMontaje(dispositivo, 'alturaCm', $event)"
        />
      </label>
      <div class="calibration-fields-row">
        <label class="calibration-field">
          <span>Inclinación (°)</span>
          <input
            type="number" step="1" min="-180" max="180"
            :value="props.modelValue[dispositivo].inclinacionGrados"
            @input="actualizarMontaje(dispositivo, 'inclinacionGrados', $event)"
          />
        </label>
        <label class="calibration-field">
          <span>Giro horizontal (°)</span>
          <input
            type="number" step="1" min="-180" max="180"
            :value="props.modelValue[dispositivo].giroGrados"
            @input="actualizarMontaje(dispositivo, 'giroGrados', $event)"
          />
        </label>
      </div>
    </div>

    <button
      class="calibration-reset-button physical-save-button"
      type="button"
      :disabled="!puedeGuardar"
      @click="emit('guardar')"
    >
      {{ props.guardada ? 'Configuración guardada' : 'Guardar instalación' }}
    </button>
    <p class="physical-setup-footnote">
      Se guarda en este navegador y se conserva al recargar la página.
    </p>
  </section>
</template>
