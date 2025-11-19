import React from 'react';
import styles from './styles.module.css';

export default function GradientText({ children, variant = 'primary' }) {
  return (
    <span className={`${styles.gradientText} ${styles[variant]}`}>
      {children}
    </span>
  );
}

