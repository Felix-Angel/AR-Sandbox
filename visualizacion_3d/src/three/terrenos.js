import * as THREE from 'three'

const PALETA_COLORES = {
  'Verde bosque': '#315c45',
  Terracota: '#c66a4a',
  Crema: '#faf7f0',
  Tinta: '#26352d',
  'Maíz': '#e5b94b',
  Turquesa: '#3e9b98',
  Bugambilia: '#b64d73',
  Café: '#7a4a2f',
  Gris: '#7d8797',
}

let texturaTerrenoCompartida = null

function normalizarAltura(altura) {
  const valor = Number.isFinite(altura) ? altura : 50
  return Math.min(100, Math.max(0, valor))
}

export function obtenerColorTerreno(color) {
  return PALETA_COLORES[color] || '#8ecae6'
}

function ruidoBase(x, z) {
  return Math.sin(x * 1.7 + z * 0.9) * 0.6 + Math.cos(z * 1.2 - x * 0.7) * 0.5
}

function crearTexturaTerreno() {
  if (texturaTerrenoCompartida) return texturaTerrenoCompartida

  const canvas = document.createElement('canvas')
  canvas.width = 128
  canvas.height = 128
  const contexto = canvas.getContext('2d', { willReadFrequently: true })
  const imagen = contexto.createImageData(canvas.width, canvas.height)

  for (let y = 0; y < canvas.height; y += 1) {
    for (let x = 0; x < canvas.width; x += 1) {
      const indice = (y * canvas.width + x) * 4
      const grano = Math.sin(x * 0.41 + Math.cos(y * 0.27)) * 8
        + Math.cos(y * 0.36 - Math.sin(x * 0.19)) * 7
      const variacion = (Math.imul(x + 1, 374761393) + Math.imul(y + 1, 668265263)) >>> 0
      const moteado = (variacion % 19) - 9
      const valor = Math.min(255, Math.max(0, 218 + grano + moteado))
      imagen.data[indice] = valor
      imagen.data[indice + 1] = valor
      imagen.data[indice + 2] = valor
      imagen.data[indice + 3] = 255
    }
  }

  contexto.putImageData(imagen, 0, 0)
  texturaTerrenoCompartida = new THREE.CanvasTexture(canvas)
  texturaTerrenoCompartida.colorSpace = THREE.SRGBColorSpace
  texturaTerrenoCompartida.wrapS = THREE.RepeatWrapping
  texturaTerrenoCompartida.wrapT = THREE.RepeatWrapping
  texturaTerrenoCompartida.repeat.set(3, 3)
  texturaTerrenoCompartida.anisotropy = 4
  texturaTerrenoCompartida.needsUpdate = true
  return texturaTerrenoCompartida
}

function campana(x, z, centroX, centroZ, radioX, radioZ = radioX) {
  return Math.exp(-(((x - centroX) ** 2) / radioX + ((z - centroZ) ** 2) / radioZ))
}

function calcularAlturaTerreno({ terreno, altura, x, z }) {
  const nivel = normalizarAltura(altura) / 100
  const radio = Math.sqrt(x * x + z * z)

  switch (terreno) {
    case 'montanas': {
      const picos = campana(x, z, -3.2, -2.1, 8.5)
        + campana(x, z, 1.7, 2.6, 6.5) * 0.82
        + campana(x, z, 4.3, -3.6, 5.2) * 0.58
        + campana(x, z, -0.2, 5.2, 7.2) * 0.66
      const rugosidad = ruidoBase(x, z) * 0.12
      return Math.max(0.12, 0.18 + picos * (2.4 + nivel * 8.2) + rugosidad)
    }
    case 'valles': {
      const ladera = 1 - Math.exp(-((x * x) / 18))
      const ondulacion = Math.sin(z * 0.78 + x * 0.3) * 0.16 + ruidoBase(x, z) * 0.08
      return Math.max(0.05, (0.16 + ladera * 0.8 + ondulacion) * (1.2 + nivel * 5.4))
    }
    case 'volcanes': {
      const conica = Math.max(0, 1 - radio / 8.4) ** 1.35
      const crater = Math.exp(-((radio * radio) / 1.25))
      const bordeCrater = Math.exp(-(((radio - 1.45) ** 2) / 0.32))
      const escala = 1.4 + nivel * 6.4
      return Math.max(0.08, 0.18 + conica * escala - crater * escala * 0.48 + bordeCrater * escala * 0.12)
    }
    case 'llanuras':
    default: {
      const leve = Math.sin(x * 0.85) * 0.16 + Math.cos(z * 0.72) * 0.14 + ruidoBase(x, z) * 0.08
      return Math.max(0.08, (0.28 + leve) * (1 + nivel * 2.6))
    }
  }
}

export function crearGeometriaTerreno({ terreno = 'montanas', altura = 50 }) {
  const ancho = 16
  const profundidad = 16
  const segmentos = 100

  const geometria = new THREE.PlaneGeometry(ancho, profundidad, segmentos, segmentos)
  geometria.rotateX(-Math.PI / 2)

  const vertices = geometria.attributes.position
  const nivelBase = normalizarAltura(altura)

  for (let i = 0; i < vertices.count; i += 1) {
    const x = vertices.getX(i)
    const z = vertices.getZ(i)
    const y = calcularAlturaTerreno({ terreno, altura: nivelBase, x, z })
    vertices.setY(i, y)
  }

  geometria.computeVertexNormals()

  return geometria
}

export function crearTerreno({ terreno = 'montanas', color = 'Verde bosque', altura = 50 }) {
  const geometria = crearGeometriaTerreno({ terreno, altura })

  const material = new THREE.MeshStandardMaterial({
    color: obtenerColorTerreno(color),
    map: crearTexturaTerreno(),
    roughness: 0.96,
    metalness: 0.01,
  })

  const terrenoMesh = new THREE.Mesh(geometria, material)
  terrenoMesh.castShadow = true
  terrenoMesh.receiveShadow = true

  const base = new THREE.Mesh(
    new THREE.CylinderGeometry(9.5, 10.8, 2.8, 32),
    new THREE.MeshStandardMaterial({
      color: '#26352d',
      roughness: 0.9,
      metalness: 0.15,
    }),
  )
  base.position.y = -2.2
  base.receiveShadow = true

  const grupo = new THREE.Group()
  grupo.add(terrenoMesh)
  grupo.add(base)

  const liberarRecursos = () => {
    grupo.removeEventListener('removed', liberarRecursos)

    const geometrias = new Set()
    const materiales = new Set()

    grupo.traverse((objeto) => {
      if (objeto.geometry) {
        geometrias.add(objeto.geometry)
      }

      if (Array.isArray(objeto.material)) {
        objeto.material.forEach((material) => materiales.add(material))
      } else if (objeto.material) {
        materiales.add(objeto.material)
      }
    })

    geometrias.forEach((geometriaAnterior) => geometriaAnterior.dispose())
    materiales.forEach((materialAnterior) => materialAnterior.dispose())
  }

  grupo.addEventListener('removed', liberarRecursos)

  return grupo
}
