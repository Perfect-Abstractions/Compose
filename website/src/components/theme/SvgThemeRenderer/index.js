import React from 'react';
import clsx from 'clsx';
import {useColorMode} from '@docusaurus/theme-common';
import useBaseUrl from '@docusaurus/useBaseUrl';

/**
 * SvgThemeRenderer Component
 *
 * @param {string} lightSrc - Path to the SVG to display in light mode
 * @param {string} darkSrc - Path to the SVG to display in dark mode
 * @param {string} alt - Accessible description for the SVG image
 * @param {string} className - Optional className for the root element
 * @param {object} props - Additional img element props (style, loading, etc.)
 */
export default function SvgThemeRenderer({
  lightSrc,
  darkSrc,
  alt = '',
  className,
  ...props
}) {
  
  const {colorMode} = useColorMode();

  const activeSrc =
    colorMode === 'dark'
      ? darkSrc || lightSrc
      : lightSrc || darkSrc;

  if (!activeSrc) {
    return null;
  }

  const resolvedSrc = activeSrc.startsWith('/') ? useBaseUrl(activeSrc) : activeSrc;

  return (
    <img
      src={resolvedSrc}
      alt={alt}
      className={clsx(className)}
      {...props}
    />
  );
}
