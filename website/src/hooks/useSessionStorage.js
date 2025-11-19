import {useState, useCallback} from 'react';

/**
 * Simple session storage hook with key/value setting
 * Persists values for the current browser session only
 * 
 * @param {string} key - Storage key
 * @param {string|null} initialValue - Initial value if key doesn't exist
 * @returns {[string|null, function, function]} - [value, setValue, removeValue]
 */
export function useSessionStorage(key, initialValue = null) {
  // Initialize state from sessionStorage or use initialValue
  const [storedValue, setStoredValue] = useState(() => {
    if (typeof window === 'undefined') {
      return initialValue;
    }
    try {
      const item = window.sessionStorage.getItem(key);
      return item ? JSON.parse(item) : initialValue;
    } catch (error) {
      console.warn(`Error reading sessionStorage key "${key}":`, error);
      return initialValue;
    }
  });

  // Set value function
  const setValue = useCallback(
    (value) => {
      if (typeof window === 'undefined') {
        return;
      }
      try {
        setStoredValue(value);
        window.sessionStorage.setItem(key, JSON.stringify(value));
      } catch (error) {
        console.warn(`Error setting sessionStorage key "${key}":`, error);
      }
    },
    [key]
  );

  // Remove value function
  const removeValue = useCallback(() => {
    if (typeof window === 'undefined') {
      return;
    }
    try {
      setStoredValue(null);
      window.sessionStorage.removeItem(key);
    } catch (error) {
      console.warn(`Error removing sessionStorage key "${key}":`, error);
    }
  }, [key]);

  return [storedValue, setValue, removeValue];
}

