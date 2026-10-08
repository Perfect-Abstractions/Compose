import clsx from 'clsx';
import Link from '@docusaurus/Link';
import Heading from '@theme/Heading';
import styles from './ctaSection.module.css';

export default function CtaSection() {
  return (
    <section className={styles.ctaSection} aria-labelledby="cta-heading">
      <div className={clsx('container', styles.ctaContainer)}>
        <div className={styles.ctaBanner}>
          <div className={styles.ctaGlowTop} aria-hidden="true" />
          <div className={styles.ctaGlowBottom} aria-hidden="true" />
          <div className={styles.ctaArc} aria-hidden="true" />
          <div className={styles.ctaHighlight} aria-hidden="true" />
          <div className={styles.ctaNoise} aria-hidden="true" />

          <div className={styles.ctaInner}>
            <Heading as="h2" id="cta-heading" className={styles.ctaTitle}>
              Build your next system one facet at a time.
            </Heading>
            <p className={styles.ctaDescription}>
              Start with a working project, add reusable Solidity building blocks, and keep your custom logic easy to understand.
            </p>
            <div className={styles.ctaActions}>
              <Link to="/docs" className={clsx(styles.ctaButton, styles.ctaPrimaryLight)}>
                <span>Start Building</span>
                <svg
                  className={styles.ctaButtonIcon}
                  width={20}
                  height={20}
                  viewBox="0 0 20 20"
                  aria-hidden="true"
                  focusable="false">
                  <path
                    d="M7.5 5L12.5 10L7.5 15"
                    fill="none"
                    stroke="currentColor"
                    strokeWidth={2}
                    strokeLinecap="round"
                    strokeLinejoin="round"
                  />
                </svg>
              </Link>
              <Link
                to="/docs/getting-started/installation"
                className={clsx(styles.ctaButton, styles.ctaSecondaryOutline)}>
                Read the Docs
              </Link>
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}
