import React from 'react';
import Link from '@docusaurus/Link';
import clsx from 'clsx';
import Icon from '../../ui/Icon';
import styles from './styles.module.css';

/**
 * DocCard Component - MoneyKit-inspired documentation card
 * 
 * @param {string} title - Card title
 * @param {string} description - Card description
 * @param {string} href - Link destination
 * @param {string} icon - Icon component to display
 * @param {string} variant - Card style variant ('default', 'primary', 'secondary')
 * @param {string} size - Card size ('small', 'medium', 'large')
 * @param {boolean} external - Whether the link is external
 */
export default function DocCard({
  title,
  description,
  href,
  icon,
  variant = 'default',
  size = 'medium',
  external = false,
  children
}) {
  const CardContent = () => (
    <>
      {icon && (
        <div className={styles.docCardIcon}>
          {icon}
        </div>
      )}
      <div className={styles.docCardContent}>
        <h3 className={styles.docCardTitle}>{title}</h3>
        {description && (
          <p className={styles.docCardDescription}>{description}</p>
        )}
        {children}
      </div>
      <div className={styles.docCardArrow}>
        <Icon name="doc-card-arrow" size={16} />
      </div>
    </>
  );

  const cardClasses = clsx(
    styles.docCard,
    styles[`docCard--${variant}`],
    styles[`docCard--${size}`]
  );

  if (href) {
    return external ? (
      <a 
        href={href} 
        className={cardClasses}
        target="_blank"
        rel="noopener noreferrer"
      >
        <CardContent />
      </a>
    ) : (
      <Link to={href} className={cardClasses}>
        <CardContent />
      </Link>
    );
  }

  return (
    <div className={cardClasses}>
      <CardContent />
    </div>
  );
}

/**
 * DocCardGrid - Grid container for DocCards
 */
export function DocCardGrid({ columns = 2, children }) {
  return (
    <div 
      className={styles.docCardGrid}
      style={{ '--grid-columns': columns }}
    >
      {children}
    </div>
  );
}

