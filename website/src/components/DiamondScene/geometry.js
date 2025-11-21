import * as THREE from 'three';

// GEOMETRY: HIGH-FIDELITY ROUND BRILLIANT CUT
// Constructed procedurally to ensure perfect symmetry and sharp facet edges
export function createDiamondGeometry(radius = 1.5) {
  const geometry = new THREE.BufferGeometry();
  
  const rTable = radius * 0.54;
  const rGirdle = radius;
  const rMidCrown = radius * 0.82;
  const rMidPav = radius * 0.35;
  
  const hCrown = radius * 0.30;
  const hMidCrown = radius * 0.12; 
  const hGirdle = 0;
  const hTip = -radius * 0.75; 
  const hMidPav = -radius * 0.45; 
  
  const vertices = [];
  const indices = [];
  
  const tableVerts = [];
  for (let i = 0; i < 8; i++) {
    const theta = (i / 8) * Math.PI * 2;
    vertices.push(Math.cos(theta) * rTable, hCrown, Math.sin(theta) * rTable);
    tableVerts.push(i);
  }
  
  const midCrownVerts = [];
  const midCrownStart = 8;
  for (let i = 0; i < 8; i++) {
    const theta = ((i + 0.5) / 8) * Math.PI * 2;
    vertices.push(Math.cos(theta) * rMidCrown, hMidCrown, Math.sin(theta) * rMidCrown);
    midCrownVerts.push(midCrownStart + i);
  }
  
  const girdleVerts = [];
  const girdleStart = 16;
  for (let i = 0; i < 16; i++) {
    const theta = (i / 16) * Math.PI * 2;
    vertices.push(Math.cos(theta) * rGirdle, hGirdle, Math.sin(theta) * rGirdle);
    girdleVerts.push(girdleStart + i);
  }
  
  const pavMidVerts = [];
  const pavMidStart = 32;
  for (let i = 0; i < 16; i++) {
    const theta = (i / 16) * Math.PI * 2;
    vertices.push(Math.cos(theta) * (rGirdle * 0.5), hGirdle + (hTip - hGirdle) * 0.5, Math.sin(theta) * (rGirdle * 0.5));
    pavMidVerts.push(pavMidStart + i);
  }

  const tipIdx = 48;
  vertices.push(0, hTip, 0);

  const topCenterIdx = 49;
  vertices.push(0, hCrown, 0);
  
  // Table Fan
  for (let i = 0; i < 8; i++) {
    indices.push(topCenterIdx, tableVerts[i], tableVerts[(i + 1) % 8]);
  }
  
  // Crown
  for (let i = 0; i < 8; i++) {
    const t1 = tableVerts[i];
    const t2 = tableVerts[(i + 1) % 8];
    const m = midCrownVerts[i];
    
    const gLeft = girdleVerts[(i * 2) % 16];
    const gMid = girdleVerts[(i * 2 + 1) % 16];
    const gRight = girdleVerts[(i * 2 + 2) % 16];
    
    const nextI = (i + 1) % 8;
    const prevI = (i + 7) % 8;
    const T_curr = tableVerts[i];
    const T_next = tableVerts[nextI];
    const M_curr = midCrownVerts[i]; 
    const G_curr = girdleVerts[i * 2];     
    const G_mid  = girdleVerts[i * 2 + 1]; 
    const G_next = girdleVerts[(i * 2 + 2) % 16];
    
    indices.push(T_curr, M_curr, T_next); // Star
    indices.push(M_curr, G_curr, G_mid);  // Upper Girdle 1
    indices.push(M_curr, G_mid, G_next);  // Upper Girdle 2
    
    const M_prev = midCrownVerts[prevI];
    indices.push(T_curr, M_prev, G_curr); // Bezel 1
    indices.push(T_curr, G_curr, M_curr); // Bezel 2
  }
  
  // Pavilion
  for (let i = 0; i < 16; i++) {
    const G_curr = girdleVerts[i];
    const G_next = girdleVerts[(i + 1) % 16];
    const P_curr = pavMidVerts[i];
    const P_next = pavMidVerts[(i + 1) % 16];
    
    indices.push(G_curr, P_curr, G_next);
    indices.push(G_next, P_curr, P_next);
    indices.push(P_curr, tipIdx, P_next);
  }
  
  geometry.setAttribute('position', new THREE.Float32BufferAttribute(vertices, 3));
  geometry.setIndex(indices);
  geometry.computeVertexNormals();
  
  return geometry;
}

// Helper to map triangles to logical Facet IDs for interaction
export function addFacetIds(nonIndexedGeometry) {
  const positionAttribute = nonIndexedGeometry.getAttribute('position');
  const vertexCount = positionAttribute.count;
  // nonIndexedGeometry has unique vertices for each triangle, so count is multiple of 3
  
  const facetIds = new Float32Array(vertexCount);
  
  let triIndex = 0;
  
  // MUST MATCH THE ORDER OF INDICES PUSHED IN createDiamondGeometry
  
  // 1. Table: 8 triangles (Fan)
  // ID 1: Table
  for (let i = 0; i < 8; i++) {
    const id = 1; 
    for (let v = 0; v < 3; v++) facetIds[triIndex * 3 + v] = id;
    triIndex++;
  }
  
  // 2. Crown: 8 sections * 5 triangles
  for (let i = 0; i < 8; i++) {
    // Star: 1 triangle
    const starId = 100 + i;
    for (let v = 0; v < 3; v++) facetIds[triIndex * 3 + v] = starId;
    triIndex++;
    
    // Upper Girdle 1: 1 triangle
    const upGirdle1Id = 200 + i * 2;
    for (let v = 0; v < 3; v++) facetIds[triIndex * 3 + v] = upGirdle1Id;
    triIndex++;
    
    // Upper Girdle 2: 1 triangle
    const upGirdle2Id = 200 + i * 2 + 1;
    for (let v = 0; v < 3; v++) facetIds[triIndex * 3 + v] = upGirdle2Id;
    triIndex++;
    
    // Bezel: 2 triangles (Kite) -> Same ID
    const bezelId = 300 + i;
    for (let v = 0; v < 3; v++) facetIds[triIndex * 3 + v] = bezelId;
    triIndex++;
    for (let v = 0; v < 3; v++) facetIds[triIndex * 3 + v] = bezelId;
    triIndex++;
  }
  
  // 3. Pavilion: 16 sections * 3 triangles
  for (let i = 0; i < 16; i++) {
    // Lower Girdle / Upper Pav 1
    const lowGirdle1Id = 400 + i;
    for (let v = 0; v < 3; v++) facetIds[triIndex * 3 + v] = lowGirdle1Id;
    triIndex++;
    
    // Lower Girdle / Upper Pav 2
    const lowGirdle2Id = 500 + i;
    for (let v = 0; v < 3; v++) facetIds[triIndex * 3 + v] = lowGirdle2Id;
    triIndex++;
    
    // Pavilion Main (Tip)
    const pavMainId = 600 + i;
    for (let v = 0; v < 3; v++) facetIds[triIndex * 3 + v] = pavMainId;
    triIndex++;
  }
  
  nonIndexedGeometry.setAttribute('aFacetId', new THREE.BufferAttribute(facetIds, 1));
  return nonIndexedGeometry;
}
