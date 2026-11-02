import * as THREE from 'three'

export function crearCamara(width, height) {
  const camera = new THREE.PerspectiveCamera(42, width / height, 0.1, 2000)
  camera.position.set(12, 12, 18)
  camera.lookAt(0, 1, 0)

  return camera
}
