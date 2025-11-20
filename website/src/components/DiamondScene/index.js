import React, { useEffect, useRef } from 'react';
import * as THREE from 'three';
import gsap from 'gsap';
import { DiamondShader, ParticleShader, FacetHighlightShader } from './shaders';
import { createDiamondGeometry, addFacetIds } from './geometry';

export default function DiamondScene({ className, onHoverChange }) {
  const canvasContainerRef = useRef(null);

  useEffect(() => {
    if (!canvasContainerRef.current) return;

    const container = canvasContainerRef.current;
    
    // Scene setup
    const scene = new THREE.Scene();
    
    // Camera
    const camera = new THREE.PerspectiveCamera(22, container.clientWidth / container.clientHeight, 0.1, 1000);
    camera.position.z = 12;

    // Renderer
    const renderer = new THREE.WebGLRenderer({ antialias: true, alpha: true }); // Alpha true for transparency
    renderer.setSize(container.clientWidth, container.clientHeight);
    renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));
    container.appendChild(renderer.domElement);

    // GEOMETRY
    // Use slightly smaller radius to fit composition
    const diamondGeometry = createDiamondGeometry(1.7);
    
    // Flat Normals for Faceted Look (Critical for diamond shader)
    let flatGeometry = diamondGeometry.toNonIndexed();
    flatGeometry.computeVertexNormals();
    
    // ADD FACET IDs for Interaction
    flatGeometry = addFacetIds(flatGeometry);

    // SHADER MATERIAL (Main Body)
    const material = new THREE.ShaderMaterial({
      uniforms: THREE.UniformsUtils.clone(DiamondShader.uniforms),
      vertexShader: DiamondShader.vertexShader,
      fragmentShader: DiamondShader.fragmentShader,
      side: THREE.DoubleSide,
      transparent: true,
      extensions: { derivatives: true }
    });

    const mesh = new THREE.Mesh(flatGeometry, material);
    
    // HIGHLIGHT MESH (Overlay for EIP-2535 Facets)
    const highlightUniforms = THREE.UniformsUtils.clone(FacetHighlightShader.uniforms);
    const highlightMaterial = new THREE.ShaderMaterial({
      uniforms: highlightUniforms,
      vertexShader: FacetHighlightShader.vertexShader,
      fragmentShader: FacetHighlightShader.fragmentShader,
      side: THREE.DoubleSide,
      transparent: true,
      depthTest: true,
      depthWrite: false,
      blending: THREE.AdditiveBlending,
    });
    
    // Create a slightly scaled up mesh or use polygon offset to avoid z-fighting
    const highlightMesh = new THREE.Mesh(flatGeometry, highlightMaterial);
    highlightMesh.scale.setScalar(1.001); // Tiny scale up to sit on top
    
    // WIREFRAME (Subtle Structure)
    // Angle threshold reduced to 15 to catch the top table edges (which are shallow)
    const edges = new THREE.EdgesGeometry(diamondGeometry, 15); 
    const lineMat = new THREE.LineBasicMaterial({ 
      color: 0xffffff, 
      transparent: true, 
      opacity: 0.3, 
      blending: THREE.AdditiveBlending
    });
    const wireframe = new THREE.LineSegments(edges, lineMat);

    const diamondGroup = new THREE.Group();
    diamondGroup.add(mesh);
    diamondGroup.add(highlightMesh);
    diamondGroup.add(wireframe);

    // PARTICLES: FLOATING WAVE (PRO GRADE - DENSE & UNORDERED)
    const particlesGeometry = new THREE.BufferGeometry();
    const countX = 200;
    const countZ = 100;
    const particlesCount = countX * countZ;
    const posArray = new Float32Array(particlesCount * 3);
    
    let i = 0;
    const separation = 0.5; 
    const offsetX = (countX * separation) / 2;
    const offsetZ = (countZ * separation) / 2;

    for(let x = 0; x < countX; x++) {
      for(let z = 0; z < countZ; z++) {
        posArray[i] = (x * separation) - offsetX + (Math.random() - 0.5) * separation * 0.8;
        posArray[i+1] = 0; 
        posArray[i+2] = (z * separation) - offsetZ + (Math.random() - 0.5) * separation * 0.8;
        i += 3;
      }
    }
    
    particlesGeometry.setAttribute('position', new THREE.BufferAttribute(posArray, 3));
    
    const particlesMaterial = new THREE.ShaderMaterial({
      uniforms: {
        ...ParticleShader.uniforms,
        uWidth: { value: countX * separation },
        uDepth: { value: countZ * separation }
      },
      vertexShader: ParticleShader.vertexShader,
      fragmentShader: ParticleShader.fragmentShader,
      transparent: true,
      blending: THREE.AdditiveBlending,
      depthWrite: false
    });
    
    const particlesMesh = new THREE.Points(particlesGeometry, particlesMaterial);
    
    const particlesGroup = new THREE.Group();
    particlesGroup.add(particlesMesh);
    
    particlesGroup.position.y = -1; 
    particlesGroup.position.z = -1; 
    particlesGroup.rotation.x = 0.05; 
    
    scene.add(diamondGroup);
    scene.add(particlesGroup);

    // INITIAL POSITION
    diamondGroup.position.x = window.innerWidth > 1024 ? 2.2 : 0;
    diamondGroup.position.y = 0.1;
    diamondGroup.rotation.x = 0.25; 
    
    // ANIMATION
    // Rotation
    gsap.to(diamondGroup.rotation, {
      y: Math.PI * 2,
      duration: 40,
      repeat: -1,
      ease: "none"
    });
    
    // Float
    gsap.to(diamondGroup.position, {
      y: 0.4,
      duration: 4,
      yoyo: true,
      repeat: -1,
      ease: "sine.inOut"
    });

    // RAYCASTER SETUP
    const raycaster = new THREE.Raycaster();
    const mouse = new THREE.Vector2(-100, -100); // Start off-screen
    
    const onMouseMove = (event) => {
      // Disable interaction on mobile
      if (window.innerWidth <= 1024) {
        mouse.x = -100;
        mouse.y = -100;
        return;
      }
      
      const rect = renderer.domElement.getBoundingClientRect();
      mouse.x = ((event.clientX - rect.left) / rect.width) * 2 - 1;
      mouse.y = -((event.clientY - rect.top) / rect.height) * 2 + 1;
    };
    
    window.addEventListener('mousemove', onMouseMove);

    // Time Uniform & Loop
    const clock = new THREE.Clock();
    let animationId;
    let currentHoverId = -1;
    
    const animate = () => {
      animationId = requestAnimationFrame(animate);
      const elapsedTime = clock.getElapsedTime();
      
      // Update Uniforms
      mesh.material.uniforms.uTime.value = elapsedTime;
      highlightMesh.material.uniforms.uTime.value = elapsedTime;
      particlesMaterial.uniforms.uTime.value = elapsedTime;
      
      // Rotate wave slightly
      particlesGroup.rotation.y = Math.sin(elapsedTime * 0.1) * 0.1;
      
      // Raycasting logic
      raycaster.setFromCamera(mouse, camera);
      
      // Intersect with the highlight mesh (which has the same geometry as the diamond)
      const intersects = raycaster.intersectObject(highlightMesh);
      
      if (intersects.length > 0) {
        const intersect = intersects[0];
        const faceIndex = intersect.faceIndex;
        
        // Retrieve Facet ID from geometry attribute
        if (flatGeometry.attributes.aFacetId) {
          const facetId = flatGeometry.attributes.aFacetId.getX(faceIndex * 3);
          
          if (highlightMesh.material.uniforms.uHoverFacetId.value !== facetId) {
            highlightMesh.material.uniforms.uHoverFacetId.value = facetId;
            
            // Trigger callback only if changed
            if (currentHoverId !== facetId) {
              currentHoverId = facetId;
              if (onHoverChange) onHoverChange(facetId);
            }
          }
        }
      } else {
        // Reset if no intersection
        if (highlightMesh.material.uniforms.uHoverFacetId.value !== -1.0) {
          highlightMesh.material.uniforms.uHoverFacetId.value = -1.0;
          
          if (currentHoverId !== -1) {
            currentHoverId = -1;
            if (onHoverChange) onHoverChange(-1);
          }
        }
      }
      
      renderer.render(scene, camera);
    };
    animate();

    // RESIZE
    const handleResize = () => {
      if (!container) return;
      const width = container.clientWidth;
      const height = container.clientHeight;
      
      camera.aspect = width / height;
      camera.updateProjectionMatrix();
      renderer.setSize(width, height);
      
      const isDesktop = window.innerWidth > 1024;
      
      if (isDesktop) {
        gsap.to(diamondGroup.position, { x: 2.2, duration: 0.5 });
        mesh.material.opacity = 1.0;
        wireframe.material.opacity = 0.2; 
      } else {
        gsap.to(diamondGroup.position, { x: 0, duration: 0.5 });
        mesh.material.opacity = 0.1; 
        wireframe.material.opacity = 0.05;
      }
    };
    
    handleResize();
    window.addEventListener('resize', handleResize);

    return () => {
      window.removeEventListener('resize', handleResize);
      window.removeEventListener('mousemove', onMouseMove);
      cancelAnimationFrame(animationId);
      if (container && renderer.domElement && container.contains(renderer.domElement)) {
        container.removeChild(renderer.domElement);
      }
      diamondGeometry.dispose();
      flatGeometry.dispose();
      edges.dispose();
      particlesGeometry.dispose(); 
      renderer.dispose();
    };
  }, [onHoverChange]); // Depend on callback

  return <div className={className} ref={canvasContainerRef} />;
}
