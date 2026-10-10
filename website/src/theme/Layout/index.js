import React from 'react';
import Layout from '@theme-original/Layout';
import AnnouncementBanner from '@site/src/components/ui/AnnouncementBanner';

const CURRENT_BANNER = {
  id: 'visual-builder-launch-announcement',
  message: 'Build your diamond in the browser.',
  linkHref: 'https://app.compose.diamonds',
  linkLabel: 'Try the Builder',
  persistence: 'local',
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

