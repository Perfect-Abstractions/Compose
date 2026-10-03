import React from 'react';
import clsx from 'clsx';
import { useDoc } from '@docusaurus/plugin-content-docs/client';
import useDocusaurusContext from '@docusaurus/useDocusaurusContext';
import EditThisPage from '@theme/EditThisPage';
import Link from '@docusaurus/Link';
import WasThisHelpful from '@site/src/components/docs/WasThisHelpful';
import Icon from '@site/src/components/ui/Icon';
import styles from './styles.module.css';

/**
 * @param {boolean} [soloInSidebar] — top of right column with no TOC above; drop extra top rule
 */
export default function DocPageAside({ soloInSidebar = false }) {
  const { metadata } = useDoc();
  const { editUrl, permalink, title } = metadata;
  const { siteConfig } = useDocusaurusContext();
  const reportIssueUrl =
    siteConfig.customFields?.reportIssueUrl ??
    'https://github.com/Perfect-Abstractions/Compose/issues/new/choose';

  const reportIssueLink = (
    <Link
      href={reportIssueUrl}
      className={styles.reportLink}
      target="_blank"
      rel="noopener noreferrer"
    >
      <Icon name="github" size={14} decorative />
      Report issue
    </Link>
  );

  return (
    <aside
      className={clsx(styles.aside, soloInSidebar && styles.asideSoloInRail)}
      aria-label="Page feedback and links"
    >
      <WasThisHelpful
        variant="aside"
        permalink={permalink}
        title={title}
        asideEndSlot={reportIssueLink}
      />
    </aside>
  );
}
