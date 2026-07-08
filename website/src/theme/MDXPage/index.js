/**
 * Swizzled MDXPage: renders standalone MDX pages using the docs-style layout
 * (breadcrumb, right-hand TOC rail, feedback aside) while keeping the left
 * navigation sidebar hidden.
 *
 * Pages that set `layout: default` in their frontmatter fall back to the
 * original Docusaurus MDX page layout.
 */
import React from 'react';
import clsx from 'clsx';
import {
  PageMetadata,
  HtmlClassNameProvider,
  ThemeClassNames,
  useWindowSize,
} from '@docusaurus/theme-common';
import Layout from '@theme/Layout';
import MDXContent from '@theme/MDXContent';
import TOC from '@theme/TOC';
import TOCCollapsible from '@theme/TOCCollapsible';
import ContentVisibility from '@theme/ContentVisibility';
import HomeBreadcrumbItem from '@theme/DocBreadcrumbs/Items/Home';
import Link from '@docusaurus/Link';
import { useLocation } from '@docusaurus/router';
import useDocusaurusContext from '@docusaurus/useDocusaurusContext';
import WasThisHelpful from '@site/src/components/docs/WasThisHelpful';
import MarkdownActionsDropdown from '@site/src/components/docs/MarkdownActionsDropdown';
import DownloadIcon from '@site/static/icons/download.svg';
import GiscusComponent from '@site/src/components/Giscus';
import Icon from '@site/src/components/ui/Icon';
import OriginalMDXPage from '@theme-original/MDXPage';

import styles from './styles.module.css';

function MDXPageBreadcrumbs({ title, frontMatter }) {
  const pdfUrl = frontMatter?.pdf;

  return (
    <div className="markdown-actions-breadcrumbs-row">
      <nav
        className={clsx(
          ThemeClassNames.docs.docBreadcrumbs,
          styles.breadcrumbsContainer,
        )}
        aria-label="Breadcrumbs">
        <div className={styles.breadcrumbsInner}>
          <ul className="breadcrumbs">
            <HomeBreadcrumbItem />
            <li className="breadcrumbs__item breadcrumbs__item--active">
              <span className="breadcrumbs__link">{title}</span>
            </li>
          </ul>
        </div>
      </nav>
      <div className="markdown-actions-container">
        <MarkdownActionsDropdown />
        {pdfUrl && (
          <a
            className="button button--outline button--secondary button--sm"
            href={pdfUrl}
            download
          >
            <DownloadIcon width={16} height={16} style={{ marginRight: '4px', verticalAlign: 'middle' }} />
            Download PDF
          </a>
        )}
      </div>
    </div>
  );
}

function MDXPageAside({ title, soloInSidebar = false }) {
  const { siteConfig } = useDocusaurusContext();
  const location = useLocation();
  const reportIssueUrl =
    siteConfig.customFields?.reportIssueUrl ??
    'https://github.com/Perfect-Abstractions/Compose/issues/new/choose';

  const reportIssueLink = (
    <Link
      href={reportIssueUrl}
      className={styles.reportLink}
      target="_blank"
      rel="noopener noreferrer">
      <Icon name="github" size={16} decorative />
      Report issue
    </Link>
  );

  return (
    <aside
      className={clsx(
        styles.aside,
        soloInSidebar && styles.asideSoloInRail,
      )}
      aria-label="Page feedback and links">
      <WasThisHelpful
        variant="aside"
        permalink={location.pathname}
        title={title}
        asideEndSlot={reportIssueLink}
      />
    </aside>
  );
}

function useMDXPageTOC({ toc, frontMatter }) {
  const windowSize = useWindowSize();

  const hidden = frontMatter.hide_table_of_contents;
  const canRender = !hidden && toc.length > 0;

  const mobile = canRender ? (
    <TOCCollapsible
      toc={toc}
      minHeadingLevel={frontMatter.toc_min_heading_level}
      maxHeadingLevel={frontMatter.toc_max_heading_level}
      className={clsx(ThemeClassNames.docs.docTocMobile, styles.tocMobile)}
    />
  ) : undefined;

  const desktop =
    canRender && (windowSize === 'desktop' || windowSize === 'ssr') ? (
      <TOC
        toc={toc}
        minHeadingLevel={frontMatter.toc_min_heading_level}
        maxHeadingLevel={frontMatter.toc_max_heading_level}
        className={ThemeClassNames.docs.docTocDesktop}
      />
    ) : undefined;

  return { hidden, mobile, desktop };
}

export default function MDXPage(props) {
  const { content: MDXPageContent } = props;
  const { metadata, assets, contentTitle } = MDXPageContent;
  const { title, description, frontMatter } = metadata;
  const pageTitle = contentTitle || title;
  const { keywords, wrapperClassName } = frontMatter;
  const image = assets.image ?? frontMatter.image;

  const location = useLocation();
  const windowSize = useWindowSize();
  const isDesktop = windowSize === 'desktop' || windowSize === 'ssr';

  if (frontMatter.layout === 'default') {
    return <OriginalMDXPage {...props} />;
  }

  const toc = MDXPageContent.toc ?? [];
  const docTOC = useMDXPageTOC({ toc, frontMatter });
  const showDesktopRightColumn = isDesktop;
  const showAsideInline = !isDesktop;

  return (
    <HtmlClassNameProvider
      className={clsx(
        wrapperClassName ?? ThemeClassNames.wrapper.mdxPages,
        ThemeClassNames.page.mdxPage,
      )}>
      <Layout>
        <PageMetadata
          title={title}
          description={description}
          keywords={keywords}
          image={image}
        />
        <main className={styles.mdxPageMain}>
          <div
            className={clsx(
              'container padding-top--md padding-bottom--lg',
              styles.mdxPageContainer,
            )}>
            <div className="row">
              <div 
                className={clsx(
                  'col',
                  showDesktopRightColumn && styles.docItemCol,
                )}
              >
                <ContentVisibility metadata={metadata} />
                <article className="markdown">
                  <MDXPageBreadcrumbs title={pageTitle} frontMatter={frontMatter} />
                  {docTOC.mobile}
                  <MDXContent>
                    <MDXPageContent />
                  </MDXContent>
                  {frontMatter.enableComments !== false && (
                    <GiscusComponent />
                  )}
                  {showAsideInline && <MDXPageAside title={title} />}
                </article>
              </div>
              {showDesktopRightColumn && (
                <div className="col col--3">
                  {docTOC.desktop ? (
                    <div className={styles.docTocRail}>
                      <div
                        className={clsx(
                          styles.docTocRailScroll,
                          'thin-scrollbar',
                        )}>
                        {docTOC.desktop}
                      </div>
                      <div className={styles.docTocRailFooter}>
                        <MDXPageAside title={title} />
                      </div>
                    </div>
                  ) : (
                    <div className={styles.docAsideOnly}>
                      <MDXPageAside title={title} soloInSidebar />
                    </div>
                  )}
                </div>
              )}
            </div>
          </div>
        </main>
      </Layout>
    </HtmlClassNameProvider>
  );
}
