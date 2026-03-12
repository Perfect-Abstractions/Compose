import React from 'react';
import Link from '@docusaurus/Link';
import Icon from '../../ui/Icon';
import styles from './styles.module.css';

/**
 * RelatedDocs Component - Related articles section
 * 
 * @param {Array} items - Array of related doc items { title, href, description }
 * @param {string} title - Section title (default: 'Related Documentation')
 */
export default function RelatedDocs({ 
  items = [],
  title = 'Related Documentation'
}) {
  if (!items || items.length === 0) return null;

  return (
    <div className={styles.relatedDocs}>
      <h3 className={styles.relatedDocsTitle}>{title}</h3>
      <div className={styles.relatedDocsGrid}>
        {items.map((item, index) => (
          <Link
            key={index}
            to={item.href}
            className={styles.relatedDocCard}
          >
            {item.icon && (
              <div className={styles.relatedDocIcon}>{item.icon}</div>
            )}
            <div className={styles.relatedDocContent}>
              <h4 className={styles.relatedDocTitle}>{item.title}</h4>
              {item.description && (
                <p className={styles.relatedDocDescription}>{item.description}</p>
              )}
            </div>
            <Icon name="arrow-right-stroke" size={20} className={styles.relatedDocArrow} />
          </Link>
        ))}
      </div>
    </div>
  );
}





