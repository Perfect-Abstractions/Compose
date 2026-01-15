// @ts-check
// `@type` JSDoc annotations allow editor autocompletion and type checking
// (when paired with `@ts-check`).
// There are various equivalent ways to declare your Docusaurus config.
// See: https://docusaurus.io/docs/api/docusaurus-config

import dotenv from 'dotenv';
import {themes as prismThemes} from 'prism-react-renderer';

dotenv.config();

// This runs in Node.js - Don't use client-side code here (browser APIs, JSX...)

/** @type {import('@docusaurus/types').Config} */
const config = {
  title: 'Compose',
  tagline: 'Smart Contract Oriented Programming for ERC-2535 Diamonds',
  favicon: 'img/favicon.ico',

  // Future flags, see https://docusaurus.io/docs/api/docusaurus-config#future
  future: {
    v4: true, // Improve compatibility with the upcoming Docusaurus v4
  },

  // Set the production url of your site here
  //url: 'https://compose.diamonds/',
  url: 'https://compose.diamonds/',
  // Set the /<baseUrl>/ pathname under which your site is served
  // For GitHub pages deployment, it is often '/<projectName>/'
  baseUrl: '/',


  // Broken link handling
  onBrokenLinks: 'throw',
  themes: ['@docusaurus/theme-mermaid'],

  // Docusaurus v4-compatible location for broken Markdown links
  markdown: {
    mermaid: true,
    hooks: {
      onBrokenMarkdownLinks: 'throw',
    },
  },

  // plugins: [],

  // Even if you don't use internationalization, you can use this field to set
  // useful metadata like html lang.
  i18n: {
    defaultLocale: 'en',
    locales: ['en'],
  },

  // Custom head tags (meta tags, etc.)
  headTags: [
    {
      tagName: 'meta',
      attributes: {
        name: 'algolia-site-verification',
        content: '7742A5A0022761B1',
      },
    },
    // SEO & Social metadata
    {
      tagName: 'meta',
      attributes: {
        name: 'twitter:card',
        content: 'summary_large_image',
      },
    },
    {
      tagName: 'meta',
      attributes: {
        name: 'twitter:site',
        content: '@compose',
      },
    },
    {
      tagName: 'meta',
      attributes: {
        property: 'og:type',
        content: 'website',
      },
    },
    {
      tagName: 'script',
      attributes: {
        type: 'application/ld+json',
      },
      innerHTML: JSON.stringify({
        '@context': 'https://schema.org/',
        '@type': 'Organization',
        name: 'Compose',
        url: 'https://compose.diamonds/',
        logo: 'https://compose.diamonds/img/logo.svg',
      }),
    },
  ],

  presets: [
    [
      'classic',
      /** @type {import('@docusaurus/preset-classic').Options} */
      ({
        docs: {
          sidebarPath: './sidebars.js',
          // Please change this to your repo.
          // Remove this to remove the "edit this page" links.
          editUrl:
            'https://github.com/Perfect-Abstractions/Compose/tree/main/website/',
        },
        blog: {
          showReadingTime: true,
          feedOptions: {
            type: ['rss', 'atom'],
            xslt: true,
          },
          // Please change this to your repo.
          // Remove this to remove the "edit this page" links.
          editUrl:
            'https://github.com/Perfect-Abstractions/Compose/tree/main/website/',
          // Useful options to enforce blogging best practices
          onInlineTags: 'warn',
          onInlineAuthors: 'warn',
          onUntruncatedBlogPosts: 'warn',
        },
        // Sitemap policy
        sitemap: {
          changefreq: 'weekly',
          priority: 0.6,
          ignorePatterns: ['/tags/**'],
          filename: 'sitemap.xml',
        },
        theme: {
          customCss: ['./src/css/custom.css'],
        },
      }),
    ],
  ],

  themeConfig:
    /** @type {import('@docusaurus/preset-classic').ThemeConfig} */
    ({
      image: 'img/socialcard-compose.png',
      colorMode: {
        defaultMode: 'light',
        disableSwitch: false,
        respectPrefersColorScheme: true,
      },
      navbar: {
        title: 'Compose',
        logo: {
          alt: 'Compose Logo',
          src: 'img/logo.svg',
        },
        hideOnScroll: false,
        items: [
          {
            to: "/docs",
            position: 'left',
            label: 'Docs',
            activeBaseRegex: '/docs',
          },
          {
            to: '/blog', 
            label: 'Blog', 
            position: 'left',
            activeBaseRegex: '/blog',
          },
          // {
          //   type: 'dropdown',
          //   label: 'Resources',
          //   position: 'left',
          //   items: [
          //     {
          //       label: 'Getting Started',
          //       to: '/docs/getting-started/installation',
          //     },
          //     {
          //       label: 'Examples',
          //       to: '/',
          //     },
          //     {
          //       label: 'API Reference',
          //       to: '/',
          //     },
          //   ],
          // },
          {
            href: 'https://discord.gg/DCBD2UKbxc',
            label: 'Discord',
            position: 'right',
          },
          {
            href: 'https://github.com/Perfect-Abstractions/Compose',
            label: 'GitHub',
            position: 'right',
          },
        ],
      },
      footer: {
        style: 'dark',
        links: [
          {
            title: 'Docs',
            items: [
              {
                label: 'Getting Started',
                to: '/docs',
              },
              {
                label: 'Installation',
                to: '/docs/getting-started/installation',
              },
            ],
          },
          {
            title: 'Community',
            items: [
              {
                label: 'Discord',
                href: 'https://discord.gg/DCBD2UKbxc',
              },
              {
                label: 'GitHub Discussions',
                href: 'https://github.com/Perfect-Abstractions/Compose/discussions',
              },
            ],
          },
          {
            title: 'More',
            items: [
              {
                label: 'Blog',
                to: '/blog',
              },
              {
                label: 'GitHub',
                href: 'https://github.com/Perfect-Abstractions/Compose',
              },
              {
                label: 'MIT License',
                href: 'https://github.com/Perfect-Abstractions/Compose/blob/main/LICENSE.md',
              },
            ],
          },
        ],
        copyright: `Made with DELEGATECALL by the <a href="https://github.com/Perfect-Abstractions/Compose/graphs/contributors">Compose Community</a>.<br/>
          Copyright © ${new Date().getFullYear()}`,
      },
      prism: {
        theme: prismThemes.github,
        darkTheme: prismThemes.dracula,
        additionalLanguages: ['solidity'],
      },
      // Only include Algolia config if appId is available (for production)
      ...(process.env.ALGOLIA_APP_ID && {
        algolia: {
          appId: process.env.ALGOLIA_APP_ID,
          apiKey: process.env.ALGOLIA_API_KEY,
          indexName: process.env.ALGOLIA_INDEX_NAME || 'Compose',
          contextualSearch: true,
        },
      }),
      // Giscus commenting system configuration
      // See here for more information: https://github.com/giscus/giscus
      ...(process.env.GISCUS_REPO && process.env.GISCUS_REPO_ID && process.env.GISCUS_CATEGORY_ID && {
        giscus: {
          repo: process.env.GISCUS_REPO,
          repoId: process.env.GISCUS_REPO_ID,
          category: process.env.GISCUS_CATEGORY || 'Blog',
          categoryId: process.env.GISCUS_CATEGORY_ID,
          mapping: process.env.GISCUS_MAPPING || 'pathname',
          strict: process.env.GISCUS_STRICT || '0',
          reactionsEnabled: process.env.GISCUS_REACTIONS_ENABLED || '1',
          emitMetadata: process.env.GISCUS_EMIT_METADATA || '0',
          inputPosition: process.env.GISCUS_INPUT_POSITION || 'top',
          lang: process.env.GISCUS_LANG || 'en',
          loading: process.env.GISCUS_LOADING || 'lazy'
        },
      }),
      // Newsletter email collection configuratio
      ...(process.env.NEWSLETTER_FORM_ID && {
        newsletter: {
          formId: process.env.NEWSLETTER_FORM_ID,
          apiUrl: process.env.NEWSLETTER_API_URL || 'https://api.convertkit.com/v3',
        },
      }),
    }),
  plugins: [
    process.env.POSTHOG_API_KEY && [
      "posthog-docusaurus",
      {
        apiKey: process.env.POSTHOG_API_KEY,
        appUrl: 'https://compose.diamonds/54Q17895d65',
        uiHost: 'https://us.posthog.com',
        enableInDevelopment: false, 
        capturePageLeave: true,
      },
    ],
  ].filter(Boolean),
};

export default config;
