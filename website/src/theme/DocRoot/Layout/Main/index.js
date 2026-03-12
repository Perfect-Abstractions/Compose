/**
 * Custom DocRoot Layout Main. Sidebar toggle is in DocBreadcrumbs.
 */
import React from 'react';
import clsx from 'clsx';
import { useDocsSidebar } from '@docusaurus/plugin-content-docs/client';

import styles from './styles.module.css';

export default function DocRootLayoutMain({
  hiddenSidebarContainer,
  sidebarFullyHidden = false,
  children,
}) {
  const sidebar = useDocsSidebar();
  const mainExpanded =
    hiddenSidebarContainer || sidebarFullyHidden || !sidebar;

  return (
    <main
      className={clsx(
        styles.docMainContainer,
        mainExpanded && styles.docMainContainerEnhanced,
        sidebarFullyHidden && 'docs-main-full-width'
      )}>
      <div
        className={clsx(
          'container padding-top--md padding-bottom--lg',
          styles.docItemWrapper,
          (hiddenSidebarContainer || sidebarFullyHidden) &&
            styles.docItemWrapperEnhanced
        )}>
        {children}
      </div>
    </main>
  );
}
