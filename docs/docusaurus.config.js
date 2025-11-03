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
  url: 'https://docusaurus-test-seven-sage.vercel.app/',
  // Set the /<baseUrl>/ pathname under which your site is served
  // For GitHub pages deployment, it is often '/<projectName>/'
  baseUrl: '/',


  // Broken link handling
  onBrokenLinks: 'throw',

  // Docusaurus v4-compatible location for broken Markdown links
  markdown: {
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
            'https://github.com/Perfect-Abstractions/Compose/tree/main/docs/',
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
            'https://github.com/Perfect-Abstractions/Compose/tree/main/blog/',
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
      image: 'img/social-card-compose.png',
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
          {
            type: 'dropdown',
            label: 'Resources',
            position: 'left',
            items: [
              {
                label: 'Getting Started',
                to: '/docs/getting-started/installation',
              },
              {
                label: 'Examples',
                to: '/',
              },
              {
                label: 'API Reference',
                to: '/',
              },
            ],
          },
          {
            href: 'https://discord.gg/compose',
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
              {
                label: 'Quick Start',
                to: '/docs/getting-started/quick-start',
              },
            ],
          },
          {
            title: 'Community',
            items: [
              {
                label: 'Discord',
                href: 'https://discord.gg/compose',
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
        copyright: `Made with DELEGATECALL by the Compose Community.<br/>
          Copyright © ${new Date().getFullYear()}`,
      },
      prism: {
        theme: prismThemes.github,
        darkTheme: prismThemes.dracula,
        additionalLanguages: ['solidity'],
      },
      algolia: {
        appId: process.env.ALGOLIA_APP_ID,
        apiKey: process.env.ALGOLIA_API_KEY,
        indexName: process.env.ALGOLIA_INDEX_NAME || 'compose',
        contextualSearch: true,
      },
    }),
};

export default config;
