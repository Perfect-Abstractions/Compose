import Heading from '@theme/Heading';
import styles from './featuresSection.module.css';

export default function FeaturesSection() {
  const features = [
    {
      kicker: 'Design principle',
      title: 'Read First',
      description: 'Code written to be understood first, not just executed. Every facet is self-contained and readable top-to-bottom.',
      link: '/docs/design/written-to-be-read',
    },
    {
      kicker: 'ERC-2535',
      title: 'Diamond-Native',
      description: 'Built specifically for ERC-2535 Diamonds. Deploy facets once, reuse them across multiple diamonds onchain.',
      link: '/docs/foundations/diamond-contracts',
    },
    {
      kicker: 'Architecture',
      title: 'Composition Over Inheritance',
      description: 'Combine deployed facets instead of inheriting contracts. Build systems from simple, reusable pieces.',
      link: '/docs/design/design-for-composition',
    },
    {
      kicker: 'SCOP',
      title: 'Intentional Simplicity',
      description: 'Smart Contract Oriented Programming (SCOP) - designed specifically for smart contracts, not general software.',
      link: '/docs/design',
    },
    {
      kicker: 'Roadmap',
      title: 'On-chain Standard Library',
      description: '(In the future) Access verified, audited facets deployed on multiple blockchains.',
      link: '/docs/foundations/onchain-contract-library',
    },
    {
      kicker: 'Ecosystem',
      title: 'Community-Driven',
      description: 'Built with love by the community. Join us in creating the standard library for ERC-2535 Diamonds.',
      link: '/docs/contribution/how-to-contribute',
    },
  ];

  return (
    <section className={styles.featuresSection}>
      <div className="container">
        <div className={styles.sectionHeader}>
          <span className={styles.sectionBadge}>Why Compose</span>
          <Heading as="h2" className={styles.sectionTitle}>
            Rethinking Smart Contract Development
          </Heading>
          <p className={styles.sectionSubtitle}>
            Forget traditional smart contract design patterns. Compose takes a radically
            different approach with Smart Contract Oriented Programming.
          </p>
          <br />
          <p className={styles.sectionSubtitle}>
          We focus on building small, independent, and easy-to-understand smart contracts called <b>facets</b>.
          Each facet is designed to be deployed once, then reused and composed seamlessly with others to form
          complete smart contract systems.
          </p>
        </div>
        <div className={styles.featuresGrid}>
          {features.map((feature) => (
            <a
              href={feature.link}
              key={feature.title}
              className={styles.featureCardLink}
            >
              <article className={styles.featureCard}>
                <header className={styles.featureMeta}>
                  <span className={styles.featureKicker}>{feature.kicker}</span>
                </header>
                <h3 className={styles.featureTitle}>{feature.title}</h3>
                <p className={styles.featureDescription}>{feature.description}</p>
                <span className={styles.featureHint}>
                  <span className={styles.featureHintLabel}>Open in docs</span>
                  <span className={styles.featureHintArrow} aria-hidden="true">
                    →
                  </span>
                </span>
              </article>
            </a>
          ))}
        </div>
      </div>
    </section>
  );
}
