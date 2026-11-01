import * as THREE from 'three'

const PALETA_COLORES = {
  'Verde bosque': '#2e7d32',
  Terracota: '#c9653b',
  Crema: '#f3d9a3',
  Tinta: '#2d3748',
  'Maíz': '#f4c95d',
  Turquesa: '#2aa4a4',
  Bugambilia: '#8e5ea2',
  Café: '#7a4a2f',
  Gris: '#7d8797',
}

function normalizarAltura(altura) {
  const valor = Number.isFinite(altura) ? altura : 50
  return Math.min(100, Math.max(0, valor))
}

function mapColor(color) {
  return PALETA_COLORES[color] || '#8ecae6'
}

function ruidoBase(x, z) {
  return Math.sin(x * 1.7 + z * 0.9) * 0.6 + Math.cos(z * 1.2 - x * 0.7) * 0.5
}

function calcularAlturaTerreno({ terreno, altura, x, z }) {
  const nivel = normalizarAltura(altura) / 100
  const radio = Math.sqrt(x * x + z * z)

  switch (terreno) {
    case 'montanas': {
      const ondulacion = Math.sin(x * 2.4) + Math.cos(z * 2.8) + Math.sin((x + z) * 1.9)
      return (0.8 + ondulacion * 0.8) * (1.8 + nivel * 6)
    }
    case 'valles': {
      const depresion = Math.cos(x * 1.4) * Math.sin(z * 1.7)
      const laterales = Math.exp(-((x * x) / 18 + (z * z) / 18))
      return (0.7 + depresion * 0.8 + laterales * 1.8) * (1.2 + nivel * 4.2) - (1.4 + nivel * 1.6)
    }
    case 'volcanes': {
      const conica = 1 - Math.min(1, radio / 8)
      const crater = Math.exp(-((x * x + z * z) / 2.2))
      return (0.9 + conica * 4.2 + crater * 1.1) * (0.8 + nivel * 4.5) - 1.5
    }
    case 'llanuras':
    default: {
      const leve = Math.sin(x * 2.5) * 0.7 + Math.cos(z * 2.1) * 0.6 + ruidoBase(x, z)
      return (0.25 + leve * 0.35) * (1 + nivel * 2.2)
    }
  }
}

export function crearTerreno({ terreno = 'montanas', color = 'Verde bosque', altura = 50 }) {
  const ancho = 16
  const profundidad = 16
  const segmentos = 80

  const geometria = new THREE.PlaneGeometry(ancho, profundidad, segmentos, segmentos)
  geometria.rotateX(-Math.PI / 2)

  const vertices = geometria.attributes.position
  const nivelBase = normalizarAltura(altura)

  for (let i = 0; i < vertices.count; i += 1) {
    const x = vertices.getX(i)
    const z = vertices.getY(i)
    const y = calcularAlturaTerreno({ terreno, altura: nivelBase, x, z })
    vertices.setY(i, y)
  }

  geometria.computeVertexNormals()

  const material = new THREE.MeshStandardMaterial({
    color: mapColor(color),
    roughness: 0.9,
    metalness: 0.08,
  })

  const terrenoMesh = new THREE.Mesh(geometria, material)
  terrenoMesh.castShadow = true
  terrenoMesh.receiveShadow = true

  const base = new THREE.Mesh(
    new THREE.CylinderGeometry(9.5, 10.8, 2.8, 32),
    new THREE.MeshStandardMaterial({
      color: '#1d2a39',
      roughness: 0.9,
      metalness: 0.15,
    }),
  )
  base.position.y = -2.2
  base.receiveShadow = true

  const grupo = new THREE.Group()
  grupo.add(terrenoMesh)
  grupo.add(base)

  return grupo
}
