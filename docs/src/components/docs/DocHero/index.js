import React from 'react';
import clsx from 'clsx';
import styles from './styles.module.css';

/**
 * DocHero Component - MoneyKit-inspired hero section for documentation pages
 * 
 * @param {string} title - Hero title
 * @param {string} subtitle - Hero subtitle/description
 * @param {string} backgroundImage - URL for background image
 * @param {string} variant - Style variant ('default', 'gradient', 'dark', 'image')
 * @param {number} height - Hero height ('small', 'medium', 'large', 'full')
 * @param {ReactNode} children - Additional content
 */
export default function DocHero({
  title,
  subtitle,
  backgroundImage,
  variant = 'gradient',
  height = 'medium',
  children
}) {
  const heroStyle = backgroundImage ? {
    backgroundImage: `url(${backgroundImage})`
  } : {};

  return (
    <div 
      className={clsx(
        styles.docHero,
        styles[`docHero--${variant}`],
        styles[`docHero--${height}`],
        backgroundImage && styles['docHero--hasImage']
      )}
      style={heroStyle}
    >
      <div className={styles.docHeroOverlay}></div>
      <div className={styles.docHeroContent}>
        {title && (
          <h1 className={styles.docHeroTitle}>{title}</h1>
        )}
        {subtitle && (
          <p className={styles.docHeroSubtitle}>{subtitle}</p>
        )}
        {children}
      </div>
    </div>
  );
}

/**
 * DocHeroSection - Companion component for content below hero
 */
export function DocHeroSection({ title, children, className }) {
  return (
    <section className={clsx(styles.docHeroSection, className)}>
      {title && (
        <h2 className={styles.docHeroSectionTitle}>{title}</h2>
      )}
      {children}
    </section>
  );
}

