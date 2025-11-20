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

