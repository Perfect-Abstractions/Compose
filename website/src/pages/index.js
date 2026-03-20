import useDocusaurusContext from '@docusaurus/useDocusaurusContext';
import Layout from '@theme/Layout';
import HomepageHeader from '../components/home/HomepageHeader';
import FeaturesSection from '../components/home/FeaturesSection';
import CodeShowcase from '../components/home/CodeShowcase';
import StatsSection from '../components/home/StatsSection';
import CtaSection from '../components/home/CtaSection';

export default function Home() {
  const {siteConfig} = useDocusaurusContext();
  return (
    <Layout
      title={`${siteConfig.title} - Smart Contract Library`}
      description="Compose is a smart contract library for ERC-2535 Diamonds. Build readable, composable smart contracts with onchain standard library facets.">
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
