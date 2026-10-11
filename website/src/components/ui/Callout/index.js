import React from 'react';
import clsx from 'clsx';
import styles from './styles.module.css';

const TYPES = ['info', 'tip', 'warning', 'danger', 'success', 'note', 'important'];

/**
 * Callout Component - Enhanced admonition-style component
 *
 * @param {string} type - Callout type ('info', 'tip', 'warning', 'danger', 'success', 'note', 'important')
 * @param {string} title - Optional title
 * @param {ReactNode} children - Content
 * @param {boolean} collapsible - Render as expandable disclosure (default: false)
 * @param {boolean} defaultOpen - Expanded by default (collapsible only, default: false)
 * @param {string} className - Optional extra class
 */
export default function Callout({
  type = 'info',
  title,
  children,
  collapsible = false,
  defaultOpen = false,
  className,
}) {
  const resolvedType = TYPES.includes(type) ? type : 'info';

  const classes = clsx(
    'theme-admonition',
    `theme-admonition-${resolvedType}`,
    styles.callout,
    collapsible && styles.calloutCollapsible,
    className,
  );

  if (collapsible) {
    const label = title || resolvedType.charAt(0).toUpperCase() + resolvedType.slice(1);
    return (
      <aside role="note" className={classes}>
        <details open={defaultOpen || undefined}>
          <summary className={styles.calloutHeader}>
            <span className={styles.calloutTitle}>{label}</span>
            <span className={styles.calloutChevron} aria-hidden="true" />
          </summary>
          <div className={styles.calloutContent}>{children}</div>
        </details>
      </aside>
    );
  }

  return (
    <aside role="note" className={classes}>
      {title && (
        <div className={styles.calloutHeader}>
          <span className={styles.calloutTitle}>{title}</span>
        </div>
      )}
      <div className={styles.calloutContent}>{children}</div>
    </aside>
  );
}
