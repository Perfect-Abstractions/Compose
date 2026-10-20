import * as THREE from 'three';
import { OrbitControls } from 'three/examples/jsm/controls/OrbitControls.js';
import { constellationView, starDepthScale } from './model.mjs';

function glowTexture() {
  const canvas = document.createElement('canvas');
  canvas.width = canvas.height = 64;
  const context = canvas.getContext('2d');
  const gradient = context.createRadialGradient(32, 32, 0, 32, 32, 32);
  for (const [offset, alpha] of [[0, 0.95], [0.12, 0.65], [0.32, 0.25], [0.65, 0.06], [1, 0]]) {
    gradient.addColorStop(offset, `rgba(255,255,255,${alpha})`);
  }
  context.fillStyle = gradient;
  context.fillRect(0, 0, 64, 64);
  const texture = new THREE.CanvasTexture(canvas);
  texture.generateMipmaps = false;
  texture.minFilter = texture.magFilter = THREE.LinearFilter;
  return texture;
}

/** Own the renderer lifecycle independently of the docs page and its controls. */
export function createLibraryScene(container, data, { onNode, onHover, onError }) {
  const renderer = new THREE.WebGLRenderer({ antialias: true, alpha: true, preserveDrawingBuffer: true });
  renderer.setPixelRatio(Math.min(window.devicePixelRatio, 1.5));
  renderer.domElement.setAttribute('aria-label', 'Compose library 3D graph');
  container.appendChild(renderer.domElement);
  const scene = new THREE.Scene();
  scene.background = new THREE.Color('#080b12');
  const camera = new THREE.PerspectiveCamera(43, 1, 0.1, 250);
  const controls = new OrbitControls(camera, renderer.domElement);
  controls.enableDamping = true;
  controls.minDistance = 5;
  controls.maxDistance = 100;
  controls.maxPolarAngle = Math.PI * 0.85;
  const geometry = new THREE.SphereGeometry(1, 16, 12);
  const hitMaterial = new THREE.MeshBasicMaterial({ transparent: true, opacity: 0, depthWrite: false });
  const meshes = [];
  const stars = [];
  const edges = [];
  const labels = [];
  const texture = glowTexture();
  const disposables = [geometry, hitMaterial, texture];
  const byId = new Map(data.nodes.map((node) => [node.id, node]));
  const backgroundGeometry = new THREE.BufferGeometry();
  const backgroundPositions = [];
  const backgroundColors = [];
  for (let i = 0; i < 750; i++) {
    const z = 1 - 2 * (i + 0.5) / 750;
    const angle = i * 2.399963;
    const radius = 55 + (i % 17) * 2;
    const ring = Math.sqrt(1 - z * z);
    backgroundPositions.push(Math.cos(angle) * ring * radius, Math.sin(angle) * ring * radius, z * radius);
    const intensity = 0.24 + (i % 7) * 0.075;
    backgroundColors.push(intensity * 0.85, intensity * 0.92, intensity);
  }
  backgroundGeometry.setAttribute('position', new THREE.Float32BufferAttribute(backgroundPositions, 3));
  backgroundGeometry.setAttribute('color', new THREE.Float32BufferAttribute(backgroundColors, 3));
  const backgroundMaterial = new THREE.PointsMaterial({ size: 0.075, vertexColors: true, transparent: true, opacity: 0.7, depthWrite: false });
  scene.add(new THREE.Points(backgroundGeometry, backgroundMaterial));
  disposables.push(backgroundGeometry, backgroundMaterial);
  for (const node of data.nodes) {
    const material = new THREE.MeshBasicMaterial({ color: node.color, transparent: true, opacity: node.matches ? 1 : 0.16 });
    const mesh = new THREE.Mesh(geometry, material);
    mesh.position.set(...node.position);
    mesh.scale.setScalar(node.kind === 'group' ? 0.17 : 0.1);
    mesh.userData.node = node;
    scene.add(mesh);
    const hit = new THREE.Mesh(geometry, hitMaterial);
    hit.position.copy(mesh.position);
    hit.scale.setScalar(0.32);
    hit.userData.node = node;
    scene.add(hit);
    meshes.push(hit);
    const glowMaterial = new THREE.SpriteMaterial({ map: texture, color: node.color, transparent: true, blending: THREE.AdditiveBlending, depthWrite: false, depthTest: false, toneMapped: false, opacity: node.matches ? 0.65 : 0.12 });
    const glow = new THREE.Sprite(glowMaterial);
    glow.raycast = () => {};
    scene.add(glow);
    stars.push({ node, mesh, hit, glow });
    disposables.push(material, glowMaterial);
    {
      const label = document.createElement(node.kind === 'group' ? 'button' : 'span');
      label.type = 'button';
      label.textContent = node.name;
      label.title = node.name;
      label.className = `library-graph-label${node.level === 'category' ? ' category' : ''}${node.kind === 'facet' ? ' facet' : ''}`;
      label.style.setProperty('--node-color', node.color);
      label.style.opacity = node.matches ? '1' : '0.35';
      if (node.kind === 'group') label.addEventListener('click', () => onNode(node));
      container.appendChild(label);
      labels.push({ element: label, node, position: new THREE.Vector3(...node.position), offset: node.level === 'category' ? -30 : -23 });
    }
  }
  for (const edge of data.links) {
    const source = byId.get(edge.source), target = byId.get(edge.target);
    const lineGeometry = new THREE.BufferGeometry().setFromPoints([new THREE.Vector3(...source.position), new THREE.Vector3(...target.position)]);
    const material = new THREE.LineBasicMaterial({ color: target.color, transparent: true, opacity: target.matches ? (target.kind === 'facet' ? 0.25 : 0.15) : 0.035 });
    scene.add(new THREE.Line(lineGeometry, material));
    edges.push({ edge, geometry: lineGeometry });
    disposables.push(lineGeometry, material);
  }
  let width = 1, height = 1, frame, down, hovered, selectedId, disposed = false;
  function reset() {
    selectedId = undefined;
    hovered = undefined;
    onHover(undefined);
    const view = constellationView(data.nodes, camera.aspect);
    for (const star of stars) {
      const position = view.positions.get(star.node.id);
      star.mesh.position.set(...position);
      star.hit.position.set(...position);
      star.glow.position.set(...position);
    }
    for (const label of labels) label.position.set(...view.positions.get(label.node.id));
    for (const edge of edges) {
      edge.geometry.setFromPoints([new THREE.Vector3(...view.positions.get(edge.edge.source)), new THREE.Vector3(...view.positions.get(edge.edge.target))]);
      edge.geometry.computeBoundingSphere();
    }
    camera.position.set(...view.camera);
    controls.target.set(...view.target);
    controls.update();
  }
  const resize = new ResizeObserver(() => {
    width = container.clientWidth;
    height = container.clientHeight;
    if (!width || !height) return;
    camera.aspect = width / height;
    camera.updateProjectionMatrix();
    renderer.setSize(width, height);
    reset();
  });
  resize.observe(container);
  const raycaster = new THREE.Raycaster();
  const pointer = new THREE.Vector2();
  function pick(event) {
    const rect = renderer.domElement.getBoundingClientRect();
    pointer.set((event.clientX - rect.left) / rect.width * 2 - 1, -(event.clientY - rect.top) / rect.height * 2 + 1);
    raycaster.setFromCamera(pointer, camera);
    return raycaster.intersectObjects(meshes)[0]?.object.userData.node;
  }
  function move(event) {
    const node = pick(event);
    if (node?.id !== hovered?.id) {
      hovered = node;
      renderer.domElement.style.cursor = node ? 'pointer' : 'grab';
      onHover(node);
    }
  }
  function press(event) { down = [event.clientX, event.clientY]; }
  function release(event) {
    if (!down || Math.hypot(event.clientX - down[0], event.clientY - down[1]) > 5) return;
    const node = pick(event);
    down = null;
    if (node) { selectedId = node.id; onNode(node); }
  }
  function leave() { down = null; hovered = undefined; onHover(undefined); }
  function lost(event) { event.preventDefault(); onError(); }
  renderer.domElement.addEventListener('pointermove', move);
  renderer.domElement.addEventListener('pointerdown', press);
  renderer.domElement.addEventListener('pointerup', release);
  renderer.domElement.addEventListener('pointerleave', leave);
  renderer.domElement.addEventListener('webglcontextlost', lost);
  function animate() {
    if (disposed) return;
    controls.update();
    const referenceDistance = camera.position.distanceTo(controls.target);
    for (const star of stars) {
      const distance = star.mesh.position.distanceTo(camera.position);
      const units = 2 * distance * Math.tan(43 * Math.PI / 360) / height;
      const depth = starDepthScale(distance, referenceDistance);
      const active = star.node.id === hovered?.id || star.node.id === selectedId;
      star.mesh.scale.setScalar(units * depth * (active ? 3.1 : star.node.kind === 'facet' ? 1.65 : 2.1));
      star.mesh.material.opacity = active ? 1 : star.node.matches ? Math.min(1, 0.8 * depth) : 0.16;
      star.hit.scale.setScalar(units * 10);
      star.glow.scale.setScalar(units * depth * (active ? 36 : 24));
      star.glow.material.opacity = active ? 0.95 : star.node.matches ? Math.min(0.85, 0.65 * depth) : 0.12;
    }
    renderer.render(scene, camera);
    const placed = [];
    for (const label of labels) {
      const projected = label.position.clone().project(camera);
      const facet = label.node.kind === 'facet';
      if ((facet && label.node.id !== hovered?.id && label.node.id !== selectedId) || projected.z > 1 || Math.abs(projected.x) > 1 || Math.abs(projected.y) > 1) {
        label.element.style.display = 'none';
        continue;
      }
      label.element.style.display = '';
      const labelWidth = Math.min(label.element.offsetWidth, width - 16);
      const labelHeight = label.element.offsetHeight;
      const x = Math.max(labelWidth / 2 + 8, Math.min(width - labelWidth / 2 - 8, (projected.x + 1) / 2 * width));
      const anchorY = (1 - projected.y) / 2 * height;
      const offset = [label.offset, -23, 16, -42, 35, -61, 54, -80, 73, -100, 94].find((candidate) => {
        const top = anchorY + candidate;
        return top >= 4 && top + labelHeight <= height - 4 && !placed.some((rect) => x + labelWidth / 2 > rect.left && x - labelWidth / 2 < rect.right && top + labelHeight + 2 > rect.top && top < rect.bottom);
      });
      if (offset === undefined) { label.element.style.display = 'none'; continue; }
      label.offset = offset;
      const y = anchorY + offset;
      label.element.style.left = `${x}px`;
      label.element.style.top = `${y}px`;
      placed.push({ left: x - labelWidth / 2 - 3, right: x + labelWidth / 2 + 3, top: y - 2, bottom: y + labelHeight + 2 });
    }
    frame = requestAnimationFrame(animate);
  }
  reset();
  animate();
  return {
    reset,
    select(id) { selectedId = id; },
    dispose() {
      disposed = true;
      cancelAnimationFrame(frame);
      resize.disconnect();
      controls.dispose();
      renderer.domElement.removeEventListener('pointermove', move);
      renderer.domElement.removeEventListener('pointerdown', press);
      renderer.domElement.removeEventListener('pointerup', release);
      renderer.domElement.removeEventListener('pointerleave', leave);
      renderer.domElement.removeEventListener('webglcontextlost', lost);
      disposables.forEach((resource) => resource.dispose());
      labels.forEach((label) => label.element.remove());
      renderer.dispose();
      renderer.domElement.remove();
    },
  };
}
