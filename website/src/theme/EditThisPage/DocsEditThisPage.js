import React from 'react';
import Link from '@docusaurus/Link';
import {useDoc} from '@docusaurus/plugin-content-docs/client';
import styles from './styles.module.css';

/**
 * DocsEditThisPage component for documentation pages
 * Uses useDoc hook to access frontMatter for "View Source" link
 * 
 * WARNING: This component should ONLY be rendered when we're certain 
 * we're in a docs page context. It will throw an error if used outside
 * the DocProvider context.
 * 
 * @param {string} editUrl - URL to edit the page
 */
export default function DocsEditThisPage({editUrl}) {
  const {frontMatter} = useDoc();
  const viewSource = frontMatter?.gitSource;

  // Nothing to show
  if (!editUrl && !viewSource) {
    return null;
  }

  return (
    <div className={styles.wrapper}>
      {viewSource && (
        <> 
          <Link
            className={styles.link}
            href={viewSource}
            target="_blank"
            rel="noopener noreferrer"
          >
            <span>View Source</span>
          </Link>
          <span className={styles.separator}>|</span>
        </>
      )}
      {editUrl && (
        <Link className={styles.link} href={editUrl}>
          <span>Edit this page</span>
        </Link>
      )}
    </div>
  );
}

