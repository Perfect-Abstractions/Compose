'use strict';

const fs = require('fs');
const path = require('path');
const React = require('react');

const WIDTH = 1200;
const HEIGHT = 630;

// Inter from @fontsource (woff); Satori accepts ArrayBuffer
const fontPath = path.join(__dirname, '../node_modules/@fontsource/inter/files/inter-latin-400-normal.woff');
const fontData = fs.readFileSync(fontPath);
const fontBuffer = fontPath.endsWith('.woff2')
  ? fontData.buffer
  : fontData; // Node Buffer works as ArrayBuffer for Satori

const fontConfig = [
  {
    name: 'Inter',
    data: fontBuffer,
    weight: 400,
    style: 'normal',
  },
];

const options = {
  width: WIDTH,
  height: HEIGHT,
  fonts: fontConfig,
};

function truncateTitle(title, maxChars = 60) {
  if (!title || typeof title !== 'string') return 'Compose';
  const t = title.trim();
  if (t.length <= maxChars) return t;
  return t.slice(0, maxChars - 3).trim() + '...';
}

function buildLayout(title, subtitle = 'Smart Contract Oriented Programming for ERC-2535 Diamonds') {
  return React.createElement(
    'div',
    {
      style: {
        display: 'flex',
        flexDirection: 'column',
        width: '100%',
        height: '100%',
        background: 'linear-gradient(135deg, #0f172a 0%, #1e293b 100%)',
        color: '#f8fafc',
        fontFamily: 'Inter',
        padding: 80,
        justifyContent: 'center',
      },
    },
    React.createElement(
      'div',
      {
        style: {
          fontSize: 28,
          marginBottom: 24,
          opacity: 0.9,
        },
      },
      'Compose'
    ),
    React.createElement(
      'div',
      {
        style: {
          fontSize: 56,
          fontWeight: 700,
          lineHeight: 1.2,
          marginBottom: 16,
        },
      },
      truncateTitle(title)
    ),
    subtitle
      ? React.createElement(
          'div',
          {
            style: {
              fontSize: 24,
              opacity: 0.85,
              lineHeight: 1.4,
              maxWidth: 900,
            },
          },
          typeof subtitle === 'string' && subtitle.length > 120 ? subtitle.slice(0, 120) + '...' : subtitle
        )
      : null
  );
}

/**
 * Docs image renderer. Receives { metadata, version, plugin, document, websiteOutDir }, context.
 */
function docs(data, context) {
  const title = data.metadata?.title ?? 'Compose';
  const description = data.metadata?.description ?? null;
  return [buildLayout(title, description), options];
}

/**
 * Blog image renderer. Receives { data, plugin, pageType, permalink, document, websiteOutDir }, context.
 * Only meaningful for pageType 'post'; list/tags/archive may use default or skip.
 */
function blog(data, context) {
  const isPost = data.pageType === 'post';
  const title = isPost
    ? (data.data?.metadata?.title ?? data.data?.title ?? 'Compose')
    : (data.data?.label ?? data.data?.title ?? 'Blog');
  const description = isPost && data.data?.metadata?.description ? data.data.metadata.description : null;
  return [buildLayout(title, description), options];
}

module.exports = { docs, blog };
