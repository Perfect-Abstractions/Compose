import Heading from '@theme/Heading';
import Icon from '../../components/ui/Icon';
import styles from './featuresSection.module.css';

export default function FeaturesSection() {
  const features = [
    {
      icon: 'read-first',
      title: 'Read First',
      description: 'Code written to be understood first, not just executed. Every facet is self-contained and readable top-to-bottom.',
    },
    {
      icon: 'diamond-native',
      title: 'Diamond-Native',
      description: 'Built specifically for ERC-2535 Diamonds. Deploy facets once, reuse them across multiple diamonds on-chain.',
    },
    {
      icon: 'composition',
      title: 'Composition Over Inheritance',
      description: 'Combine deployed facets instead of inheriting contracts. Build complex systems from simple, reusable pieces.',
    },
    {
      icon: 'simplicity',
      title: 'Intentional Simplicity',
      description: 'Smart Contract Oriented Programming (SCOP) - designed specifically for smart contracts, not general software.',
    },
    {
      icon: 'library',
      title: 'On-Chain Standard Library',
      description: 'Access verified, audited facets deployed on multiple blockchains. ERC-20, ERC-721, access control, and more.',
    },
    {
      icon: 'community',
      title: 'Community-Driven',
      description: 'Built with love by the community. Join us in creating the standard library for ERC-2535 Diamonds.',
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
        </div>
        <div className={styles.featuresGrid}>
          {features.map((feature) => (
            <div key={feature.title} className={styles.featureCard}>
              <div className={styles.featureIcon}>
                <Icon name={feature.icon} size={32} />
              </div>
              <h3 className={styles.featureTitle}>{feature.title}</h3>
              <p className={styles.featureDescription}>{feature.description}</p>
            </div>
          ))}
        </div>
      </div>
    </section>
  );
}



