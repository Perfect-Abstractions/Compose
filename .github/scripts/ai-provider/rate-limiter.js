/**
 * Rate Limiter
 * Handles request-based and token-based rate limiting
 */

class RateLimiter {
  constructor() {
    this.provider = null;
    this.lastCallTime = 0;
    this.tokenHistory = [];
    this.limits = {
      maxRequestsPerMinute: 10,
      maxTokensPerMinute: 40000,
    };
    this.tokenWindowMs = 60000; // 60 seconds
    this.safetyMargin = 0.85; // Use 85% of token budget
  }

  /**
   * Set the active provider and update rate limits
   */
  setProvider(provider) {
    this.provider = provider;
    this.limits = provider.getRateLimits();
  }

  /**
   * Estimate token usage for a request
   * Uses rough heuristic: ~4 characters per token
   */
  estimateTokenUsage(systemPrompt, userPrompt, maxTokens) {
    const inputText = (systemPrompt || '') + (userPrompt || '');
    const estimatedInputTokens = Math.ceil(inputText.length / 4);
    return estimatedInputTokens + (maxTokens || 0);
  }

  /**
   * Wait for rate limits before making a request
   */
  async waitForRateLimit(estimatedTokens) {
    const now = Date.now();

    // 1. Request-based rate limit (requests per minute)
    const minDelayMs = Math.ceil(60000 / this.limits.maxRequestsPerMinute);
    const elapsed = now - this.lastCallTime;

    if (this.lastCallTime > 0 && elapsed < minDelayMs) {
      const waitTime = minDelayMs - elapsed;
      console.log(`    ⏳ Rate limit: waiting ${Math.ceil(waitTime / 1000)}s...`);
      await this._sleep(waitTime);
    }

    // 2. Token-based rate limit
    this._cleanTokenHistory();
    const currentConsumption = this._getCurrentTokenConsumption();
    const effectiveBudget = this.limits.maxTokensPerMinute * this.safetyMargin;
    const availableTokens = effectiveBudget - currentConsumption;

    if (estimatedTokens > availableTokens) {
      const waitTime = this._calculateTokenWaitTime(estimatedTokens, currentConsumption);
      if (waitTime > 0) {
        console.log(
          `    ⏳ Token budget: ${currentConsumption.toFixed(0)}/${effectiveBudget.toFixed(0)} used. ` +
          `Waiting ${Math.ceil(waitTime / 1000)}s...`
        );
        await this._sleep(waitTime);
        this._cleanTokenHistory();
      }
    } else {
      console.log(
        `    📊 Token budget: ${currentConsumption.toFixed(0)}/${effectiveBudget.toFixed(0)} used, ` +
        `~${estimatedTokens} needed`
      );
    }

    this.lastCallTime = Date.now();
  }

  /**
   * Record actual token consumption after a request
   */
  recordTokenConsumption(tokens) {
    this.tokenHistory.push({
      timestamp: Date.now(),
      tokens: tokens,
    });
    this._cleanTokenHistory();
  }

  /**
   * Clean expired entries from token history
   */
  _cleanTokenHistory() {
    const now = Date.now();
    this.tokenHistory = this.tokenHistory.filter(
      entry => (now - entry.timestamp) < this.tokenWindowMs
    );
  }

  /**
   * Get current token consumption in the rolling window
   */
  _getCurrentTokenConsumption() {
    return this.tokenHistory.reduce((sum, entry) => sum + entry.tokens, 0);
  }

  /**
   * Calculate how long to wait for token budget to free up
   */
  _calculateTokenWaitTime(tokensNeeded, currentConsumption) {
    const effectiveBudget = this.limits.maxTokensPerMinute * this.safetyMargin;
    const availableTokens = effectiveBudget - currentConsumption;

    if (tokensNeeded <= availableTokens) {
      return 0;
    }

    if (this.tokenHistory.length === 0) {
      return 0;
    }

    // Find how many tokens need to expire
    const tokensToFree = tokensNeeded - availableTokens;
    let freedTokens = 0;
    let oldestTimestamp = Date.now();

    for (const entry of this.tokenHistory) {
      freedTokens += entry.tokens;
      oldestTimestamp = entry.timestamp;

      if (freedTokens >= tokensToFree) {
        break;
      }
    }

    // Calculate wait time until that entry expires
    const timeUntilExpiry = this.tokenWindowMs - (Date.now() - oldestTimestamp);
    return Math.max(0, timeUntilExpiry + 2000); // Add 2s buffer
  }

  async _sleep(ms) {
    return new Promise(resolve => setTimeout(resolve, ms));
  }
}

module.exports = RateLimiter;

