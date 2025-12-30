/**
 * AI Enhancement
 * 
 * Orchestrates AI-powered documentation enhancement.
 */

const ai = require('../../ai-provider');
const { buildSystemPrompt, buildPrompt } = require('./prompt-builder');
const { extractJSON, convertEnhancedFields } = require('./response-parser');
const { addFallbackContent } = require('./fallback-content-provider');

/**
 * Check if enhancement should be skipped for a file
 * @param {object} data - Documentation data
 * @returns {boolean} True if should skip
 */
function shouldSkipEnhancement(data) {
  if (!data.functions || data.functions.length === 0) {
    return true;
  }
  
  if (data.title.startsWith('I') && data.title.length > 1 && 
      data.title[1] === data.title[1].toUpperCase()) {
    return true;
  }

  return false;
}

/**
 * Enhance documentation data using AI
 * @param {object} data - Parsed documentation data
 * @param {'module' | 'facet'} contractType - Type of contract
 * @param {string} token - Legacy token parameter (deprecated, uses env vars now)
 * @returns {Promise<{data: object, usedFallback: boolean, error?: string}>} Enhanced data with fallback status
 */
async function enhanceWithAI(data, contractType, token) {
  try {
    const systemPrompt = buildSystemPrompt();
    const userPrompt = buildPrompt(data, contractType);

    // Call AI provider
    const responseText = await ai.call(systemPrompt, userPrompt, {
      onSuccess: () => {
        // Silent success - no logging
      },
      onError: () => {
        // Silent error - will be caught below
      }
    });

    // Parse JSON response
    let enhanced;
    try {
      enhanced = JSON.parse(responseText);
    } catch (directParseError) {
      const cleanedContent = extractJSON(responseText);
      enhanced = JSON.parse(cleanedContent);
    }

    return { data: convertEnhancedFields(enhanced, data), usedFallback: false };

  } catch (error) {
    return { 
      data: addFallbackContent(data, contractType), 
      usedFallback: true, 
      error: error.message 
    };
  }
}

module.exports = {
  enhanceWithAI,
  shouldSkipEnhancement,
};

