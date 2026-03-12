/**
 * Shared state for docs sidebar visibility (hide/show).
 * Consumed by DocRoot Layout (for .docs-sidebar-hidden class) and DocBreadcrumbs (inline toggle).
 */
import React from 'react';

export const DocsSidebarVisibilityContext = React.createContext(null);

/**
 * @returns {{ isHidden: boolean, toggle: () => void }}
 */
export function useDocsSidebarVisibility() {
  const value = React.useContext(DocsSidebarVisibilityContext);
  if (value == null) {
    return { isHidden: false, toggle: () => {} };
  }
  const [isHidden, toggle] = value;
  return { isHidden, toggle };
}
