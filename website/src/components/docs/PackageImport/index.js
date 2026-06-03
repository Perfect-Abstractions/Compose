import React, { useState } from 'react';
import styles from './styles.module.css';

function getRelativePath(gitSource) {
  const marker = '/tree/main/src/';
  const idx = gitSource.indexOf(marker);
  if (idx === -1) return '';
  const after = gitSource.slice(idx + marker.length);
  return after;
}

export default function PackageImport({ gitSource }) {
  const [copied, setCopied] = useState(false);

  if (!gitSource) return null;

  const relPath = getRelativePath(gitSource);

  const handleCopy = async () => {
    try {
      await navigator.clipboard.writeText(`@perfect-abstractions/compose/${relPath}`);
      setCopied(true);
      setTimeout(() => setCopied(false), 2000);
    } catch {
      // silent
    }
  };

  return (
    <div className={styles.packageImport}>
      <code className={styles.code}>
       {`@perfect-abstractions/compose/${relPath}`}
      </code>
      <button
        className={styles.copyButton}
        onClick={handleCopy}
        aria-label="Copy import"
        title="Copy import"
      >
        {copied ? '✓ Copied' : 'Copy'}
      </button>
    </div>
  );
}
