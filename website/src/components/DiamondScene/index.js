import React, { useEffect, useRef } from 'react';
import * as THREE from 'three';
import gsap from 'gsap';
import { DiamondShader, ParticleShader } from './shaders';
import { createDiamondGeometry } from './geometry';

export default function DiamondScene({ className }) {
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
    const flatGeometry = diamondGeometry.toNonIndexed();
    flatGeometry.computeVertexNormals();

    // SHADER MATERIAL
    const material = new THREE.ShaderMaterial({
      uniforms: DiamondShader.uniforms,
      vertexShader: DiamondShader.vertexShader,
      fragmentShader: DiamondShader.fragmentShader,
      side: THREE.DoubleSide,
      transparent: true,
      extensions: { derivatives: true }
    });

    const mesh = new THREE.Mesh(flatGeometry, material);
    
    // WIREFRAME (Subtle Structure)
    // Angle threshold reduced to 15 to catch the top table edges (which are shallow)
    const edges = new THREE.EdgesGeometry(diamondGeometry, 15); 
    const lineMat = new THREE.LineBasicMaterial({ 
      color: 0xffffff, 
      transparent: true, 
      opacity: 0.3, // Increased from 0.15 for clearer "border on axis"
      blending: THREE.AdditiveBlending
    });
    const wireframe = new THREE.LineSegments(edges, lineMat);

    const diamondGroup = new THREE.Group();
    diamondGroup.add(mesh);
    diamondGroup.add(wireframe);

    // PARTICLES: FLOATING WAVE (PRO GRADE - DENSE & UNORDERED)
    const particlesGeometry = new THREE.BufferGeometry();
    // Massive grid for "infinite sea" look
    const countX = 200;
    const countZ = 100;
    const particlesCount = countX * countZ;
    const posArray = new Float32Array(particlesCount * 3);
    
    let i = 0;
    const separation = 0.5; // Even tighter spacing for high density
    const offsetX = (countX * separation) / 2;
    const offsetZ = (countZ * separation) / 2;

    for(let x = 0; x < countX; x++) {
      for(let z = 0; z < countZ; z++) {
        // Grid position with random jitter for "unordered" look
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
        // Pass uniform for wrapping if needed, or hardcode in shader
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
    
    // Create a group for particles
    const particlesGroup = new THREE.Group();
    particlesGroup.add(particlesMesh);
    
    // Position: Bottom half of header (Raised slightly)
    // Camera is at z=12. We put this lower and tilted to act as a "sea"
    particlesGroup.position.y = -1; // Moved up from -2.5
    particlesGroup.position.z = -1; // Push back slightly
    particlesGroup.rotation.x = 0.05; // Tilt up towards back
    
    scene.add(diamondGroup);
    scene.add(particlesGroup);

    // INITIAL POSITION
    diamondGroup.position.x = window.innerWidth > 1024 ? 2.2 : 0;
    diamondGroup.position.y = 0.1;
    diamondGroup.rotation.x = 0.25; // Tilt to catch light
    
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

    // Time Uniform
    const clock = new THREE.Clock();
    let animationId;
    const animate = () => {
      animationId = requestAnimationFrame(animate);
      const elapsedTime = clock.getElapsedTime();
      mesh.material.uniforms.uTime.value = elapsedTime;
      particlesMaterial.uniforms.uTime.value = elapsedTime;
      
      // Rotate wave slightly or just let it flow
      particlesGroup.rotation.y = Math.sin(elapsedTime * 0.1) * 0.1;
      
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
        // Keep particles centered or adjust if needed
        // gsap.to(particlesGroup.position, { x: 0, duration: 0.5 }); 
        mesh.material.opacity = 1.0;
        wireframe.material.opacity = 0.2; // Match initial definition
      } else {
        gsap.to(diamondGroup.position, { x: 0, duration: 0.5 });
        // Fade out on mobile to not block text
        mesh.material.opacity = 0.1; 
        wireframe.material.opacity = 0.05;
      }
    };
    
    handleResize();
    window.addEventListener('resize', handleResize);

    return () => {
      window.removeEventListener('resize', handleResize);
      cancelAnimationFrame(animationId);
      if (container && renderer.domElement && container.contains(renderer.domElement)) {
        container.removeChild(renderer.domElement);
      }
      diamondGeometry.dispose();
      flatGeometry.dispose();
      edges.dispose();
      particlesGeometry.dispose(); // Clean up particles
      renderer.dispose();
    };
  }, []);

  return <div className={className} ref={canvasContainerRef} />;
}

