import { useState, useEffect } from 'react';

const MOBILE_BREAKPOINT = 996;

/**
 * Returns true when viewport width is at or below the mobile breakpoint (996px).
 * Used to switch hero layout: full-screen diamond + side content vs. small centered diamond with content around it.
 */
export function useIsMobile() {
  const [isMobile, setIsMobile] = useState(false);

  useEffect(() => {
    const mql = window.matchMedia(`(max-width: ${MOBILE_BREAKPOINT}px)`);
    const update = () => setIsMobile(mql.matches);
    update();
    mql.addEventListener('change', update);
    return () => mql.removeEventListener('change', update);
  }, []);

  return isMobile;
}
