import React from 'react';
import Icon from '../../ui/Icon';
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
      <Icon name="clock-outline" size={16} />
      <span>{minutes} {timeText} read</span>
    </div>
  );
}





