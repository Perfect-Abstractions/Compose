/**
 * Persisted sidebar visibility state (desktop only).
 * SSR-safe: defaults to false (visible) until hydration, then reads from localStorage.
 * @param {string} storageKey - localStorage key (e.g. 'compose-docs-sidebar-hidden')
 * @returns {[boolean, function(): void]} [isHidden, toggle]
 */
import { useState, useEffect, useCallback } from 'react';

export function useSidebarVisibility(storageKey) {
  const [isHidden, setIsHidden] = useState(false);

  useEffect(() => {
    if (typeof window === 'undefined') return;
    try {
      const stored = window.localStorage.getItem(storageKey);
      setIsHidden(stored === 'true');
    } catch {
      // ignore
    }
  }, [storageKey]);

  const toggle = useCallback(() => {
    setIsHidden((prev) => {
      const next = !prev;
      try {
        window.localStorage.setItem(storageKey, String(next));
      } catch {
        // ignore
      }
      return next;
    });
  }, [storageKey]);

  return [isHidden, toggle];
}
