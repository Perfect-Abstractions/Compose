import React from 'react';
import Link from '@docusaurus/Link';
import styles from './styles.module.css';

/**
 * Simple EditThisPage component for non-docs contexts (blog, etc.)
 * Safe to use anywhere - doesn't require any special context
 * 
 * @param {string} editUrl - URL to edit the page
 */
export default function SimpleEditThisPage({editUrl}) {
  if (!editUrl) {
    return null;
  }

  return (
    <div className={styles.wrapper}>
      <Link className={styles.link} href={editUrl}>
        <span aria-hidden="true">✏️</span>
        <span>Edit this page</span>
      </Link>
    </div>
  );
}

