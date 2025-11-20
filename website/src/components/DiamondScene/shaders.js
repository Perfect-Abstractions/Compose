import * as THREE from 'three';

// ULTRA-REALISTIC DIAMOND SHADER
// Implements physical dispersion (chromatic aberration), internal reflection simulation,
// and a crystalline normal map perturbation for that "crushed ice" look.
export const DiamondShader = {
  uniforms: {
    uTime: { value: 0 },
    // Color Palette: Deep rich blues for shadow, bright electric blues for highlights
    uColor1: { value: new THREE.Color('#020617') }, // Almost black navy (Depth)
    uColor2: { value: new THREE.Color('#1d4ed8') }, // Rich Blue (Body)
    uColor3: { value: new THREE.Color('#bfdbfe') }, // Ice White (Sparkle)
    uEnvRotation: { value: 0 },
    uPixelSize: { value: 2.0 } // Tighter dithering for definition
  },
  vertexShader: `
    varying vec2 vUv;
    varying vec3 vNormal;
    varying vec3 vPosition;
    varying vec3 vViewPosition;
    varying vec3 vWorldPosition;
    varying vec3 vReflect;

    void main() {
      vUv = uv;
      vNormal = normalize(normalMatrix * normal);
      vPosition = position;
      
      vec4 worldPosition = modelMatrix * vec4(position, 1.0);
      vWorldPosition = worldPosition.xyz;
      
      vec4 mvPosition = modelViewMatrix * vec4(position, 1.0);
      vViewPosition = -mvPosition.xyz;
      
      // Calculate reflection vector in view space for env mapping
      vReflect = reflect(-normalize(vViewPosition), vNormal);
      
      gl_Position = projectionMatrix * mvPosition;
    }
  `,
  fragmentShader: `
    uniform float uTime;
    uniform vec3 uColor1;
    uniform vec3 uColor2;
    uniform vec3 uColor3;
    uniform float uPixelSize;

    varying vec2 vUv;
    varying vec3 vNormal;
    varying vec3 vViewPosition;
    varying vec3 vReflect;

    // Ordered dithering matrix 4x4
    float dither4x4(vec2 position, float brightness) {
      int x = int(mod(position.x, 4.0));
      int y = int(mod(position.y, 4.0));
      int index = x + y * 4;
      float limit = 0.0;

      if (x < 8) {
        if (index == 0) limit = 0.0625;
        if (index == 1) limit = 0.5625;
        if (index == 2) limit = 0.1875;
        if (index == 3) limit = 0.6875;
        if (index == 4) limit = 0.8125;
        if (index == 5) limit = 0.3125;
        if (index == 6) limit = 0.9375;
        if (index == 7) limit = 0.4375;
        if (index == 8) limit = 0.25;
        if (index == 9) limit = 0.75;
        if (index == 10) limit = 0.125;
        if (index == 11) limit = 0.625;
        if (index == 12) limit = 1.0;
        if (index == 13) limit = 0.5;
        if (index == 14) limit = 0.875;
        if (index == 15) limit = 0.375;
      }
      return brightness < limit ? 0.0 : 1.0;
    }
    
    // Fast pseudo-random
    float rand(vec2 co){
        return fract(sin(dot(co.xy ,vec2(12.9898,78.233))) * 43758.5453);
    }

      // Cheap environment map simulation (Studio Lights)
      float getEnvLight(vec3 dir) {
        float light = 0.0;
        // Key Light (Top Right) - Boosted for brightness
        light += pow(max(0.0, dot(dir, normalize(vec3(1.0, 1.5, 1.0)))), 32.0) * 3.5;
        // Top Light (Direct Overhead) - Added for extra brilliance
        light += pow(max(0.0, dot(dir, vec3(0.0, 0.95, 0.1))), 20.0) * 2.0;
        // Fill Light (Left)
        light += pow(max(0.0, dot(dir, normalize(vec3(-1.0, 0.5, 0.2)))), 16.0) * 1.2;
        // Rim Light (Back/Bottom) - Reduced intensity to darken bottom
        light += pow(max(0.0, dot(dir, normalize(vec3(0.0, -1.0, -1.0)))), 8.0) * 0.2;
        
        return light;
      }

    void main() {
      vec3 viewDir = normalize(vViewPosition);
      vec3 normal = normalize(vNormal);
      
      // 1. Fresnel (The "Glass" Edge)
      float fresnel = pow(1.0 - max(0.0, dot(viewDir, normal)), 4.0);
      
      // 2. Reflection (External bounce)
      vec3 refDir = reflect(-viewDir, normal);
      
      // 3. Refraction/Internal (The "Fire")
      // We simulate internal bounces by distorting the reflection vector
      // This creates the "scrambled" look of a diamond interior
      vec3 internalDir = refDir;
      internalDir.x += sin(uTime * 0.5 + vViewPosition.y * 10.0) * 0.1;
      internalDir.y += cos(uTime * 0.3 + vViewPosition.x * 10.0) * 0.1;
      internalDir = normalize(internalDir);
      
      // 4. Dispersion (Chromatic Aberration - The Rainbow)
      // We sample the environment light at slightly offset angles for R, G, B
      float rLight = getEnvLight(normalize(internalDir + vec3(0.02, 0.0, 0.0)));
      float gLight = getEnvLight(normalize(internalDir));
      float bLight = getEnvLight(normalize(internalDir - vec3(0.02, 0.0, 0.0)));
      
      vec3 sparkles = vec3(rLight, gLight, bLight);
      
      // 5. Edge Definition (Facet Cuts)
      // Use derivatives to find sharp geometric edges
      vec3 dNx = dFdx(vNormal);
      vec3 dNy = dFdy(vNormal);
      float edgeStrength = length(dNx) + length(dNy);
      // Lower threshold to catch fainter edges (like the top table angles)
      float edge = smoothstep(0.01, 0.06, edgeStrength);
      
      // COMPOSITING
      
      // Base Body: Deep blue to mid blue gradient based on view angle
      float bodyTerm = dot(normal, vec3(0.0, 1.0, 0.0)) * 0.5 + 0.5;
      // Brighter top mix: 0.8 influence instead of 0.6
      vec3 bodyColor = mix(uColor1, uColor2, bodyTerm * 0.8 + fresnel * 0.4);
      
      // Add Sparkles (Dispersion)
      // Sparkles are masked by the body density to feel "internal"
      vec3 finalColor = bodyColor + (sparkles * uColor3 * 1.5);
      
      // Add extra top face brightness (Table highlight)
      float topGlow = smoothstep(0.8, 1.0, normal.y); // Widen the range to catch more top angles
      finalColor += uColor3 * topGlow * 0.25; // Boosted intensity
      
      // Add crisp white edges - Changed to Light Blue for definition
      vec3 edgeColor = mix(uColor3, uColor2, 0.2); // Whiter blue
      finalColor += edgeColor * edge * 2.0; // Stronger edge definition
      
      // DITHERING (The Retro-Tech Style)
      // We dither based on luminance to create texture
      float luminance = dot(finalColor, vec3(0.299, 0.587, 0.114));
      
      // Boost dither input at edges and highlights - Increased weight to fill body
      float ditherInput = luminance * 1.2 + edge * 0.4 + max(rLight, max(gLight, bLight)) * 0.2;
      
      vec2 pixelCoord = gl_FragCoord.xy / uPixelSize;
      float dither = dither4x4(pixelCoord, ditherInput);
      
      // Final Mix:
      // Balanced mix: Use calculated color for both states to preserve form
      // Shadow state: Dimmer but colored (0.6)
      // Light state: Boosted (1.4)
      vec3 pixelColor = mix(finalColor * 0.6, finalColor * 1.4, dither);
      
      // Add pure white sparkle post-dither for "blinding" hits
      float superHighlight = step(0.95, max(rLight, max(gLight, bLight)));
      pixelColor = mix(pixelColor, vec3(1.0), superHighlight * 0.8);

    // MOBILE VISIBILITY FIX:
    // On small screens, the diamond often sits BEHIND the text.
    // We need to fade it out or darken it significantly when it might interfere with text readability.
    
    gl_FragColor = vec4(pixelColor, 0.9); // Slight transparency for blending
  }
`
};

// PARTICLE SHADER - Floating diamond dust (Pro Wave with Flow)
export const ParticleShader = {
  uniforms: {
    uTime: { value: 0 },
    uColor: { value: new THREE.Color('#3b82f6') }, // Blue-500
    uPixelSize: { value: 2.0 },
    uWidth: { value: 100.0 } // Width of the field for wrapping
  },
  vertexShader: `
    uniform float uTime;
    uniform float uWidth;
    varying vec3 vPos;
    varying float vDist; 
    
    void main() {
      vPos = position;
      vec3 pos = position;
      
      // CONTINUOUS FLOW:
      // Move particles to the right over time
      float speed = 0.5;
      pos.x += uTime * speed;
      
      // Infinite Scroll Logic:
      // If pos.x goes beyond half width, wrap it back to start
      // Assumes initial grid is centered at 0
      // uWidth is total width. Range is [-uWidth/2, uWidth/2]
      float halfWidth = uWidth * 0.5;
      
      // Modulo math for GLSL to wrap around [-halfWidth, halfWidth]
      // We add halfWidth first to shift to [0, uWidth], mod it, then shift back
      pos.x = mod(pos.x + halfWidth, uWidth) - halfWidth;
      
      // WAVE MOVEMENT (Vertical):
      // Use the new wrapped X for wave calculation so the wave stays cohesive
      float time = uTime * 0.3;
      
      // Layered sine waves for "water" look
      float wave1 = sin(pos.x * 0.4 + time) * cos(pos.z * 0.3 + time) * 0.6;
      float wave2 = sin(pos.x * 0.8 - time * 1.2) * 0.2;
      float wave3 = cos((pos.x + pos.z) * 0.2) * 0.3;
      
      pos.y += wave1 + wave2 + wave3;
      
      vec4 mvPosition = modelViewMatrix * vec4(pos, 1.0);
      gl_Position = projectionMatrix * mvPosition;
      
      // Calculate distance for depth fade
      vDist = length(mvPosition.xyz);
      
      // Size attenuation - Dust Size
      gl_PointSize = (4.0 * 12.0) / -mvPosition.z;
    }
  `,
  fragmentShader: `
    uniform vec3 uColor;
    uniform float uPixelSize;
    varying float vDist;
    
    // Reusing dither logic for consistency
    float dither4x4(vec2 position, float brightness) {
      int x = int(mod(position.x, 4.0));
      int y = int(mod(position.y, 4.0));
      int index = x + y * 4;
      float limit = 0.0;
      if (x < 8) {
        if (index == 0) limit = 0.0625;
        if (index == 1) limit = 0.5625;
        if (index == 2) limit = 0.1875;
        if (index == 3) limit = 0.6875;
        if (index == 4) limit = 0.8125;
        if (index == 5) limit = 0.3125;
        if (index == 6) limit = 0.9375;
        if (index == 7) limit = 0.4375;
        if (index == 8) limit = 0.25;
        if (index == 9) limit = 0.75;
        if (index == 10) limit = 0.125;
        if (index == 11) limit = 0.625;
        if (index == 12) limit = 1.0;
        if (index == 13) limit = 0.5;
        if (index == 14) limit = 0.875;
        if (index == 15) limit = 0.375;
      }
      return brightness < limit ? 0.0 : 1.0;
    }

    void main() {
      vec2 center = gl_PointCoord - 0.5;
      float dist = length(center);
      if (dist > 0.5) discard;
      
      // Softer, more diffuse edge for "dust" look
      float alpha = 1.0 - smoothstep(0.4, 0.8, dist);
      
      // Depth Fade
      float depthFade = 1.0 - smoothstep(8.0, 22.0, vDist);
      alpha *= depthFade;
      
      vec2 pixelCoord = gl_FragCoord.xy / uPixelSize;
      float dither = dither4x4(pixelCoord, alpha * 1.5); 
      
      if (dither < 0.1) discard;
      
      // Slightly more varied color for dust (mostly blue with faint white)
      vec3 finalColor = mix(uColor, vec3(1.0), 0.1);
      
      gl_FragColor = vec4(finalColor, alpha * 0.6);
    }
  `
};

// HIGHLIGHT SHADER - For highlighting specific facets (Diamond Standard / EIP-2535 Visualization)
export const FacetHighlightShader = {
  uniforms: {
    uTime: { value: 0 },
    uColor: { value: new THREE.Color('#488FF8') }, // Blue-400 (Bright Blue)
    uActiveFacetId: { value: -1.0 }, // ID of the facet group to highlight (-1 = none)
    uHoverFacetId: { value: -1.0 } // ID of the facet currently hovered (optional)
  },
  vertexShader: `
    attribute float aFacetId;
    varying float vFacetId;
    varying vec3 vNormal;
    
    void main() {
      vFacetId = aFacetId;
      vNormal = normalize(normalMatrix * normal);
      vec4 mvPosition = modelViewMatrix * vec4(position, 1.0);
      gl_Position = projectionMatrix * mvPosition;
    }
  `,
  fragmentShader: `
    uniform float uTime;
    uniform vec3 uColor;
    uniform float uActiveFacetId;
    uniform float uHoverFacetId;
    
    varying float vFacetId;
    varying vec3 vNormal;
    varying vec3 vPosition; // Added for rim calculation

    void main() {
      // Check if this fragment belongs to the active facet group
      float isActive = 1.0 - step(0.1, abs(vFacetId - uActiveFacetId));
      float isHover = 1.0 - step(0.1, abs(vFacetId - uHoverFacetId));
      
      float totalActive = max(isActive, isHover);
      
      if (totalActive < 0.1) discard;
      
      // Clean, steady glow instead of frantic pulsing
      // Small subtle breathe for life
      float breathe = sin(uTime * 3.0) * 0.1 + 0.95; // Faster, brighter base
      
      // Add Rim Light for definition (Fresnel-like)
      // View vector is roughly along Z in local space for this simple rim
      float rim = 1.5 - abs(dot(normalize(vNormal), vec3(0.0, 0.0, 1.0)));
      rim = pow(rim, 3.0);
      
      // Combine
      vec3 finalColor = uColor * 1.4; // Boost base color brightness
      
      // Mix solid fill with extra bright rim
      finalColor += vec3(0.6) * rim; // Brighter rim
      
      // Base alpha: steady and clean
      // Increased opacity significantly for brighter appearance
      float alpha = totalActive * breathe * 0.85; 
      
      // Boost alpha at rim for "glassy" edge
      alpha += rim * 0.4;

      gl_FragColor = vec4(finalColor, alpha);
    }
  `
};
