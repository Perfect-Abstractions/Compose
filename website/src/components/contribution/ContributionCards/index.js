import React from 'react';
import Link from '@docusaurus/Link';
import SvgThemeRenderer from '@site/src/components/theme/SvgThemeRenderer';
import styles from './styles.module.css';

/**
 * ContributionCard
 * 
 * @param {string} title - Card title
 * @param {string} description - Card description
 * @param {string} href - Link destination
 * @param {string} kicker - Small label above title (e.g., "Solidity", "Node.js")
 * @param {string} kickerLogo - Path to logo displayed beside kicker text
 * @param {string} kickerLogoDark - Path to logo for dark mode
 * @param {string[]} tags - Array of tag labels
 */
export default function ContributionCard({
  title,
  description,
  href,
  kicker,
  kickerLogo,
  kickerLogoDark,
  tags
}) {
  return (
    <Link to={href} className={styles.contributionCard}>
      <header className={styles.cardMeta}>
        {kickerLogo && (
          <SvgThemeRenderer
            lightSrc={kickerLogo}
            darkSrc={kickerLogoDark}
            alt=""
            className={styles.kickerLogo}
            aria-hidden="true"
          />
        )}
        <span className={styles.kicker}>{kicker}</span>
      </header>
      <h3 className={styles.cardTitle}>{title}</h3>
      <p className={styles.cardDescription}>{description}</p>
      {tags && (
        <div className={styles.tags}>
          {tags.map((tag) => (
            <span key={tag} className={styles.tag}>
              {tag}
            </span>
          ))}
        </div>
      )}
      <span className={styles.cardLinkHint}>
        <span className={styles.cardLinkLabel}>Get started</span>
        <span className={styles.cardLinkArrow} aria-hidden="true">→</span>
      </span>
    </Link>
  );
}

/**
 * ContributionCardGrid - Grid container for ContributionCards
 */
export function ContributionCardGrid({ columns = 2, children }) {
  return (
    <div 
      className={styles.contributionCardGrid}
      style={{ '--grid-columns': columns }}
    >
      {children}
    </div>
  );
}
