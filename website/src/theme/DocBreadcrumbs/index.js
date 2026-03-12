/**
 * Swizzled DocBreadcrumbs: same row as sidebar toggle (icon) + breadcrumbs + markdown actions dropdown.
 * Sidebar toggle is inline before breadcrumbs (docs only) to save space.
 */
import React from 'react';
import clsx from 'clsx';
import {ThemeClassNames} from '@docusaurus/theme-common';
import {
  useSidebarBreadcrumbs,
  useDocsSidebar,
} from '@docusaurus/plugin-content-docs/client';
import {useHomePageRoute} from '@docusaurus/theme-common/internal';
import Link from '@docusaurus/Link';
import {translate} from '@docusaurus/Translate';
import HomeBreadcrumbItem from '@theme/DocBreadcrumbs/Items/Home';
import DocBreadcrumbsStructuredData from '@theme/DocBreadcrumbs/StructuredData';
import MarkdownActionsDropdown from '@site/src/components/docs/MarkdownActionsDropdown';
import {useDocsSidebarVisibility} from '@site/src/contexts/DocsSidebarVisibilityContext';
import { SidebarToggleButton } from '@site/src/components/navigation/SidebarToggle';
import styles from './styles.module.css';

function BreadcrumbsItemLink({children, href, isLast}) {
  const className = 'breadcrumbs__link';
  if (isLast) {
    return <span className={className}>{children}</span>;
  }
  return href ? (
    <Link className={className} href={href}>
      <span>{children}</span>
    </Link>
  ) : (
    <span className={className}>{children}</span>
  );
}

function BreadcrumbsItem({children, active}) {
  return (
    <li
      className={clsx('breadcrumbs__item', {
        'breadcrumbs__item--active': active,
      })}>
      {children}
    </li>
  );
}

export default function DocBreadcrumbs() {
  const breadcrumbs = useSidebarBreadcrumbs();
  const homePageRoute = useHomePageRoute();
  const sidebar = useDocsSidebar();
  const { isHidden: sidebarFullyHidden, toggle: toggleSidebarFullyHidden } =
    useDocsSidebarVisibility();

  if (!breadcrumbs) {
    return null;
  }

  const sidebarToggleAriaLabel = sidebarFullyHidden
    ? 'Show navigation sidebar'
    : 'Hide navigation sidebar';

  return (
    <>
      <DocBreadcrumbsStructuredData breadcrumbs={breadcrumbs} />
      <div className="markdown-actions-breadcrumbs-row">
        <nav
          className={clsx(
            ThemeClassNames.docs.docBreadcrumbs,
            styles.breadcrumbsContainer,
          )}
          aria-label={translate({
            id: 'theme.docs.breadcrumbs.navAriaLabel',
            message: 'Breadcrumbs',
            description: 'The ARIA label for the breadcrumbs',
          })}>
          <div className={styles.breadcrumbsInnerBlogArticle}>
            {sidebar && (
              <>
                <SidebarToggleButton
                  isHidden={sidebarFullyHidden}
                  onToggle={toggleSidebarFullyHidden}
                  ariaLabel={sidebarToggleAriaLabel}
                />
                <span
                  className={styles.sidebarToggleSep}
                  aria-hidden="true">
                  |
                </span>
              </>
            )}
            <ul className="breadcrumbs">
              {homePageRoute && <HomeBreadcrumbItem />}
              {breadcrumbs.map((item, idx) => {
                const isLast = idx === breadcrumbs.length - 1;
                const href =
                  item.type === 'category' && item.linkUnlisted
                    ? undefined
                    : item.href;
                return (
                  <BreadcrumbsItem key={idx} active={isLast}>
                    <BreadcrumbsItemLink href={href} isLast={isLast}>
                      {item.label}
                    </BreadcrumbsItemLink>
                  </BreadcrumbsItem>
                );
              })}
            </ul>
          </div>
        </nav>
        <div className="markdown-actions-container">
          <MarkdownActionsDropdown />
        </div>
      </div>
    </>
  );
}
