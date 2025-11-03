import React from 'react';
import clsx from 'clsx';
import Icon from '../Icon';
import styles from './styles.module.css';

/**
 * Callout Component - Enhanced admonition-style component
 * 
 * @param {string} type - Callout type ('info', 'warning', 'danger', 'success', 'tip')
 * @param {string} title - Optional title
 * @param {ReactNode} children - Content
 * @param {boolean} icon - Show icon (default: true)
 */
export default function Callout({ 
  type = 'info', 
  title, 
  children,
  icon = true 
}) {
  const iconNames = {
    info: 'lightbulb',
    warning: 'warning',
    danger: 'no-entry',
    success: 'checkmark',
    tip: 'lightbulb',
    note: 'memo'
  };

  return (
    <div className={clsx(styles.callout, styles[`callout--${type}`])}>
      <div className={styles.calloutHeader}>
        {icon && (
          <span className={styles.calloutIcon}>
            <Icon name={iconNames[type] || iconNames.info} size={24} />
          </span>
        )}
        {title && (
          <span className={styles.calloutTitle}>{title}</span>
        )}
      </div>
      <div className={styles.calloutContent}>
        {children}
      </div>
    </div>
  );
}

