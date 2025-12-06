/**
 * Configuration for documentation generation
 * 
 * Centralized configuration for paths, settings, and defaults.
 * Modify this file to change documentation output paths or behavior.
 */

module.exports = {
  // Input paths
  forgeDocsDir: 'docs/src/src',
  
  // Output paths for generated documentation
  facetsOutputDir: 'website/docs/contracts/facets',
  modulesOutputDir: 'website/docs/contracts/modules',
  
  // Template settings
  defaultSidebarPosition: 99,
  
  // GitHub Models API settings (for optional AI enhancement)
  // Uses Azure AI inference endpoint with GitHub token auth in Actions
  // See: https://github.blog/changelog/2025-04-14-github-actions-token-integration-now-generally-available-in-github-models/
  models: {
    host: 'models.inference.ai.azure.com',
    model: 'gpt-4o',
    maxTokens: 2000,
  },
};

