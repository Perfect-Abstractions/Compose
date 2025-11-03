import React from 'react';
import clsx from 'clsx';
import styles from './styles.module.css';

export default function Badge({ children, variant = 'primary', size = 'medium' }) {
  return (
    <span className={clsx(
      styles.badge,
      styles[variant],
      styles[size]
    )}>
      {children}
    </span>
  );
}

