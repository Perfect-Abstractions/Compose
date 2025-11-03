import React from 'react';
import Link from '@docusaurus/Link';
import clsx from 'clsx';
import styles from './styles.module.css';

export default function GradientButton({ 
  children, 
  href, 
  to,
  size = 'medium',
  variant = 'primary',
  external = false,
  className
}) {
  const buttonClasses = clsx(
    styles.gradientButton,
    styles[size],
    styles[variant],
    className
  );

  const props = external ? { href, target: '_blank', rel: 'noopener noreferrer' } : { to };

  if (href || to) {
    return (
      <Link className={buttonClasses} {...props}>
        <span className={styles.buttonContent}>{children}</span>
        <span className={styles.buttonGlow} />
      </Link>
    );
  }

  return (
    <button className={buttonClasses}>
      <span className={styles.buttonContent}>{children}</span>
      <span className={styles.buttonGlow} />
    </button>
  );
}

