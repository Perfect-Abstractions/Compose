/**
 * Provider Factory
 * Creates the appropriate AI provider based on environment variables
 */

const { createGitHubProvider } = require('./providers/github-models');
const { createGeminiProvider } = require('./providers/gemini');

/**
 * Get the active AI provider based on environment configuration
 * 
 * Environment variables:
 * - AI_PROVIDER: 'github' | 'gemini' | 'auto' (default: 'auto')
 * - AI_MODEL: Override default model for the provider
 * - GITHUB_TOKEN: API key for GitHub Models
 * - GOOGLE_AI_API_KEY: API key for Gemini
 * 
 * @returns {BaseAIProvider|null} Provider instance or null if none available
 */
function getProvider() {
  const providerName = (process.env.AI_PROVIDER || 'auto').toLowerCase();
  const customModel = process.env.AI_MODEL;

  if (providerName === 'auto') {
    return autoDetectProvider(customModel);
  }

  switch (providerName) {
    case 'github':
    case 'github-models':
      return createGitHubProvider(customModel);

    case 'gemini':
    case 'google':
      return createGeminiProvider(customModel);

    default:
      console.warn(`⚠️  Unknown provider: ${providerName}. Falling back to auto-detect.`);
      return autoDetectProvider(customModel);
  }
}

/**
 * Auto-detect provider based on available API keys
 */
function autoDetectProvider(customModel) {
  // Try Gemini
  const geminiProvider = createGeminiProvider(customModel);
  if (geminiProvider) {
    return geminiProvider;
  }

  // Fallback to GitHub Models (free in GitHub Actions)
  const githubProvider = createGitHubProvider(customModel);
  if (githubProvider) {
    return githubProvider;
  }

  return null;
}

module.exports = {
  getProvider,
};

