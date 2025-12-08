import React from 'react';
import Link from '@docusaurus/Link';
import {useDoc} from '@docusaurus/plugin-content-docs/client';
import styles from './styles.module.css';

export default function EditThisPage({editUrl}) {
  const {frontMatter} = useDoc();
  const viewSource = frontMatter?.gitSource;

  // Nothing to show
  if (!editUrl && !viewSource) {
    return null;
  }

  return (
    <div className={styles.wrapper}>
      {viewSource && (
        <Link
          className={styles.link}
          href={viewSource}
          target="_blank"
          rel="noopener noreferrer"
        >
          <span aria-hidden="true">🔗</span>
          <span>View Source</span>
        </Link>
      )}
      {editUrl && (
        <Link className={styles.link} href={editUrl}>
          <span aria-hidden="true">✏️</span>
          <span>Edit this page</span>
        </Link>
      )}
    </div>
  );
}

