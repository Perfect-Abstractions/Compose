/**
 * Token-Aware Rate Limiter for GitHub Models API
 * 
 * Handles both time-based and token-based rate limiting to stay within:
 * - 10 requests per 60 seconds (request rate limit)
 * - 40,000 tokens per 60 seconds (minute-token limit)
 * - Daily limits (requests and tokens per day)
 * 
 */

const fs = require('fs');
const path = require('path');
const { sleep } = require('../workflow-utils');

// GitHub Models API Limits
const MAX_REQUESTS_PER_MINUTE = 10;
const MAX_TOKENS_PER_MINUTE = 40000;

// Daily limits (conservative estimates - adjust based on your actual tier)
// Free tier typically has lower limits, paid tiers have higher
const MAX_REQUESTS_PER_DAY = 1500; // Conservative estimate
const MAX_TOKENS_PER_DAY = 150000; // Conservative estimate

// Safety margins to avoid hitting limits
const REQUEST_SAFETY_BUFFER_MS = 1000; // Add 1s buffer to request spacing
const TOKEN_BUDGET_SAFETY_MARGIN = 0.85; // Use 85% of minute budget
const DAILY_BUDGET_SAFETY_MARGIN = 0.90; // Use 90% of daily budget

// Calculated values
const REQUEST_DELAY_MS = Math.ceil((60000 / MAX_REQUESTS_PER_MINUTE) + REQUEST_SAFETY_BUFFER_MS);
const EFFECTIVE_TOKEN_BUDGET = MAX_TOKENS_PER_MINUTE * TOKEN_BUDGET_SAFETY_MARGIN;
const EFFECTIVE_DAILY_REQUESTS = Math.floor(MAX_REQUESTS_PER_DAY * DAILY_BUDGET_SAFETY_MARGIN);
const EFFECTIVE_DAILY_TOKENS = Math.floor(MAX_TOKENS_PER_DAY * DAILY_BUDGET_SAFETY_MARGIN);
const TOKEN_WINDOW_MS = 60000; // 60 second rolling window

// State tracking (minute-level)
let lastApiCallTime = 0;
let tokenConsumptionHistory = []; // Array of { timestamp, tokens }

// Daily tracking
const DAILY_USAGE_FILE = path.join(__dirname, '.daily-usage.json');
let dailyUsage = loadDailyUsage();

/**
 * Load daily usage from file
 * @returns {object} Daily usage data
 */
function loadDailyUsage() {
  try {
    if (fs.existsSync(DAILY_USAGE_FILE)) {
      const data = JSON.parse(fs.readFileSync(DAILY_USAGE_FILE, 'utf8'));
      const today = new Date().toISOString().split('T')[0];
      
      // Reset if it's a new day
      if (data.date !== today) {
        return { date: today, requests: 0, tokens: 0 };
      }
      
      return data;
    }
  } catch (error) {
    console.warn('Could not load daily usage file:', error.message);
  }
  
  // Default: new day
  return {
    date: new Date().toISOString().split('T')[0],
    requests: 0,
    tokens: 0,
  };
}

/**
 * Save daily usage to file
 */
function saveDailyUsage() {
  try {
    fs.writeFileSync(DAILY_USAGE_FILE, JSON.stringify(dailyUsage, null, 2));
  } catch (error) {
    console.warn('Could not save daily usage file:', error.message);
  }
}

/**
 * Check if daily limits would be exceeded
 * @param {number} estimatedTokens - Tokens needed for next request
 * @returns {object} { exceeded: boolean, reason: string }
 */
function checkDailyLimits(estimatedTokens) {
  const today = new Date().toISOString().split('T')[0];
  
  // Reset if new day
  if (dailyUsage.date !== today) {
    dailyUsage = { date: today, requests: 0, tokens: 0 };
    saveDailyUsage();
  }
  
  // Check request limit
  if (dailyUsage.requests >= EFFECTIVE_DAILY_REQUESTS) {
    return {
      exceeded: true,
      reason: `Daily request limit reached (${dailyUsage.requests}/${EFFECTIVE_DAILY_REQUESTS})`,
    };
  }
  
  // Check token limit
  if (dailyUsage.tokens + estimatedTokens > EFFECTIVE_DAILY_TOKENS) {
    return {
      exceeded: true,
      reason: `Daily token limit would be exceeded (${dailyUsage.tokens + estimatedTokens}/${EFFECTIVE_DAILY_TOKENS})`,
    };
  }
  
  return { exceeded: false };
}

/**
 * Record daily usage
 * @param {number} tokens - Tokens consumed
 */
function recordDailyUsage(tokens) {
  const today = new Date().toISOString().split('T')[0];
  
  // Reset if new day
  if (dailyUsage.date !== today) {
    dailyUsage = { date: today, requests: 0, tokens: 0 };
  }
  
  dailyUsage.requests += 1;
  dailyUsage.tokens += tokens;
  saveDailyUsage();
}

/**
 * Estimate token usage for a request
 * Uses a rough heuristic: ~4 characters per token for input text
 * @param {string} systemPrompt - System prompt text
 * @param {string} userPrompt - User prompt text
 * @param {number} maxTokens - Max tokens requested for completion
 * @returns {number} Estimated total tokens (input + output)
 */
function estimateTokenUsage(systemPrompt, userPrompt, maxTokens) {
  const inputText = (systemPrompt || '') + (userPrompt || '');
  // Rough estimate: ~4 characters per token for GPT-4 models
  const estimatedInputTokens = Math.ceil(inputText.length / 4);
  // Add max_tokens for potential output (worst case: we use all requested tokens)
  return estimatedInputTokens + maxTokens;
}

/**
 * Clean expired entries from token consumption history
 * Removes entries older than TOKEN_WINDOW_MS
 */
function cleanTokenHistory() {
  const now = Date.now();
  tokenConsumptionHistory = tokenConsumptionHistory.filter(
    entry => (now - entry.timestamp) < TOKEN_WINDOW_MS
  );
}

/**
 * Get current token consumption in the rolling window
 * @returns {number} Total tokens consumed in the last 60 seconds
 */
function getCurrentTokenConsumption() {
  cleanTokenHistory();
  return tokenConsumptionHistory.reduce((sum, entry) => sum + entry.tokens, 0);
}

/**
 * Record token consumption for rate limiting
 * @param {number} tokens - Tokens consumed in the request
 */
function recordTokenConsumption(tokens) {
  tokenConsumptionHistory.push({
    timestamp: Date.now(),
    tokens: tokens,
  });
  cleanTokenHistory();
}

/**
 * Update the last recorded token consumption with actual usage from API response
 * @param {number} actualTokens - Actual tokens used (from API response)
 */
function updateLastTokenConsumption(actualTokens) {
  if (tokenConsumptionHistory.length > 0) {
    const lastEntry = tokenConsumptionHistory[tokenConsumptionHistory.length - 1];
    lastEntry.tokens = actualTokens;
  }
}

/**
 * Calculate wait time needed for token budget to free up
 * @param {number} tokensNeeded - Tokens needed for the next request
 * @param {number} currentConsumption - Current token consumption
 * @returns {number} Milliseconds to wait (0 if no wait needed)
 */
function calculateTokenWaitTime(tokensNeeded, currentConsumption) {
  const availableTokens = EFFECTIVE_TOKEN_BUDGET - currentConsumption;
  
  if (tokensNeeded <= availableTokens) {
    return 0; // No wait needed
  }
  
  // Need to wait for some tokens to expire from the rolling window
  if (tokenConsumptionHistory.length === 0) {
    return 0; // No history, shouldn't happen but handle gracefully
  }
  
  // Find how many tokens need to expire
  const tokensToFree = tokensNeeded - availableTokens;
  let freedTokens = 0;
  let oldestTimestamp = Date.now();
  
  // Walk through history from oldest to newest
  for (const entry of tokenConsumptionHistory) {
    freedTokens += entry.tokens;
    oldestTimestamp = entry.timestamp;
    
    if (freedTokens >= tokensToFree) {
      break;
    }
  }
  
  // Calculate wait time until that entry expires
  const now = Date.now();
  const timeUntilExpiry = TOKEN_WINDOW_MS - (now - oldestTimestamp);
  
  // Add small buffer to ensure the tokens have actually expired
  return Math.max(0, timeUntilExpiry + 2000);
}

/**
 * Calculate wait time for 429 rate limit recovery
 * When we hit a 429, we need to wait for enough tokens to free up from the window
 * @param {number} tokensNeeded - Tokens needed for the next request
 * @returns {number} Milliseconds to wait
 */
function calculate429WaitTime(tokensNeeded) {
  cleanTokenHistory();
  const currentConsumption = getCurrentTokenConsumption();
  const availableTokens = EFFECTIVE_TOKEN_BUDGET - currentConsumption;
  
  if (tokensNeeded <= availableTokens) {
    // We should have budget, but got 429 anyway - wait for oldest entry to expire
    if (tokenConsumptionHistory.length > 0) {
      const oldestEntry = tokenConsumptionHistory[0];
      const now = Date.now();
      const timeUntilExpiry = TOKEN_WINDOW_MS - (now - oldestEntry.timestamp);
      return Math.max(5000, timeUntilExpiry + 2000); // At least 5s, plus buffer
    }
    return 10000; // Default 10s if no history
  }
  
  // Calculate how long until we have enough budget
  return calculateTokenWaitTime(tokensNeeded, currentConsumption);
}

/**
 * Wait for rate limits if needed (both time-based and token-based)
 * This is the main entry point for rate limiting before making an API call
 * 
 * @param {number} estimatedTokens - Estimated tokens for the upcoming request
 * @returns {Promise<void>}
 */
async function waitForRateLimit(estimatedTokens) {
  const now = Date.now();
  
  // 1. Check time-based rate limit (requests per minute)
  const elapsed = now - lastApiCallTime;
  if (lastApiCallTime > 0 && elapsed < REQUEST_DELAY_MS) {
    const waitTime = REQUEST_DELAY_MS - elapsed;
    console.log(`    ⏳ Rate limit: waiting ${Math.ceil(waitTime / 1000)}s (request spacing)...`);
    await sleep(waitTime);
  }
  
  // 2. Check token-based rate limit
  cleanTokenHistory();
  const currentConsumption = getCurrentTokenConsumption();
  const availableTokens = EFFECTIVE_TOKEN_BUDGET - currentConsumption;
  
  if (estimatedTokens > availableTokens) {
    const waitTime = calculateTokenWaitTime(estimatedTokens, currentConsumption);
    
    if (waitTime > 0) {
      console.log(
        `    ⏳ Token budget: ${currentConsumption.toFixed(0)}/${EFFECTIVE_TOKEN_BUDGET.toFixed(0)} tokens used. ` +
        `Need ${estimatedTokens} tokens. Waiting ${Math.ceil(waitTime / 1000)}s for budget to reset...`
      );
      await sleep(waitTime);
      cleanTokenHistory(); // Re-clean after waiting
    }
  } else {
    const remainingTokens = availableTokens - estimatedTokens;
    console.log(
      `    📊 Token budget: ${currentConsumption.toFixed(0)}/${EFFECTIVE_TOKEN_BUDGET.toFixed(0)} used, ` +
      `~${estimatedTokens} needed, ~${remainingTokens.toFixed(0)} remaining after this request`
    );
  }
  
  // Update last call time
  lastApiCallTime = Date.now();
}

/**
 * Get current rate limiter statistics (useful for debugging/monitoring)
 * @returns {object} Statistics object
 */
function getStats() {
  cleanTokenHistory();
  const currentConsumption = getCurrentTokenConsumption();
  
  return {
    requestDelayMs: REQUEST_DELAY_MS,
    maxTokensPerMinute: MAX_TOKENS_PER_MINUTE,
    effectiveTokenBudget: EFFECTIVE_TOKEN_BUDGET,
    currentTokenConsumption: currentConsumption,
    availableTokens: EFFECTIVE_TOKEN_BUDGET - currentConsumption,
    tokenHistoryEntries: tokenConsumptionHistory.length,
    lastApiCallTime: lastApiCallTime,
    timeSinceLastCall: lastApiCallTime > 0 ? Date.now() - lastApiCallTime : null,
  };
}

/**
 * Reset rate limiter state (useful for testing)
 */
function reset() {
  lastApiCallTime = 0;
  tokenConsumptionHistory = [];
}

module.exports = {
  estimateTokenUsage,
  waitForRateLimit,
  recordTokenConsumption,
  updateLastTokenConsumption,
  getCurrentTokenConsumption,
  getStats,
  reset,
  calculate429WaitTime,
  // Export constants for testing/configuration
  MAX_REQUESTS_PER_MINUTE,
  MAX_TOKENS_PER_MINUTE,
  EFFECTIVE_TOKEN_BUDGET,
};

