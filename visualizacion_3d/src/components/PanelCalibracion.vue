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
