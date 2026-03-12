import React from 'react';
import { useBlogPost } from '@docusaurus/plugin-content-blog/client';
import BlogPostItem from '@theme-original/BlogPostItem';
import GiscusComponent from '@site/src/components/Giscus';
import NewsletterSignup from '@site/src/components/newsletter/NewsletterSignup';

export default function BlogPostItemWrapper(props) {
  const { metadata, isBlogPostPage } = useBlogPost();

  const { frontMatter } = metadata;
  const { enableComments, enableNewsletter } = frontMatter;

  return (
    <>
      <BlogPostItem {...props} />
      {(enableComments !== false && isBlogPostPage) && (
        <GiscusComponent />
      )}
      {(enableNewsletter !== false && isBlogPostPage) && (
        <NewsletterSignup 
          title="Stay Updated"
          description="Get notified about releases, feature announcements, and technical deep-dives on building smart contracts with Compose."
        />
      )}
    </>
  );
}
