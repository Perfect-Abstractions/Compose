import React from 'react';
import clsx from 'clsx';
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
      <svg width="16" height="16" viewBox="0 0 20 20" fill="none">
        <path
          d="M10 18.333a8.333 8.333 0 100-16.666 8.333 8.333 0 000 16.666z"
          stroke="currentColor"
          strokeWidth="1.5"
          strokeLinecap="round"
          strokeLinejoin="round"
        />
        <path
          d="M10 6.667v5l3.333 2"
          stroke="currentColor"
          strokeWidth="1.5"
          strokeLinecap="round"
          strokeLinejoin="round"
        />
      </svg>
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





