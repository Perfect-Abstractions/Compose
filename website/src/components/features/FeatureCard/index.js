import React from 'react';
import clsx from 'clsx';
import styles from './styles.module.css';

export default function FeatureCard({ icon, title, description, gradient, link }) {
  const CardContent = (
    <div className={clsx(styles.featureCard, gradient && styles[gradient])}>
      <div className={styles.cardIcon}>{icon}</div>
      <h3 className={styles.cardTitle}>{title}</h3>
      <p className={styles.cardDescription}>{description}</p>
      {link && (
        <div className={styles.cardLink}>
          Learn more →
        </div>
      )}
    </div>
  );

  if (link) {
    return (
      <a href={link} className={styles.cardWrapper}>
        {CardContent}
      </a>
    );
  }

  return <div className={styles.cardWrapper}>{CardContent}</div>;
}

