import React from 'react';
import clsx from 'clsx';
import styles from './styles.module.css';

/**
 * ReadingTime Component - Estimated reading time calculator
 * 
 * @param {string} content - Content text or ReactNode
 * @param {number} wordsPerMinute - Reading speed (default: 200)
 */
export default function ReadingTime({ 
  content,
  wordsPerMinute = 200
}) {
  const calculateReadingTime = () => {
    let text = '';
    
    if (typeof content === 'string') {
      text = content;
    } else if (content?.props?.children) {
      // Extract text from React children
      const extractText = (node) => {
        if (typeof node === 'string') return node;
        if (Array.isArray(node)) return node.map(extractText).join(' ');
        if (node?.props?.children) return extractText(node.props.children);
        return '';
      };
      text = extractText(content);
    }

    const words = text.trim().split(/\s+/).filter(word => word.length > 0).length;
    const minutes = Math.ceil(words / wordsPerMinute);
    
    return minutes;
  };

  const minutes = calculateReadingTime();
  const timeText = minutes === 1 ? 'minute' : 'minutes';

  if (minutes === 0) return null;

  return (
    <div className={styles.readingTime}>
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
      <span>{minutes} {timeText} read</span>
    </div>
  );
}





