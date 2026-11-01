import * as THREE from 'three'
import { OrbitControls } from 'three/examples/jsm/controls/OrbitControls.js'
import { crearCamara } from './camara.js'
import { crearTerreno } from './terrenos.js'

export function crearEscena(contendor, configuracionInicial = {}) {
  const scene = new THREE.Scene()
  scene.background = new THREE.Color('#0b1220')
  scene.fog = new THREE.Fog('#0b1220', 18, 60)

  const camera = crearCamara(contendor.clientWidth, contendor.clientHeight)

  const renderer = new THREE.WebGLRenderer({ antialias: true, alpha: true })
  renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2))
  renderer.setSize(contendor.clientWidth, contendor.clientHeight)
  renderer.shadowMap.enabled = true
  renderer.shadowMap.type = THREE.PCFSoftShadowMap
  contendor.appendChild(renderer.domElement)

  const hemiLight = new THREE.HemisphereLight('#dfe9ff', '#1a2433', 1.25)
  scene.add(hemiLight)

  const dirLight = new THREE.DirectionalLight('#ffffff', 1.4)
  dirLight.position.set(10, 18, 10)
  dirLight.castShadow = true
  dirLight.shadow.mapSize.width = 2048
  dirLight.shadow.mapSize.height = 2048
  scene.add(dirLight)

  const suelo = new THREE.Mesh(
    new THREE.CircleGeometry(18, 80),
    new THREE.MeshStandardMaterial({
      color: '#101a2d',
      roughness: 1,
      metalness: 0,
    }),
  )
  suelo.rotation.x = -Math.PI / 2
  suelo.position.y = -3.2
  suelo.receiveShadow = true
  scene.add(suelo)

  const controls = new OrbitControls(camera, renderer.domElement)
  controls.enableDamping = true
  controls.enablePan = false
  controls.minDistance = 8
  controls.maxDistance = 34
  controls.maxPolarAngle = Math.PI * 0.48
  controls.target.set(0, 2, 0)

  const terrainGroup = new THREE.Group()
  scene.add(terrainGroup)

  const actualizarTerreno = (configuracion) => {
    terrainGroup.clear()

    if (!configuracion || !configuracion.terreno || !configuracion.color || configuracion.altura === undefined || configuracion.altura === null) {
      controls.target.set(0, 2, 0)
      camera.position.set(12, 12, 18)
      camera.lookAt(0, 1, 0)
      return
    }

    const datos = {
      terreno: configuracion.terreno,
      color: configuracion.color,
      altura: Number(configuracion.altura),
    }

    const terreno = crearTerreno(datos)
    terrainGroup.add(terreno)

    const bounds = new THREE.Box3().setFromObject(terreno)
    const center = bounds.getCenter(new THREE.Vector3())
    const size = bounds.getSize(new THREE.Vector3())

    const target = new THREE.Vector3(center.x, center.y + size.y * 0.25, center.z)
    controls.target.copy(target)
    camera.position.set(12, 12, 18)
    camera.lookAt(target)
  }

  const limpiarTerreno = () => {
    terrainGroup.clear()
    controls.target.set(0, 2, 0)
    camera.position.set(12, 12, 18)
    camera.lookAt(0, 1, 0)
  }

  actualizarTerreno(configuracionInicial)

  const resize = () => {
    if (!contendor) return
    camera.aspect = contendor.clientWidth / contendor.clientHeight
    camera.updateProjectionMatrix()
    renderer.setSize(contendor.clientWidth, contendor.clientHeight)
  }

  window.addEventListener('resize', resize)

  let animationFrameId = 0
  const loop = () => {
    controls.update()
    renderer.render(scene, camera)
    animationFrameId = window.requestAnimationFrame(loop)
  }
  loop()

  return {
    scene,
    camera,
    renderer,
    controls,
    actualizarTerreno,
    limpiarTerreno,
    dispose() {
      window.cancelAnimationFrame(animationFrameId)
      window.removeEventListener('resize', resize)
      controls.dispose()
      terrainGroup.clear()
      renderer.dispose()
      contendor.removeChild(renderer.domElement)
    },
  }
}
