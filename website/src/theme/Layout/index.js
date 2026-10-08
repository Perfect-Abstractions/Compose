import React from 'react';
import Layout from '@theme-original/Layout';
import AnnouncementBanner from '@site/src/components/ui/AnnouncementBanner';

const CURRENT_BANNER = {
  id: '2026-q4-erc8153-last-call-announcement',
  message: ' ERC-8153: Facet-Based Diamonds. Review before it goes final.',
  linkHref: 'https://eips.ethereum.org/EIPS/eip-8153',
  linkLabel: 'Read here',
  persistence: 'session',
};

export default function CustomLayout(props) {
  return (
    <>
      <AnnouncementBanner
        id={CURRENT_BANNER.id}
        message={CURRENT_BANNER.message}
        linkHref={CURRENT_BANNER.linkHref}
        linkLabel={CURRENT_BANNER.linkLabel}
        persistence={CURRENT_BANNER.persistence}
      />
      <Layout {...props} />
    </>
  );
}

