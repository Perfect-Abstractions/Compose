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

// Logo as PNG data URI (Satori does not reliably render SVG in img; use pre-generated PNG)
const logoPngPath = path.join(__dirname, '../static/img/logo-og-white.png');
let logoDataUri = null;
function getLogoDataUri() {
  if (logoDataUri !== null) return logoDataUri;
  try {
    const png = fs.readFileSync(logoPngPath);
    logoDataUri = 'data:image/png;base64,' + png.toString('base64');
  } catch (_) {
    logoDataUri = '';
  }
  return logoDataUri;
}

function truncateTitle(title, maxChars = 60) {
  if (!title || typeof title !== 'string') return 'Compose';
  const t = title.trim();
  if (t.length <= maxChars) return t;
  return t.slice(0, maxChars - 3).trim() + '...';
}

// Same blue gradient as default socialcard-compose.png: dark (top-left) to medium blue (bottom-right)
const BACKGROUND_GRADIENT = 'linear-gradient(135deg, #0F172A 0%, #1A3B8A 100%)';

function buildLayout(title, subtitle = 'Smart Contract Oriented Programming for ERC-2535 Diamonds') {
  const logoSrc = getLogoDataUri();
  return React.createElement(
    'div',
    {
      style: {
        display: 'flex',
        flexDirection: 'column',
        width: '100%',
        height: '100%',
        background: BACKGROUND_GRADIENT,
        color: '#ffffff',
        fontFamily: 'Inter',
        padding: 80,
        justifyContent: 'center',
      },
    },
    // Logo + "Compose" in one row (like default social card)
    React.createElement(
      'div',
      {
        style: {
          display: 'flex',
          flexDirection: 'row',
          alignItems: 'center',
          marginBottom: 32,
          gap: 20,
        },
      },
      logoSrc
        ? React.createElement('img', {
            src: logoSrc,
            width: 100,
            height: 100,
            style: { display: 'flex' },
          })
        : null,
      React.createElement(
        'div',
        {
          style: {
            fontSize: 56,
            fontWeight: 600,
            opacity: 0.95,
          },
        },
        'Compose'
      )
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
              fontSize: 26,
              opacity: 0.95,
              lineHeight: 1.5,
              maxWidth: 880,
              marginTop: 1,
            },
          },
          typeof subtitle === 'string' && subtitle.length > 140 ? subtitle.slice(0, 140).trim() + '...' : subtitle
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
