import React from 'react';
import Head from '@docusaurus/Head';
import { useDoc } from '@docusaurus/plugin-content-docs/client';
import useDocusaurusContext from '@docusaurus/useDocusaurusContext';

export default function DocItemStructuredData() {
  const { metadata, frontMatter } = useDoc();
  const { siteConfig } = useDocusaurusContext();
  const { title, description, permalink, lastUpdate } = metadata;
  const siteUrl = siteConfig.url.endsWith('/') ? siteConfig.url : `${siteConfig.url}/`;

  const structuredData = {
    '@context': 'https://schema.org/',
    '@type': 'TechArticle',
    headline: title,
    description: description || frontMatter.description || '',
    url: `${siteUrl}${permalink.startsWith('/') ? permalink.slice(1) : permalink}`,
    mainEntityOfPage: {
      '@type': 'WebPage',
      '@id': `${siteUrl}${permalink.startsWith('/') ? permalink.slice(1) : permalink}`,
    },
    author: {
      '@type': 'Organization',
      name: siteConfig.title,
      url: siteUrl,
    },
    publisher: {
      '@type': 'Organization',
      name: siteConfig.title,
      url: siteUrl,
      logo: {
        '@type': 'ImageObject',
        url: `${siteUrl}${siteConfig.themeConfig.image}`,
      },
    },
    ...(lastUpdate && {
      dateModified: new Date(lastUpdate).toISOString(),
    }),
    inLanguage: 'en',
    programmingLanguage: 'Solidity',
  };

  return (
    <Head>
      <script type="application/ld+json">
        {JSON.stringify(structuredData)}
      </script>
    </Head>
  );
}
