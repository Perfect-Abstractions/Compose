import React from 'react';
import clsx from 'clsx';
import Icon from '../Icon';
import styles from './styles.module.css';

const iconNames = {
  info: 'lightbulb',
  tip: 'sparkles',
  warning: 'warning',
  danger: 'siren',
  success: 'checkmark',
  note: 'memo',
};

export default function CalloutBox({ children, type = 'info', title }) {
  return (
    <div className={clsx(styles.callout, styles[type])}>
      <div className={styles.calloutHeader}>
        <span className={styles.calloutIcon}>
          <Icon name={iconNames[type]} size={24} />
        </span>
        <span className={styles.calloutTitle}>
          {title || type.charAt(0).toUpperCase() + type.slice(1)}
        </span>
      </div>
      <div className={styles.calloutContent}>
        {children}
      </div>
    </div>
  );
}

