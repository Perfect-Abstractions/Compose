/**
 * AI Provider Service
 * Simple, configurable AI service supporting multiple providers
 * 
 * Usage:
 *   const ai = require('./ai-provider');
 *   const response = await ai.call(systemPrompt, userPrompt);
 * 
 * Environment Variables:
 *   AI_PROVIDER - 'github' | 'gemini' | 'auto' (default: auto)
 *   AI_MODEL - Override default model
 *   GITHUB_TOKEN - For GitHub Models
 *   GOOGLE_AI_API_KEY - For Gemini
 */

const { getProvider } = require('./provider-factory');
const RateLimiter = require('./rate-limiter');

class AIProvider {
  constructor() {
    this.provider = null;
    this.rateLimiter = new RateLimiter();
    this.initialized = false;
  }

  /**
   * Initialize the provider (lazy loading)
   */
  _init() {
    if (this.initialized) {
      return;
    }

    this.provider = getProvider();
    if (!this.provider) {
      throw new Error(
        'No AI provider available. Set AI_PROVIDER or corresponding API key.'
      );
    }

    console.log(`Using AI provider: ${this.provider.name}`);
    console.log(`Provider model: ${this.provider.model}`);

    this.rateLimiter.setProvider(this.provider);
    this.initialized = true;
  }

  /**
   * Make an AI call
   * 
   * @param {string} systemPrompt - System prompt
   * @param {string} userPrompt - User prompt
   * @param {object} options - Optional settings
   * @param {number} options.maxTokens - Override max tokens
   * @param {function} options.onSuccess - Success callback
   * @param {function} options.onError - Error callback
   * @returns {Promise<string>} Response text
   */
  async call(systemPrompt, userPrompt, options = {}) {
    this._init();

    const {
      maxTokens = null,
      onSuccess = null,
      onError = null,
    } = options;

    if (!systemPrompt || !userPrompt) {
      throw new Error('systemPrompt and userPrompt are required');
    }

    try {
      // Estimate tokens and wait for rate limits
      const tokensToUse = maxTokens || this.provider.getMaxTokens();
      const estimatedTokens = this.rateLimiter.estimateTokenUsage(
        systemPrompt,
        userPrompt,
        tokensToUse
      );

      await this.rateLimiter.waitForRateLimit(estimatedTokens);

      // Build and send request
      const requestBody = this.provider.buildRequestBody(systemPrompt, userPrompt, tokensToUse);
      const requestOptions = this.provider.buildRequestOptions();

      const response = await this._makeRequest(requestOptions, requestBody);

      // Extract content
      const extracted = this.provider.extractContent(response);
      if (!extracted) {
        throw new Error('Invalid response format from API');
      }

      // Record actual token usage
      const actualTokens = extracted.tokens || estimatedTokens;
      this.rateLimiter.recordTokenConsumption(actualTokens);

      if (onSuccess) {
        onSuccess(extracted.content, actualTokens);
      }

      return extracted.content;

    } catch (error) {
      console.error(`    ❌ AI call failed: ${error.message}`);

      if (onError) {
        onError(error);
      }

      throw error;
    }
  }

  /**
   * Make HTTPS request
   */
  async _makeRequest(options, body) {
    const { makeHttpsRequest } = require('../workflow-utils');
    return await makeHttpsRequest(options, body);
  }

  /**
   * Get provider info
   */
  getProviderInfo() {
    this._init();
    return {
      name: this.provider.name,
      limits: this.provider.getRateLimits(),
      maxTokens: this.provider.getMaxTokens(),
    };
  }
}

module.exports = new AIProvider();