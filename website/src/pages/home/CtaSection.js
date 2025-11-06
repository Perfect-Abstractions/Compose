import clsx from 'clsx';
import Link from '@docusaurus/Link';
import Heading from '@theme/Heading';
import Icon from '../../components/ui/Icon';
import styles from './ctaSection.module.css';

export default function CtaSection() {
  return (
    <section className={styles.ctaSection}>
      <div className="container">
        <div className={styles.ctaContent}>
          <Heading as="h2" className={styles.ctaTitle}>
            Ready to build with Compose?
          </Heading>
          <p className={styles.ctaDescription}>
            Start creating modular, maintainable smart contracts with our comprehensive documentation.
          </p>
          <div className={styles.ctaButtons}>
            <Link to="/docs" className={clsx(styles.ctaButton, styles.ctaPrimary)}>
              <span>Get Started</span>
              <Icon name="arrow-right" size={20} />
            </Link>
            <Link to="/docs/getting-started/quick-start" className={clsx(styles.ctaButton, styles.ctaSecondaryLight)}>
              <span>View Quick Start</span>
            </Link>
          </div>
        </div>
      </div>
    </section>
  );
}

