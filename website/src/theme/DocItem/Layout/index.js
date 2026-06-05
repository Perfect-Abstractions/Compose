/**
 * Swizzled DocItem Layout: doc feedback aside (Cloudflare-style rail + mobile inline).
 */
import React from 'react';
import clsx from 'clsx';
import { useWindowSize } from '@docusaurus/theme-common';
import { useDoc } from '@docusaurus/plugin-content-docs/client';
import DocItemPaginator from '@theme/DocItem/Paginator';
import DocVersionBanner from '@theme/DocVersionBanner';
import DocVersionBadge from '@theme/DocVersionBadge';
import DocItemFooter from '@theme/DocItem/Footer';
import DocItemTOCMobile from '@theme/DocItem/TOC/Mobile';
import DocItemTOCDesktop from '@theme/DocItem/TOC/Desktop';
import DocItemContent from '@theme/DocItem/Content';
import DocBreadcrumbs from '@theme/DocBreadcrumbs';
import ContentVisibility from '@theme/ContentVisibility';
import DocPageAside from '@site/src/components/docs/DocPageAside';
import DocItemStructuredData from '@theme/DocItem/StructuredData';

import styles from './styles.module.css';

function useDocTOC() {
  const { frontMatter, toc } = useDoc();
  const windowSize = useWindowSize();

  const hidden = frontMatter.hide_table_of_contents;
  const canRender = !hidden && toc.length > 0;

  const mobile = canRender ? <DocItemTOCMobile /> : undefined;

  const desktop =
    canRender && (windowSize === 'desktop' || windowSize === 'ssr') ? (
      <DocItemTOCDesktop />
    ) : undefined;

  return {
    hidden,
    mobile,
    desktop,
  };
}

export default function DocItemLayout({ children }) {
  const docTOC = useDocTOC();
  const { metadata } = useDoc();
  const windowSize = useWindowSize();
  const isDesktop = windowSize === 'desktop' || windowSize === 'ssr';
  const showDesktopRightColumn = isDesktop;
  const showAsideInline = !isDesktop;

  return (
    <div className="row">
      <DocItemStructuredData />
      <div
        className={clsx(
          'col',
          showDesktopRightColumn && styles.docItemCol
        )}>
        <ContentVisibility metadata={metadata} />
        <DocVersionBanner />
        <div className={styles.docItemContainer}>
          <article>
            <DocBreadcrumbs />
            <DocVersionBadge />
            {docTOC.mobile}
            <DocItemContent>{children}</DocItemContent>
            <DocItemFooter />
          </article>
          {showAsideInline && <DocPageAside />}
          <DocItemPaginator />
        </div>
      </div>
      {showDesktopRightColumn && (
        <div className="col col--3">
          {docTOC.desktop ? (
            <div className={styles.docTocRail}>
              <div className={clsx(styles.docTocRailScroll, 'thin-scrollbar')}>
                {docTOC.desktop}
              </div>
              <div className={styles.docTocRailFooter}>
                <DocPageAside />
              </div>
            </div>
          ) : (
            <div className={styles.docAsideOnly}>
              <DocPageAside soloInSidebar />
            </div>
          )}
        </div>
      )}
    </div>
  );
}
