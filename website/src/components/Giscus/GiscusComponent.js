import React from 'react';
import Giscus from "@giscus/react";
import { useColorMode } from '@docusaurus/theme-common';
import useDocusaurusContext from '@docusaurus/useDocusaurusContext';
import styles from './styles.module.css';

/**
 * Giscus comment component for blog posts
 * 
 * Configuration is read from themeConfig.giscus in docusaurus.config.js
 * The component automatically adapts to the current Docusaurus theme (light/dark mode)
 * by using Giscus's built-in themes.
 * 
 * Quick setup: Visit https://giscus.app/ to get your configuration values.
 * See GISCUS_SETUP.md for detailed instructions.
 */
export default function GiscusComponent() {
  const { colorMode } = useColorMode();
  const { siteConfig } = useDocusaurusContext();
  
  const giscusConfig = siteConfig.themeConfig?.giscus;
  
  if (!giscusConfig) {
    console.warn(
      'Giscus configuration is missing from themeConfig. ' +
      'Please ensure giscus config is set in docusaurus.config.js'
    );
    return null;
  }

  const {
    repo,
    repoId,
    category = 'Blog',
    categoryId,
    mapping = 'pathname',
    strict = '0',
    reactionsEnabled = '1',
    emitMetadata = '0',
    inputPosition = 'top',
    theme: themeConfig,
    lightTheme = 'light', // Configurable light theme
    darkTheme = 'dark',   // Configurable dark theme
    lang = 'en',
    loading = 'lazy',
    ...restConfig
  } = giscusConfig;


  // Determine theme based on color mode and configuration
  const theme = colorMode === 'dark' ? darkTheme : lightTheme;

  return (
    <div className={styles.commentsSection}>
      <h2 className={`${styles.commentsHeading} anchor`} id="comments">
        Comments
      </h2>
      <Giscus
        key={`giscus-${colorMode}`}
        repo={repo}
        repoId={repoId}
        category={category}
        categoryId={categoryId}
        mapping={mapping}
        strict={strict}
        reactionsEnabled={reactionsEnabled}
        emitMetadata={emitMetadata}
        inputPosition={inputPosition}
        theme={theme}
        lang={lang}
        loading={loading}
        crossorigin="anonymous"
        async
        {...restConfig}
      />
    </div>
  );
}
