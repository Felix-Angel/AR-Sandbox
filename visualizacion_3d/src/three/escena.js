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
  const materialSensor = new THREE.MeshStandardMaterial({
    vertexColors: true,
    roughness: 0.94,
    metalness: 0,
    side: THREE.DoubleSide,
  })
  const sensorMesh = new THREE.Mesh(new THREE.BufferGeometry(), materialSensor)
  sensorMesh.visible = false
  sensorMesh.castShadow = false
  sensorMesh.receiveShadow = true
  terrainGroup.add(sensorMesh)
  const coloresAltura = [
    { posicion: 0, color: new THREE.Color('#2678c5') },
    { posicion: 0.24, color: new THREE.Color('#35a66f') },
    { posicion: 0.5, color: new THREE.Color('#e5d45d') },
    { posicion: 0.76, color: new THREE.Color('#d87943') },
    { posicion: 1, color: new THREE.Color('#f4eee0') },
  ]
  const colorAlturaTemporal = new THREE.Color()
  const colorDatoInvalido = new THREE.Color('#111a15')
  const alturaMaximaRelieve = 3.2
  let mapaSensorActivo = false
  let alturasSuavizadas = null
  let claveGeometriaSensor = ''
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
    const geometriaVisible = mapaSensorActivo ? sensorMesh.geometry : terrenoMesh?.geometry
    mallaTerreno.visible = nuevaCalibracion.mostrarMalla && Boolean(geometriaVisible)

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
    if (!sensorMesh.visible && (!terrenoMesh.visible || !terrenoMesh.geometry)) return 24
    const objetoVisible = sensorMesh.visible ? sensorMesh : grupoTerreno
    const limites = new THREE.Box3().setFromObject(objetoVisible)
    const esfera = limites.getBoundingSphere(new THREE.Sphere())
    const fovVertical = THREE.MathUtils.degToRad(camera.fov)
    const fovHorizontal = 2 * Math.atan(Math.tan(fovVertical / 2) * camera.aspect)
    const fovLimitante = Math.min(fovVertical, fovHorizontal)
    const distancia = Math.max(12, (esfera.radius / Math.sin(fovLimitante / 2)) * 1.08)
    controls.maxDistance = Math.max(48, distancia * 1.2)
    return distancia
  }

  const encuadrarTerreno = (restablecer = false) => {
    if (sensorMesh.visible || (terrenoMesh.visible && terrenoMesh.geometry)) {
      const objetoVisible = sensorMesh.visible ? sensorMesh : grupoTerreno
      const limites = new THREE.Box3().setFromObject(objetoVisible)
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
    const cambioVisibilidad = terrenoMesh.visible || baseTerreno.visible || sensorMesh.visible
    const habiaGeometria = Boolean(terrenoMesh.geometry)

    if (terrenoMesh.geometry) {
      terrenoMesh.geometry.dispose()
      terrenoMesh.geometry = null
    }

    terrenoMesh.visible = false
    baseTerreno.visible = false
    sensorMesh.visible = false
    mapaSensorActivo = false
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
      if (!mapaSensorActivo) mallaTerreno.geometry = terrenoMesh.geometry
      geometriaAnterior?.dispose()
    }

    if (cambioColor) {
      terrenoMesh.material.color.set(obtenerColorTerreno(datos.color))
    }

    terrenoMesh.visible = !mapaSensorActivo
    baseTerreno.visible = !mapaSensorActivo
    if (!mapaSensorActivo) mallaTerreno.geometry = terrenoMesh.geometry
    mallaTerreno.visible = Boolean(calibracionAplicada?.mostrarMalla)
    configuracionAplicada = datos

    if (!mapaSensorActivo && !estabaVisible) {
      encuadrarTerreno(true)
    }

    if (cambioGeometria || cambioVisibilidad) {
      renderer.shadowMap.needsUpdate = true
    }
    solicitarRender()
  }

  const colorParaAltura = (alturaNormalizada, destino, offset) => {
    const limite = coloresAltura.length - 1
    const indice = Math.min(limite - 1, Math.floor(alturaNormalizada * limite))
    const inicio = coloresAltura[indice]
    const fin = coloresAltura[indice + 1]
    const tramo = (alturaNormalizada - inicio.posicion) / (fin.posicion - inicio.posicion)
    colorAlturaTemporal.lerpColors(inicio.color, fin.color, THREE.MathUtils.clamp(tramo, 0, 1))
    destino[offset] = colorAlturaTemporal.r
    destino[offset + 1] = colorAlturaTemporal.g
    destino[offset + 2] = colorAlturaTemporal.b
  }

  const actualizarMapaProfundidad = (fotograma, dimensionesCaja = {}, calibracionSensor = {}) => {
    if (!fotograma) {
      const habiaMapaSensor = mapaSensorActivo || sensorMesh.visible
      mapaSensorActivo = false
      sensorMesh.visible = false
      terrenoMesh.visible = Boolean(configuracionAplicada && terrenoMesh.geometry)
      baseTerreno.visible = Boolean(configuracionAplicada)
      if (terrenoMesh.geometry) mallaTerreno.geometry = terrenoMesh.geometry
      mallaTerreno.visible = Boolean(calibracionAplicada?.mostrarMalla && terrenoMesh.geometry)
      if (habiaMapaSensor) {
        renderer.shadowMap.needsUpdate = true
        encuadrarTerreno(false)
      }
      solicitarRender()
      return
    }

    if (!(fotograma.buffer instanceof ArrayBuffer)
      || !Number.isInteger(fotograma.width) || !Number.isInteger(fotograma.height)) return

    const factorMuestreo = Math.min(1, 160 / fotograma.width, 120 / fotograma.height)
    const columnas = Math.max(2, Math.round(fotograma.width * factorMuestreo))
    const filas = Math.max(2, Math.round(fotograma.height * factorMuestreo))
    const anchoCm = Math.min(500, Math.max(10, Number(dimensionesCaja.anchoCm) || 80))
    const profundidadCm = Math.min(500, Math.max(10, Number(dimensionesCaja.profundidadCm) || 80))
    const centroX = THREE.MathUtils.clamp(Number(calibracionSensor.centroSensorX ?? 50), 0, 100) / 100
    const centroY = THREE.MathUtils.clamp(Number(calibracionSensor.centroSensorY ?? 50), 0, 100) / 100
    const anchoSensor = THREE.MathUtils.clamp(Number(calibracionSensor.anchoSensor ?? 100), 10, 100) / 100
    const altoSensor = THREE.MathUtils.clamp(Number(calibracionSensor.altoSensor ?? 100), 10, 100) / 100
    const inicioX = THREE.MathUtils.clamp(centroX - anchoSensor / 2, 0, 1 - anchoSensor)
    const inicioY = THREE.MathUtils.clamp(centroY - altoSensor / 2, 0, 1 - altoSensor)
    const anchoEscena = anchoCm / 5
    const profundidadEscena = profundidadCm / 5
    const nuevaClave = `${columnas}x${filas}:${anchoEscena}x${profundidadEscena}:${inicioX}:${inicioY}:${anchoSensor}:${altoSensor}`

    if (nuevaClave !== claveGeometriaSensor) {
      const geometriaAnterior = sensorMesh.geometry
      const geometria = new THREE.PlaneGeometry(
        anchoEscena,
        profundidadEscena,
        columnas - 1,
        filas - 1,
      )
      geometria.rotateX(-Math.PI / 2)
      geometria.setAttribute('color', new THREE.BufferAttribute(new Float32Array(columnas * filas * 3), 3))
      sensorMesh.geometry = geometria
      mallaTerreno.geometry = geometria
      if (geometriaAnterior && geometriaAnterior !== terrenoMesh.geometry) geometriaAnterior.dispose()
      alturasSuavizadas = new Float32Array(columnas * filas)
      claveGeometriaSensor = nuevaClave
    }

    const vistaDatos = new DataView(fotograma.buffer)
    const profundidades = new Uint16Array(columnas * filas)
    const muestrasValidas = []
    for (let fila = 0; fila < filas; fila += 1) {
      const origenY = Math.min(
        fotograma.height - 1,
        Math.round((inicioY + (fila / (filas - 1)) * altoSensor) * (fotograma.height - 1)),
      )
      for (let columna = 0; columna < columnas; columna += 1) {
        const origenX = Math.min(
          fotograma.width - 1,
          Math.round((inicioX + (columna / (columnas - 1)) * anchoSensor) * (fotograma.width - 1)),
        )
        const indiceOrigen = origenY * fotograma.width + origenX
        const profundidad = vistaDatos.getUint16(fotograma.payloadOffset + indiceOrigen * 2, true)
        const indice = fila * columnas + columna
        profundidades[indice] = profundidad
        if (profundidad > 0) muestrasValidas.push(profundidad)
      }
    }

    const posiciones = sensorMesh.geometry.attributes.position
    const colores = sensorMesh.geometry.attributes.color.array
    if (muestrasValidas.length === 0) return

    muestrasValidas.sort((a, b) => a - b)
    const limiteInferior = muestrasValidas[Math.floor((muestrasValidas.length - 1) * 0.05)]
    const limiteSuperior = muestrasValidas[Math.floor((muestrasValidas.length - 1) * 0.95)]
    const rangoProfundidad = Math.max(100, limiteSuperior - limiteInferior)
    const rangoEfectivo = limiteInferior + rangoProfundidad
    const posicionesArray = posiciones.array

    for (let indice = 0; indice < profundidades.length; indice += 1) {
      const profundidad = profundidades[indice]
      const indiceVertice = indice * 3
      if (profundidad === 0) {
        posicionesArray[indiceVertice + 1] = 0
        colorDatoInvalido.toArray(colores, indiceVertice)
        continue
      }

      const alturaNormalizada = THREE.MathUtils.clamp(
        (rangoEfectivo - profundidad) / rangoProfundidad,
        0,
        1,
      )
      const alturaObjetivo = alturaNormalizada * alturaMaximaRelieve
      const alturaSuavizada = alturasSuavizadas[indice] * 0.28 + alturaObjetivo * 0.72
      alturasSuavizadas[indice] = alturaSuavizada
      posicionesArray[indiceVertice + 1] = alturaSuavizada
      colorParaAltura(alturaSuavizada / alturaMaximaRelieve, colores, indiceVertice)
    }

    posiciones.needsUpdate = true
    sensorMesh.geometry.attributes.color.needsUpdate = true
    sensorMesh.geometry.computeVertexNormals()
    sensorMesh.geometry.computeBoundingSphere()

    const primerFotograma = !sensorMesh.visible
    mapaSensorActivo = true
    sensorMesh.visible = true
    terrenoMesh.visible = false
    baseTerreno.visible = false
    mallaTerreno.geometry = sensorMesh.geometry
    mallaTerreno.visible = Boolean(calibracionAplicada?.mostrarMalla)
    if (primerFotograma) encuadrarTerreno(true)
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
    actualizarMapaProfundidad,
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
      const geometriaSensor = sensorMesh.geometry
      terrainGroup.clear()
      if (geometriaMalla && geometriaMalla !== terrenoMesh.geometry) {
        geometriaMalla.dispose()
      }
      if (geometriaSensor && geometriaSensor !== geometriaMalla && geometriaSensor !== terrenoMesh.geometry) {
        geometriaSensor.dispose()
      }
      materialSensor.dispose()
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
