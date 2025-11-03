import React from 'react';
import clsx from 'clsx';
import styles from './styles.module.css';

export default function GlassCard({ children, hover = true, className }) {
  return (
    <div className={clsx(
      styles.glassCard,
      hover && styles.hover,
      className
    )}>
      {children}
    </div>
  );
}

