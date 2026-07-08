import useDocusaurusContext from '@docusaurus/useDocusaurusContext';
import Layout from '@theme/Layout';
import HomepageHeader from '../components/home/HomepageHeader';
import FeaturesSection from '../components/home/FeaturesSection';
import CodeShowcase from '../components/home/CodeShowcase';
import StatsSection from '../components/home/StatsSection';
import CtaSection from '../components/home/CtaSection';

export default function Home() {
  return (
    <Layout
      title={`The Composition Toolkit for ERC-2535 / ERC-8153 Diamonds`}
      description="Compose provides a facets library and developer tooling for building modular diamond systems. Assemble applications from reusable on-chain components with on-chain composition">
      <HomepageHeader />
      <main>
        <FeaturesSection />
        <CodeShowcase />
        <CtaSection />
        <StatsSection />
      </main>
    </Layout>
  );
}
