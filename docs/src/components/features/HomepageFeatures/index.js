import clsx from 'clsx';
import Heading from '@theme/Heading';
import styles from './styles.module.css';

const FeatureList = [
  {
    title: '🎯 Read First',
    description: (
      <>
        Code written to be <strong>understood first</strong>, not just executed. 
        Every facet is self-contained and readable top-to-bottom without jumping between files.
        Understanding the code is our top priority.
      </>
    ),
  },
  {
    title: '💎 Diamond-Native',
    description: (
      <>
        Built specifically for <strong>ERC-2535 Diamonds</strong>. Deploy facets once,
        reuse them across multiple diamonds on-chain. Compose functionality through
        shared storage instead of inheritance.
      </>
    ),
  },
  {
    title: '🔧 Composition Over Inheritance',
    description: (
      <>
        Combine deployed facets instead of inheriting contracts. Use libraries to 
        integrate custom logic with <strong>Compose functionality</strong> through shared storage.
        Build complex systems from simple, reusable pieces.
      </>
    ),
  },
  {
    title: '🛡️ Intentional Simplicity',
    description: (
      <>
        We intentionally restrict Solidity features to create clearer, safer code.
        This is <strong>Smart Contract Oriented Programming (SCOP)</strong> - designed
        specifically for smart contracts, not general software.
      </>
    ),
  },
  {
    title: '📦 On-Chain Standard Library',
    description: (
      <>
        Access a growing collection of <strong>verified, audited facets</strong> deployed
        on multiple blockchains at the same addresses. ERC-20, ERC-721, access control,
        and more - ready to use.
      </>
    ),
  },
  {
    title: '🌐 Community-Driven',
    description: (
      <>
        Built with 🩵 by the community. Every contribution shapes the future of
        smart contract development. <strong>Join us</strong> in creating the standard
        library for ERC-2535 Diamonds.
      </>
    ),
  },
];

function Feature({title, description}) {
  return (
    <div className={clsx('col col--4')}>
      <div className="feature-card animate-fade-in">
        <div className="text--center padding-horiz--md">
          <div className="feature-icon">{title.split(' ')[0]}</div>
          <Heading as="h3">{title.split(' ').slice(1).join(' ')}</Heading>
          <p>{description}</p>
        </div>
      </div>
    </div>
  );
}

export default function HomepageFeatures() {
  return (
    <section className={styles.features}>
      <div className="container">
        <div className="text--center margin-bottom--xl">
          <Heading as="h2" className={styles.featuresHeading}>
            Why Compose is Different
          </Heading>
          <p className={styles.featuresDescription}>
            Forget traditional smart contract design patterns. Compose takes a radically different approach
            with Smart Contract Oriented Programming (SCOP).
          </p>
        </div>
        <div className="row">
          {FeatureList.map((props, idx) => (
            <Feature key={idx} {...props} />
          ))}
        </div>
      </div>
    </section>
  );
}
