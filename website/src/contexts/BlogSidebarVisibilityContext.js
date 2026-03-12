/**
 * Shared state for blog sidebar visibility (hide/show).
 * Value: [sidebarFullyHidden, toggleSidebarFullyHidden, hasSidebar].
 * Consumed by BlogArticleBreadcrumbs (inline toggle in breadcrumb row).
 */
import React from 'react';

export const BlogSidebarVisibilityContext = React.createContext(null);

/**
 * @returns {{ isHidden: boolean, toggle: () => void, hasSidebar: boolean }}
 */
export function useBlogSidebarVisibility() {
  const value = React.useContext(BlogSidebarVisibilityContext);
  if (value == null) {
    return { isHidden: false, toggle: () => {}, hasSidebar: false };
  }
  const [isHidden, toggle, hasSidebar = false] = value;
  return { isHidden, toggle, hasSidebar };
}
