/**
 * Base AI Provider class
 * All provider implementations should extend this class
 */
class BaseAIProvider {
  constructor(name, config, apiKey) {
    this.name = name;
    this.config = config;
    this.apiKey = apiKey;
  }

  /**
   * Get maximum output tokens for this provider
   */
  getMaxTokens() {
    return this.config.maxTokens || 2500;
  }

  /**
   * Get rate limits for this provider
   */
  getRateLimits() {
    return {
      maxRequestsPerMinute: this.config.maxRequestsPerMinute || 10,
      maxTokensPerMinute: this.config.maxTokensPerMinute || 40000,
    };
  }

  /**
   * Build HTTP request options
   * Must be implemented by subclass
   */
  buildRequestOptions() {
    throw new Error('buildRequestOptions must be implemented by subclass');
  }

  /**
   * Build request body with prompts
   * Must be implemented by subclass
   */
  buildRequestBody(systemPrompt, userPrompt, maxTokens) {
    throw new Error('buildRequestBody must be implemented by subclass');
  }

  /**
   * Extract content and token usage from API response
   * Must be implemented by subclass
   * @returns {{content: string, tokens: number|null}|null}
   */
  extractContent(response) {
    throw new Error('extractContent must be implemented by subclass');
  }

  /**
   * Check if error is a rate limit error
   */
  isRateLimitError(error) {
    const msg = error?.message || '';
    return msg.includes('429') || msg.toLowerCase().includes('rate limit');
  }
}

module.exports = BaseAIProvider;

