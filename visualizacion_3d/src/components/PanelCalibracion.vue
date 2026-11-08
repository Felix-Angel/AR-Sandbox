<script setup>
const props = defineProps({
  modelValue: {
    type: Object,
    required: true,
  },
})

const emit = defineEmits(['update:modelValue', 'restablecer'])

function actualizar(campo, valor) {
  emit('update:modelValue', {
    ...props.modelValue,
    [campo]: valor,
  })
}

function actualizarNumero(campo, evento) {
  const valor = Number(evento.target.value)
  if (Number.isFinite(valor)) actualizar(campo, valor)
}
</script>

<template>
  <section class="calibration-panel">
    <div class="panel-header">
      <div class="panel-heading">
        <span class="panel-icon" aria-hidden="true">⌗</span>
        <div>
          <div class="panel-title">Calibración</div>
          <div class="panel-subtitle">Ajusta el relieve a la superficie de proyección.</div>
        </div>
      </div>
    </div>

    <label class="calibration-field">
      <span>Superficie</span>
      <select :value="props.modelValue.superficie" @change="actualizar('superficie', $event.target.value)">
        <option value="caja">Caja rectangular</option>
        <option value="pizarron">Pizarrón</option>
      </select>
    </label>

    <label v-if="props.modelValue.superficie === 'pizarron'" class="calibration-field">
      <span>Orientación del pizarrón</span>
      <select :value="props.modelValue.orientacion" @change="actualizar('orientacion', $event.target.value)">
        <option value="horizontal">Horizontal</option>
        <option value="vertical">Vertical</option>
      </select>
    </label>

    <div class="calibration-fields-row">
      <label class="calibration-field">
        <span>Ancho</span>
        <input
          type="number"
          min="1"
          max="100"
          step="0.5"
          :value="props.modelValue.ancho"
          @input="actualizarNumero('ancho', $event)"
        />
      </label>
      <label class="calibration-field">
        <span>{{ props.modelValue.superficie === 'caja' ? 'Profundidad' : 'Alto' }}</span>
        <input
          type="number"
          min="1"
          max="100"
          step="0.5"
          :value="props.modelValue.alto"
          @input="actualizarNumero('alto', $event)"
        />
      </label>
    </div>

    <label class="calibration-field">
      <span>Desplazamiento horizontal <strong>{{ props.modelValue.desplazamientoX.toFixed(1) }}</strong></span>
      <input
        type="range"
        min="-10"
        max="10"
        step="0.1"
        :value="props.modelValue.desplazamientoX"
        @input="actualizarNumero('desplazamientoX', $event)"
      />
    </label>

    <label class="calibration-field">
      <span>Desplazamiento vertical <strong>{{ props.modelValue.desplazamientoY.toFixed(1) }}</strong></span>
      <input
        type="range"
        min="-10"
        max="10"
        step="0.1"
        :value="props.modelValue.desplazamientoY"
        @input="actualizarNumero('desplazamientoY', $event)"
      />
    </label>

    <label class="calibration-field">
      <span>Escala <strong>{{ props.modelValue.escala.toFixed(2) }}×</strong></span>
      <input
        type="range"
        min="0.1"
        max="3"
        step="0.05"
        :value="props.modelValue.escala"
        @input="actualizarNumero('escala', $event)"
      />
    </label>

    <label class="calibration-field">
      <span>Rotación <strong>{{ props.modelValue.rotacion }}°</strong></span>
      <input
        type="range"
        min="-180"
        max="180"
        step="1"
        :value="props.modelValue.rotacion"
        @input="actualizarNumero('rotacion', $event)"
      />
    </label>

    <div class="calibration-subsection">
      <div class="calibration-subtitle">Área capturada por Kinect</div>
      <p class="calibration-help">Centra y ajusta el recorte para abarcar el interior de la caja.</p>
      <label class="calibration-field">
        <span>Centro horizontal <strong>{{ Math.round(props.modelValue.centroSensorX) }}%</strong></span>
        <input type="range" min="0" max="100" step="1" :value="props.modelValue.centroSensorX" @input="actualizarNumero('centroSensorX', $event)" />
      </label>
      <label class="calibration-field">
        <span>Centro vertical <strong>{{ Math.round(props.modelValue.centroSensorY) }}%</strong></span>
        <input type="range" min="0" max="100" step="1" :value="props.modelValue.centroSensorY" @input="actualizarNumero('centroSensorY', $event)" />
      </label>
      <label class="calibration-field">
        <span>Ancho del recorte <strong>{{ Math.round(props.modelValue.anchoSensor) }}%</strong></span>
        <input type="range" min="10" max="100" step="1" :value="props.modelValue.anchoSensor" @input="actualizarNumero('anchoSensor', $event)" />
      </label>
      <label class="calibration-field">
        <span>Alto del recorte <strong>{{ Math.round(props.modelValue.altoSensor) }}%</strong></span>
        <input type="range" min="10" max="100" step="1" :value="props.modelValue.altoSensor" @input="actualizarNumero('altoSensor', $event)" />
      </label>
    </div>

    <label class="calibration-checkbox">
      <input
        type="checkbox"
        :checked="props.modelValue.mostrarCuadricula"
        @change="actualizar('mostrarCuadricula', $event.target.checked)"
      />
      <span>Mostrar cuadrícula de calibración</span>
    </label>

    <label class="calibration-checkbox">
      <input
        type="checkbox"
        :checked="props.modelValue.mostrarMalla"
        @change="actualizar('mostrarMalla', $event.target.checked)"
      />
      <span>Mostrar malla sobre el relieve</span>
    </label>

    <button class="calibration-reset-button" type="button" @click="emit('restablecer')">
      <span aria-hidden="true">↺</span> Restablecer calibración
    </button>
  </section>
</template>
