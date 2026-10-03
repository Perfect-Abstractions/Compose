import Heading from '@theme/Heading';
import styles from './featuresSection.module.css';

export default function FeaturesSection() {
  const features = [
    {
      kicker: 'Design principle',
      title: 'Readable by Design',
      description: 'Keep each facet focused, self-contained, and understandable from top to bottom.',
      link: '/docs/design/written-to-be-read',
    },
    {
      kicker: 'ERC-2535 / ERC-8153',
      title: 'Diamond-Native',
      description: 'Build modular systems around the ERC-2535 Diamond architecture and its shared storage model.',
      link: '/docs/foundations/diamond-contracts',
    },
    {
      kicker: 'Architecture',
      title: 'Composable Architecture',
      description: 'Assemble systems from focused facets and modules instead of coupling functionality through inheritance.',
      link: '/docs/design/design-for-composition',
    },
    {
      kicker: 'Smart Contract Oriented Programming',
      title: 'Domain-Specific Discipline',
      description: 'Use deliberate Solidity constraints and conventions designed for the realities of smart contract development.',
      link: '/docs/design',
    },
    {
      kicker: 'Developer tooling',
      title: 'A Structured Starting Point',
      description: 'Scaffold a diamond project with the Compose CLI, then develop with the Foundry or Hardhat workflow you already use.',
      link: '/docs/getting-started/installation',
    },
    {
      kicker: 'Extensibility',
      title: 'Built to Evolve',
      description: 'Add custom facets that work with Compose modules and shared diamond storage as your system develops.',
      link: '/docs/foundations/custom-facets',
    },
  ];

  return (
    <section className={styles.featuresSection}>
      <div className="container">
        <div className={styles.sectionHeader}>
          <span className={styles.sectionBadge}>Why Compose</span>
          <Heading as="h2" className={styles.sectionTitle}>
            Architecture for evolving protocols
          </Heading>
          <p className={styles.sectionSubtitle}>
            Compose gives teams a structured foundation for building, extending, and maintaining modular smart contract systems.
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
