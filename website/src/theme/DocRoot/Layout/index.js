/**
 * Custom DocRoot Layout: desktop-only sidebar hide/show with persisted preference.
 * Toggle is rendered inline in DocBreadcrumbs (not above content).
 */
import React, { useState, useMemo } from 'react';
import clsx from 'clsx';
import { useDocsSidebar } from '@docusaurus/plugin-content-docs/client';
import BackToTopButton from '@theme/BackToTopButton';
import DocRootLayoutSidebar from '@theme/DocRoot/Layout/Sidebar';
import DocRootLayoutMain from '@theme/DocRoot/Layout/Main';
import { useSidebarVisibility } from '@site/src/hooks/useSidebarVisibility';
import { STORAGE_KEYS } from '@site/src/constants/sidebar';
import { DocsSidebarVisibilityContext } from '@site/src/contexts/DocsSidebarVisibilityContext';

import styles from './styles.module.css';

export default function DocRootLayout({ children }) {
  const sidebar = useDocsSidebar();
  const [hiddenSidebarContainer, setHiddenSidebarContainer] = useState(false);
  const [sidebarFullyHidden, toggleSidebarFullyHidden] = useSidebarVisibility(
    STORAGE_KEYS.docs
  );
  const sidebarVisibilityValue = useMemo(
    () => [sidebarFullyHidden, toggleSidebarFullyHidden],
    [sidebarFullyHidden, toggleSidebarFullyHidden]
  );

  return (
    <DocsSidebarVisibilityContext.Provider value={sidebarVisibilityValue}>
      <div
        className={clsx(
          styles.docsWrapper,
          sidebarFullyHidden && 'docs-sidebar-hidden'
        )}>
        <BackToTopButton />
        <div className={styles.docRoot}>
          {sidebar && (
            <DocRootLayoutSidebar
              sidebar={sidebar.items}
              hiddenSidebarContainer={hiddenSidebarContainer}
              setHiddenSidebarContainer={setHiddenSidebarContainer}
            />
          )}
          <DocRootLayoutMain
            hiddenSidebarContainer={hiddenSidebarContainer}
            sidebarFullyHidden={sidebarFullyHidden}>
            {children}
          </DocRootLayoutMain>
        </div>
      </div>
    </DocsSidebarVisibilityContext.Provider>
  );
}
