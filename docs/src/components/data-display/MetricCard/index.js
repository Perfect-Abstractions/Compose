import React from 'react';
import Icon from '../../ui/Icon';
import styles from './styles.module.css';

export default function MetricCard({ value, label, icon, trend }) {
  return (
    <div className={styles.metricCard}>
      <div className={styles.metricHeader}>
        {icon && <span className={styles.metricIcon}>{icon}</span>}
        {trend && (
          <span className={`${styles.trend} ${styles[trend.direction]}`}>
            <Icon 
              name={trend.direction === 'up' ? 'arrow-up-right' : 'arrow-down-right'} 
              size={16} 
            />{' '}
            {trend.value}
          </span>
        )}
      </div>
      <div className={styles.metricValue}>{value}</div>
      <div className={styles.metricLabel}>{label}</div>
    </div>
  );
}

