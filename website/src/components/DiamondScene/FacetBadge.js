import React from 'react';
import Link from '@docusaurus/Link';
import styles from './facetBadge.module.css';

export function FacetBadge({ facet, visible, onMouseEnter, onMouseLeave }) {
  return (
    <div
      className={`${styles.badgeContainer} ${visible ? styles.visible : ''}`}
      onMouseEnter={onMouseEnter}
      onMouseLeave={onMouseLeave}
    >
      <div className={styles.badgeLabel}>Active Facet</div>
      {facet && facet.path ? (
        <Link className={styles.badgeValue} to={facet.path}>
          {facet.name}
        </Link>
      ) : (
        <div className={styles.badgeValue}>{facet ? facet.name : '...'}</div>
      )}
      <div className={styles.badgeLine}></div>
    </div>
  );
}
