import React from 'react';
import Icon from '../../ui/Icon';
import styles from './styles.module.css';

export default function Timeline({ items }) {
  return (
    <div className={styles.timeline}>
      {items.map((item, index) => (
        <div key={index} className={styles.timelineItem}>
          <div className={styles.timelineMarker}>
            <div className={styles.timelineDot}>
              {item.icon || <Icon name="dot" size={12} />}
            </div>
            {index < items.length - 1 && <div className={styles.timelineLine} />}
          </div>
          <div className={styles.timelineContent}>
            {item.date && <div className={styles.timelineDate}>{item.date}</div>}
            <h3 className={styles.timelineTitle}>{item.title}</h3>
            <div className={styles.timelineDescription}>{item.description}</div>
          </div>
        </div>
      ))}
    </div>
  );
}

