import { useEffect } from 'react';

/**
 * Calls onClose when a mousedown happens outside the element attached to ref.
 * @param {React.RefObject} ref
 * @param {boolean} isActive - only listen when true
 * @param {() => void} onClose
 */
export function useClickOutside(ref, isActive, onClose) {
  useEffect(() => {
    if (!isActive) return;
    const handleClickOutside = (event) => {
      if (ref.current && !ref.current.contains(event.target)) {
        onClose();
      }
    };
    document.addEventListener('mousedown', handleClickOutside);
    return () => document.removeEventListener('mousedown', handleClickOutside);
  }, [ref, isActive, onClose]);
}
