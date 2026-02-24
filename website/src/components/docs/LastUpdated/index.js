import React from 'react';
import Icon from '../../ui/Icon';
import styles from './styles.module.css';

/**
 * LastUpdated Component - Display page last updated date
 * 
 * @param {string} date - Date string or Date object
 * @param {string} author - Optional author name
 * @param {boolean} showAuthor - Show author name (default: false)
 */
export default function LastUpdated({ 
  date,
  author,
  showAuthor = false
}) {
  if (!date) return null;

  const formatDate = (dateValue) => {
    const d = new Date(dateValue);
    return d.toLocaleDateString('en-US', {
      year: 'numeric',
      month: 'long',
      day: 'numeric'
    });
  };

  return (
    <div className={styles.lastUpdated}>
      <Icon name="clock-outline" size={16} />
      <span className={styles.label}>Last updated:</span>
      <time className={styles.date} dateTime={new Date(date).toISOString()}>
        {formatDate(date)}
      </time>
      {showAuthor && author && (
        <>
          <span className={styles.separator}>•</span>
          <span className={styles.author}>by {author}</span>
        </>
      )}
    </div>
  );
}





