import useDocusaurusContext from '@docusaurus/useDocusaurusContext';
import Layout from '@theme/Layout';
import HomepageHeader from './home/HomepageHeader';
import FeaturesSection from './home/FeaturesSection';
import CodeShowcase from './home/CodeShowcase';
import StatsSection from './home/StatsSection';
import CtaSection from './home/CtaSection';

export default function Home() {
  const {siteConfig} = useDocusaurusContext();
  return (
    <Layout
      title={`${siteConfig.title} - Smart Contract Library`}
      description="Compose is a smart contract library for ERC-2535 Diamonds. Build readable, composable smart contracts with on-chain standard library facets.">
      <HomepageHeader />
      <main>
        <FeaturesSection />
        <CodeShowcase />
        <StatsSection />
        <CtaSection />
      </main>
    </Layout>
  );
}
