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
      title={`Smart Contract Development Framework for Diamonds`}
      description="Compose is a framework for building modular, maintainable smart contract systems with reusable facets, shared modules, and ERC-2535 Diamonds.">
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
