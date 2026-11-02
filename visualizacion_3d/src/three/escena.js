import * as THREE from 'three'
import { OrbitControls } from 'three/examples/jsm/controls/OrbitControls.js'
import { crearCamara } from './camara.js'
import { crearGeometriaTerreno, crearTerreno, obtenerColorTerreno } from './terrenos.js'

export function crearEscena(contendor, configuracionInicial = {}) {
  const scene = new THREE.Scene()
  scene.background = new THREE.Color('#07140f')
  scene.fog = new THREE.Fog('#07140f', 34, 92)

  const anchoInicial = contendor.clientWidth || 1
  const altoInicial = contendor.clientHeight || 1
  const camera = crearCamara(anchoInicial, altoInicial)

  const renderer = new THREE.WebGLRenderer({ antialias: true, alpha: true })
  renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2))
  renderer.setSize(anchoInicial, altoInicial)
  renderer.outputColorSpace = THREE.SRGBColorSpace
  renderer.toneMapping = THREE.ACESFilmicToneMapping
  renderer.toneMappingExposure = 1.12
  renderer.shadowMap.enabled = true
  renderer.shadowMap.type = THREE.PCFSoftShadowMap
  renderer.shadowMap.autoUpdate = false
  renderer.shadowMap.needsUpdate = true
  contendor.appendChild(renderer.domElement)

  const hemiLight = new THREE.HemisphereLight('#f5f0df', '#26392c', 1.45)
  scene.add(hemiLight)

  const dirLight = new THREE.DirectionalLight('#fff3d8', 3.1)
  dirLight.position.set(-9, 19, 11)
  dirLight.castShadow = true
  dirLight.shadow.mapSize.width = 2048
  dirLight.shadow.mapSize.height = 2048
  dirLight.shadow.camera.left = -16
  dirLight.shadow.camera.right = 16
  dirLight.shadow.camera.top = 18
  dirLight.shadow.camera.bottom = -14
  dirLight.shadow.bias = -0.00018
  dirLight.shadow.normalBias = 0.025
  scene.add(dirLight)

  const fillLight = new THREE.DirectionalLight('#9bc9b0', 1.05)
  fillLight.position.set(12, 8, -10)
  scene.add(fillLight)

  const suelo = new THREE.Mesh(
    new THREE.CircleGeometry(18, 80),
    new THREE.MeshStandardMaterial({
      color: '#17251b',
      roughness: 1,
      metalness: 0.02,
    }),
  )
  suelo.rotation.x = -Math.PI / 2
  suelo.position.y = -3.2
  suelo.receiveShadow = true
  scene.add(suelo)

  const controls = new OrbitControls(camera, renderer.domElement)
  controls.enableDamping = true
  controls.dampingFactor = 0.075
  controls.enablePan = false
  controls.rotateSpeed = 0.72
  controls.zoomSpeed = 0.82
  controls.minDistance = 7
  controls.maxDistance = 48
  controls.minPolarAngle = 0.12
  controls.maxPolarAngle = Math.PI * 0.48
  controls.target.set(0, 2, 0)

  let animationFrameId = null
  let disposed = false
  let renderEnCurso = false
  let aplicandoEstadoCamara = false

  const dibujarEscena = () => {
    camera.updateMatrixWorld(true)
    renderer.render(scene, camera)
  }

  const renderFrame = () => {
    animationFrameId = null
    if (disposed) return

    renderEnCurso = true
    try {
      controls.update()
      dibujarEscena()
    } finally {
      renderEnCurso = false
    }
  }

  const solicitarRender = () => {
    if (disposed || animationFrameId !== null) return
    animationFrameId = window.requestAnimationFrame(renderFrame)
  }

  const alCambiarControles = () => {
    // OrbitControls cambia posición y cuaternión; sincroniza su matriz antes de invalidar el render.
    if (!renderEnCurso && !aplicandoEstadoCamara) {
      if (animationFrameId !== null) {
        window.cancelAnimationFrame(animationFrameId)
        animationFrameId = null
      }
      dibujarEscena()
    }
    solicitarRender()
  }
  controls.addEventListener('change', alCambiarControles)

  const terrainGroup = new THREE.Group()
  const surfaceGroup = new THREE.Group()
  const calibrationGroup = new THREE.Group()
  scene.add(surfaceGroup)
  surfaceGroup.add(calibrationGroup)
  calibrationGroup.add(terrainGroup)

  const gridHelper = new THREE.GridHelper(21.6, 18, '#c66a4a', '#9db58c')
  gridHelper.visible = false
  gridHelper.position.y = 0.02
  gridHelper.castShadow = false
  gridHelper.receiveShadow = false
  const gridMaterials = Array.isArray(gridHelper.material) ? gridHelper.material : [gridHelper.material]
  gridMaterials.forEach((material) => {
    material.transparent = true
    material.opacity = 0.58
    material.depthTest = false
    material.toneMapped = false
  })
  gridHelper.renderOrder = 2
  calibrationGroup.add(gridHelper)

  const materialMalla = new THREE.MeshBasicMaterial({
    color: '#e8ead6',
    transparent: true,
    opacity: 0.24,
    wireframe: true,
    depthWrite: false,
    polygonOffset: true,
    polygonOffsetFactor: -1,
    polygonOffsetUnits: -1,
    toneMapped: false,
  })
  materialMalla.side = THREE.DoubleSide
  const mallaTerreno = new THREE.Mesh(new THREE.BufferGeometry(), materialMalla)
  mallaTerreno.visible = false
  mallaTerreno.renderOrder = 1
  mallaTerreno.position.y = 0.012
  terrainGroup.add(mallaTerreno)
  let calibracionAplicada = null

  const actualizarCalibracion = (calibracion = {}) => {
    const ancho = Math.max(1, Number(calibracion.ancho) || 21.6)
    const alto = Math.max(1, Number(calibracion.alto) || 21.6)
    const escala = Math.min(4, Math.max(0.1, Number(calibracion.escala) || 1))
    const desplazamientoX = Number(calibracion.desplazamientoX) || 0
    const desplazamientoY = Number(calibracion.desplazamientoY) || 0
    const rotacion = Number(calibracion.rotacion) || 0
    const pizarronVertical = calibracion.superficie === 'pizarron'
      && calibracion.orientacion === 'vertical'
    const nuevaCalibracion = {
      superficie: calibracion.superficie || 'caja',
      orientacion: pizarronVertical ? 'vertical' : 'horizontal',
      ancho,
      alto,
      desplazamientoX,
      desplazamientoY,
      escala,
      rotacion,
      mostrarCuadricula: Boolean(calibracion.mostrarCuadricula),
      mostrarMalla: Boolean(calibracion.mostrarMalla),
    }
    const cambioTransformacion = !calibracionAplicada
      || nuevaCalibracion.superficie !== calibracionAplicada.superficie
      || nuevaCalibracion.orientacion !== calibracionAplicada.orientacion
      || nuevaCalibracion.ancho !== calibracionAplicada.ancho
      || nuevaCalibracion.alto !== calibracionAplicada.alto
      || nuevaCalibracion.desplazamientoX !== calibracionAplicada.desplazamientoX
      || nuevaCalibracion.desplazamientoY !== calibracionAplicada.desplazamientoY
      || nuevaCalibracion.escala !== calibracionAplicada.escala
      || nuevaCalibracion.rotacion !== calibracionAplicada.rotacion
    const cambioCuadricula = !calibracionAplicada
      || nuevaCalibracion.mostrarCuadricula !== calibracionAplicada.mostrarCuadricula
      || nuevaCalibracion.mostrarMalla !== calibracionAplicada.mostrarMalla

    if (!cambioTransformacion && !cambioCuadricula) return

    surfaceGroup.rotation.x = pizarronVertical ? -Math.PI / 2 : 0
    calibrationGroup.position.set(desplazamientoX, 0, desplazamientoY)
    calibrationGroup.rotation.y = THREE.MathUtils.degToRad(rotacion)
    calibrationGroup.scale.set((ancho / 21.6) * escala, escala, (alto / 21.6) * escala)
    gridHelper.visible = nuevaCalibracion.mostrarCuadricula
    mallaTerreno.visible = nuevaCalibracion.mostrarMalla && Boolean(terrenoMesh?.geometry)

    if (cambioTransformacion) {
      renderer.shadowMap.needsUpdate = true
    }
    calibracionAplicada = nuevaCalibracion
    solicitarRender()
  }

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
  const targetCamara = new THREE.Vector3(0, 2, 0)
  terrainGroup.add(grupoTerreno)

  const calcularDistanciaEncuadre = () => {
    if (!terrenoMesh.visible || !terrenoMesh.geometry) return 24
    const limites = new THREE.Box3().setFromObject(grupoTerreno)
    const esfera = limites.getBoundingSphere(new THREE.Sphere())
    const fovVertical = THREE.MathUtils.degToRad(camera.fov)
    const fovHorizontal = 2 * Math.atan(Math.tan(fovVertical / 2) * camera.aspect)
    const fovLimitante = Math.min(fovVertical, fovHorizontal)
    const distancia = Math.max(12, (esfera.radius / Math.sin(fovLimitante / 2)) * 1.08)
    controls.maxDistance = Math.max(48, distancia * 1.2)
    return distancia
  }

  const encuadrarTerreno = (restablecer = false) => {
    if (terrenoMesh.visible && terrenoMesh.geometry) {
      const limites = new THREE.Box3().setFromObject(grupoTerreno)
      const centro = limites.getCenter(new THREE.Vector3())
      const tamano = limites.getSize(new THREE.Vector3())
      targetCamara.set(centro.x, centro.y + tamano.y * 0.25, centro.z)
    } else {
      targetCamara.set(0, 2, 0)
    }

    let direccion = camera.position.clone().sub(controls.target)
    if (restablecer || direccion.lengthSq() < 0.001) {
      direccion.set(12, 10, 18)
    }
    direccion.normalize()

    const distanciaActual = camera.position.distanceTo(controls.target)
    const distanciaNecesaria = calcularDistanciaEncuadre()
    const distanciaFinal = restablecer
      ? distanciaNecesaria
      : Math.max(distanciaActual, distanciaNecesaria)

    controls.target.copy(targetCamara)
    camera.position.copy(targetCamara).addScaledVector(direccion, distanciaFinal)
    camera.zoom = 1
    camera.lookAt(targetCamara)
    camera.updateProjectionMatrix()
    controls.update()
    solicitarRender()
  }

  if (!datosIniciales) {
    terrenoMesh.geometry.dispose()
    terrenoMesh.geometry = null
    terrenoMesh.visible = false
    baseTerreno.visible = false
  } else {
    mallaTerreno.geometry.dispose()
    mallaTerreno.geometry = terrenoMesh.geometry
    encuadrarTerreno(true)
  }

  let configuracionAplicada = datosIniciales ? datosTerreno : null
  actualizarCalibracion()

  const limpiarTerreno = () => {
    const cambioVisibilidad = terrenoMesh.visible || baseTerreno.visible
    const habiaGeometria = Boolean(terrenoMesh.geometry)

    if (terrenoMesh.geometry) {
      terrenoMesh.geometry.dispose()
      terrenoMesh.geometry = null
    }

    terrenoMesh.visible = false
    baseTerreno.visible = false
    mallaTerreno.visible = false
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

    const estabaVisible = terrenoMesh.visible
    const cambioGeometria = !terrenoMesh.geometry || !configuracionAplicada
      || datos.terreno !== configuracionAplicada.terreno
      || datos.altura !== configuracionAplicada.altura
    const cambioColor = !configuracionAplicada || datos.color !== configuracionAplicada.color
    const cambioVisibilidad = !terrenoMesh.visible || !baseTerreno.visible

    if (!cambioGeometria && !cambioColor && !cambioVisibilidad) return

    if (cambioGeometria) {
      const geometriaAnterior = terrenoMesh.geometry
      terrenoMesh.geometry = crearGeometriaTerreno(datos)
      if (mallaTerreno.geometry !== geometriaAnterior) {
        mallaTerreno.geometry.dispose()
      }
      mallaTerreno.geometry = terrenoMesh.geometry
      geometriaAnterior?.dispose()
    }

    if (cambioColor) {
      terrenoMesh.material.color.set(obtenerColorTerreno(datos.color))
    }

    terrenoMesh.visible = true
    baseTerreno.visible = true
    mallaTerreno.visible = Boolean(calibracionAplicada?.mostrarMalla)
    configuracionAplicada = datos

    if (!estabaVisible) {
      encuadrarTerreno(true)
    }

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
    encuadrarTerreno(false)
    solicitarRender()
  })
  resizeObserver.observe(contendor)

  const obtenerEstadoCamara = () => ({
    posicion: {
      x: camera.position.x,
      y: camera.position.y,
      z: camera.position.z,
    },
    objetivo: {
      x: controls.target.x,
      y: controls.target.y,
      z: controls.target.z,
    },
    orientacion: {
      x: camera.quaternion.x,
      y: camera.quaternion.y,
      z: camera.quaternion.z,
      w: camera.quaternion.w,
    },
    zoom: camera.zoom,
    distancia: camera.position.distanceTo(controls.target),
  })

  const aplicarEstadoCamara = (estadoCamara) => {
    const posicion = estadoCamara?.posicion
    const objetivo = estadoCamara?.objetivo
    const orientacion = estadoCamara?.orientacion
    const componentes = [posicion?.x, posicion?.y, posicion?.z, objetivo?.x, objetivo?.y, objetivo?.z]

    if (!componentes.every(Number.isFinite)) return false

    controls.target.set(objetivo.x, objetivo.y, objetivo.z)
    camera.position.set(posicion.x, posicion.y, posicion.z)

    if (Number.isFinite(estadoCamara.zoom) && estadoCamara.zoom > 0) {
      camera.zoom = estadoCamara.zoom
      camera.updateProjectionMatrix()
    }

    aplicandoEstadoCamara = true
    try {
      controls.update()

      if ([orientacion?.x, orientacion?.y, orientacion?.z, orientacion?.w].every(Number.isFinite)) {
        camera.quaternion.set(orientacion.x, orientacion.y, orientacion.z, orientacion.w).normalize()
        camera.updateMatrixWorld(true)
      }
    } finally {
      aplicandoEstadoCamara = false
    }

    solicitarRender()
    return true
  }

  const restablecerCamara = () => {
    encuadrarTerreno(true)
  }

  solicitarRender()

  return {
    scene,
    camera,
    renderer,
    controls,
    actualizarTerreno,
    actualizarCalibracion,
    obtenerEstadoCamara,
    aplicarEstadoCamara,
    restablecerCamara,
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
      const geometriaMalla = mallaTerreno.geometry
      terrainGroup.clear()
      if (geometriaMalla && geometriaMalla !== terrenoMesh.geometry) {
        geometriaMalla.dispose()
      }
      materialMalla.dispose()
      gridHelper.geometry.dispose()
      if (Array.isArray(gridHelper.material)) {
        gridHelper.material.forEach((material) => material.dispose())
      } else {
        gridHelper.material.dispose()
      }
      renderer.dispose()
      contendor.removeChild(renderer.domElement)
    },
  }
}
