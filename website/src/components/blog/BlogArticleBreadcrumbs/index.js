/**
 * Blog article breadcrumbs: same row as sidebar toggle (icon) + Home > Blog > Article title.
 * Only rendered on blog post pages; uses DocBreadcrumbs styles for consistency.
 */
import React from 'react';
import clsx from 'clsx';
import Link from '@docusaurus/Link';
import { useBlogPost } from '@docusaurus/plugin-content-blog/client';
import HomeBreadcrumbItem from '@theme/DocBreadcrumbs/Items/Home';
import { useBlogSidebarVisibility } from '@site/src/contexts/BlogSidebarVisibilityContext';
import { SidebarToggleButton } from '@site/src/components/navigation/SidebarToggle';
import styles from '@site/src/theme/DocBreadcrumbs/styles.module.css';

function BreadcrumbsItemLink({ children, href, isLast }) {
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

function BreadcrumbsItem({ children, active }) {
  return (
    <li
      className={clsx('breadcrumbs__item', {
        'breadcrumbs__item--active': active,
      })}>
      {children}
    </li>
  );
}

export default function BlogArticleBreadcrumbs() {
  const { metadata } = useBlogPost();
  const {
    isHidden: sidebarFullyHidden,
    toggle: toggleSidebarFullyHidden,
    hasSidebar,
  } = useBlogSidebarVisibility();

  if (!metadata) {
    return null;
  }

  const sidebarToggleAriaLabel = sidebarFullyHidden
    ? 'Show recent blog posts sidebar'
    : 'Hide recent blog posts sidebar';

  return (
    <nav
      className={styles.breadcrumbsContainer}
      aria-label="Breadcrumbs">
      <div className={styles.breadcrumbsInner}>
        {hasSidebar && (
          <>
            <SidebarToggleButton
              isHidden={sidebarFullyHidden}
              onToggle={toggleSidebarFullyHidden}
              ariaLabel={sidebarToggleAriaLabel}
            />
            <span className={styles.sidebarToggleSep} aria-hidden="true">
              |
            </span>
          </>
        )}
        <ul className="breadcrumbs">
          <HomeBreadcrumbItem />
          <BreadcrumbsItem active={false}>
            <BreadcrumbsItemLink href="/blog" isLast={false}>
              Blog
            </BreadcrumbsItemLink>
          </BreadcrumbsItem>
          <BreadcrumbsItem active>
            <BreadcrumbsItemLink href={undefined} isLast>
              {metadata.title}
            </BreadcrumbsItemLink>
          </BreadcrumbsItem>
        </ul>
      </div>
    </nav>
  );
}
