/**
 * Injects the markdown actions dropdown on doc pages: same row as breadcrumbs
 * (breadcrumbs left, dropdown right). Runs at 0ms, 100ms, 300ms to handle
 * async DOM from Docusaurus.
 */
import React, { useEffect } from 'react';
import { useLocation } from '@docusaurus/router';
import { createRoot } from 'react-dom/client';
import MarkdownActionsDropdown from '@site/src/components/docs/MarkdownActionsDropdown';

export default function useInjectMarkdownActionsDropdown() {
  const { pathname } = useLocation();

  useEffect(() => {
    const injectDropdown = () => {
      if (!pathname.startsWith('/docs/')) return;
      const article = document.querySelector('article');
      const breadcrumbsNav = article?.querySelector(
        'nav.theme-doc-breadcrumbs, nav[aria-label="Breadcrumbs"]'
      );
      if (!article || !breadcrumbsNav) return;
      if (document.querySelector('.markdown-actions-breadcrumbs-row')) return;

      const row = document.createElement('div');
      row.className = 'markdown-actions-breadcrumbs-row';
      article.insertBefore(row, article.firstChild);
      row.appendChild(breadcrumbsNav);

      const container = document.createElement('div');
      container.className = 'markdown-actions-container';
      row.appendChild(container);

      const root = createRoot(container);
      root.render(<MarkdownActionsDropdown />);
    };

    const timeouts = [0, 100, 300].map((delay) =>
      setTimeout(injectDropdown, delay)
    );
    return () => timeouts.forEach(clearTimeout);
  }, [pathname]);
}
