import React from 'react';
import styles from './facetBadge.module.css';

export function FacetBadge({ name, visible }) {
  return (
    <div className={`${styles.badgeContainer} ${visible ? styles.visible : ''}`}>
      <div className={styles.badgeLabel}>Active Facet</div>
      <div className={styles.badgeValue}>{name || '...'}</div>
      <div className={styles.badgeLine}></div>
    </div>
  );
}

