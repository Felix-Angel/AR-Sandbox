import * as THREE from 'three'
import { OrbitControls } from 'three/examples/jsm/controls/OrbitControls.js'
import { crearCamara } from './camara.js'
import { crearGeometriaTerreno, crearTerreno, obtenerColorTerreno } from './terrenos.js'

export function crearEscena(contendor, configuracionInicial = {}) {
  const scene = new THREE.Scene()
  scene.background = new THREE.Color('#0b1220')
  scene.fog = new THREE.Fog('#0b1220', 18, 60)

  const anchoInicial = contendor.clientWidth || 1
  const altoInicial = contendor.clientHeight || 1
  const camera = crearCamara(anchoInicial, altoInicial)

  const renderer = new THREE.WebGLRenderer({ antialias: true, alpha: true })
  renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2))
  renderer.setSize(anchoInicial, altoInicial)
  renderer.shadowMap.enabled = true
  renderer.shadowMap.type = THREE.PCFSoftShadowMap
  renderer.shadowMap.autoUpdate = false
  renderer.shadowMap.needsUpdate = true
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

  let animationFrameId = null
  let disposed = false

  const renderFrame = () => {
    animationFrameId = null
    if (disposed) return

    controls.update()
    renderer.render(scene, camera)
  }

  const solicitarRender = () => {
    if (disposed || animationFrameId !== null) return
    animationFrameId = window.requestAnimationFrame(renderFrame)
  }

  const alCambiarControles = () => solicitarRender()
  controls.addEventListener('change', alCambiarControles)

  const terrainGroup = new THREE.Group()
  scene.add(terrainGroup)

  const normalizarConfiguracion = (configuracion) => {
    if (!configuracion?.terreno || !configuracion?.color || configuracion.altura === undefined || configuracion.altura === null) {
      return null
    }

    const altura = Number(configuracion.altura)
    if (!Number.isFinite(altura)) {
      return null
    }

    return {
      terreno: configuracion.terreno,
      color: configuracion.color,
      altura,
    }
  }

  const datosIniciales = normalizarConfiguracion(configuracionInicial)
  const datosTerreno = datosIniciales || { terreno: 'montanas', color: 'Verde bosque', altura: 50 }
  const grupoTerreno = crearTerreno(datosTerreno)
  const terrenoMesh = grupoTerreno.children[0]
  const baseTerreno = grupoTerreno.children[1]
  terrainGroup.add(grupoTerreno)

  if (!datosIniciales) {
    terrenoMesh.geometry.dispose()
    terrenoMesh.geometry = null
    terrenoMesh.visible = false
    baseTerreno.visible = false
  } else {
    const bounds = new THREE.Box3().setFromObject(grupoTerreno)
    const center = bounds.getCenter(new THREE.Vector3())
    const size = bounds.getSize(new THREE.Vector3())
    const targetInicial = new THREE.Vector3(center.x, center.y + size.y * 0.25, center.z)

    controls.target.copy(targetInicial)
    camera.position.set(12, 12, 18)
    camera.lookAt(targetInicial)
    controls.update()
  }

  let configuracionAplicada = datosIniciales ? datosTerreno : null

  const limpiarTerreno = () => {
    const cambioVisibilidad = terrenoMesh.visible || baseTerreno.visible
    const habiaGeometria = Boolean(terrenoMesh.geometry)

    if (terrenoMesh.geometry) {
      terrenoMesh.geometry.dispose()
      terrenoMesh.geometry = null
    }

    terrenoMesh.visible = false
    baseTerreno.visible = false
    configuracionAplicada = null

    if (cambioVisibilidad || habiaGeometria) {
      renderer.shadowMap.needsUpdate = true
      solicitarRender()
    }
  }

  const actualizarTerreno = (configuracion) => {
    const datos = normalizarConfiguracion(configuracion)

    if (!datos) {
      limpiarTerreno()
      return
    }

    const cambioGeometria = !terrenoMesh.geometry || !configuracionAplicada
      || datos.terreno !== configuracionAplicada.terreno
      || datos.altura !== configuracionAplicada.altura
    const cambioColor = !configuracionAplicada || datos.color !== configuracionAplicada.color
    const cambioVisibilidad = !terrenoMesh.visible || !baseTerreno.visible

    if (!cambioGeometria && !cambioColor && !cambioVisibilidad) return

    if (cambioGeometria) {
      const geometriaAnterior = terrenoMesh.geometry
      terrenoMesh.geometry = crearGeometriaTerreno(datos)
      geometriaAnterior?.dispose()
    }

    if (cambioColor) {
      terrenoMesh.material.color.set(obtenerColorTerreno(datos.color))
    }

    terrenoMesh.visible = true
    baseTerreno.visible = true
    configuracionAplicada = datos

    if (cambioGeometria || cambioVisibilidad) {
      renderer.shadowMap.needsUpdate = true
    }
    solicitarRender()
  }

  let anchoRenderizado = anchoInicial
  let altoRenderizado = altoInicial

  const resizeObserver = new ResizeObserver(() => {
    const ancho = contendor.clientWidth
    const alto = contendor.clientHeight

    if (ancho === 0 || alto === 0) return
    if (ancho === anchoRenderizado && alto === altoRenderizado) return

    anchoRenderizado = ancho
    altoRenderizado = alto
    camera.aspect = ancho / alto
    camera.updateProjectionMatrix()
    renderer.setSize(ancho, alto)
    solicitarRender()
  })
  resizeObserver.observe(contendor)

  solicitarRender()

  return {
    scene,
    camera,
    renderer,
    controls,
    actualizarTerreno,
    limpiarTerreno,
    dispose() {
      disposed = true
      if (animationFrameId !== null) {
        window.cancelAnimationFrame(animationFrameId)
        animationFrameId = null
      }
      controls.removeEventListener('change', alCambiarControles)
      resizeObserver.disconnect()
      controls.dispose()
      terrainGroup.clear()
      renderer.dispose()
      contendor.removeChild(renderer.domElement)
    },
  }
}
