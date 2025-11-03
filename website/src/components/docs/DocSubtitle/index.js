import React from 'react';
import clsx from 'clsx';
import styles from './styles.module.css';

export default function DocSubtitle({ children, className }) {
  return (
    <p className={clsx(styles.subtitle, className)}>
      {children}
    </p>
  );
}


