/**
 * Custom BlogLayout: desktop-only sidebar hide/show with persisted preference.
 */
import React, { useMemo } from 'react';
import clsx from 'clsx';
import Layout from '@theme/Layout';
import BlogSidebar from '@theme/BlogSidebar';
import BlogArticleBreadcrumbs from '@site/src/components/blog/BlogArticleBreadcrumbs';
import { useSidebarVisibility } from '@site/src/hooks/useSidebarVisibility';
import { STORAGE_KEYS } from '@site/src/constants/sidebar';
import { BlogSidebarVisibilityContext } from '@site/src/contexts/BlogSidebarVisibilityContext';

export default function BlogLayout(props) {
  const { sidebar, toc, children, isBlogPostPage, ...layoutProps } = props;
  const hasSidebar = sidebar && sidebar.items.length > 0;
  const isBlogArticlePage = isBlogPostPage === true || !!toc;
  const [sidebarFullyHidden, toggleSidebarFullyHidden] = useSidebarVisibility(
    STORAGE_KEYS.blog
  );
  // Only apply persisted "hidden" on article pages; index always shows sidebar
  const effectiveSidebarHidden = isBlogArticlePage && sidebarFullyHidden;
  const sidebarVisibilityValue = useMemo(
    () => [sidebarFullyHidden, toggleSidebarFullyHidden, hasSidebar],
    [sidebarFullyHidden, toggleSidebarFullyHidden, hasSidebar]
  );

  return (
    <BlogSidebarVisibilityContext.Provider value={sidebarVisibilityValue}>
    <Layout {...layoutProps}>
      <div
        className={clsx(
          'container',
          isBlogArticlePage
            ? 'padding-top--md padding-bottom--lg blog-article-container'
            : 'margin-vert--lg',
          effectiveSidebarHidden && 'blog-sidebar-hidden'
        )}>
        <div className="row theme-blog-wrapper">
          {hasSidebar && <BlogSidebar sidebar={sidebar} />}
          <main
            className={clsx('col', {
              'col--7': hasSidebar && !effectiveSidebarHidden,
              'col--9 col--offset-1': !hasSidebar,
              /* Left sidebar hidden: main uses 9 cols so right ToC (col--2) stays visible */
              'col--9': hasSidebar && effectiveSidebarHidden,
            })}>
            {isBlogArticlePage && <BlogArticleBreadcrumbs />}
            {children}
          </main>
          {toc && <div className="col col--2">{toc}</div>}
        </div>
      </div>
    </Layout>
    </BlogSidebarVisibilityContext.Provider>
  );
}
