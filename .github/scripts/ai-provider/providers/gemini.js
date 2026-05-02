/**
 * Google AI (Gemini) Provider
 * Uses Google AI API key for authentication
 */
const BaseAIProvider = require('./base-provider');

/**
 * Gemini Provider Class
 * Default model: gemini-2.5-flash-lite
 * This model is a lightweight model that is designed to be fast and efficient.
 * Refer to https://ai.google.dev/gemini-api/docs for the list of models.
 */
class GeminiProvider extends BaseAIProvider {
  /**
   * Constructor
   * @param {object} config - Configuration object
   * @param {string} config.model - Model to use
   * @param {number} config.maxTokens - Maximum number of tokens to generate
   * @param {number} config.maxRequestsPerMinute - Maximum number of requests per minute
   * @param {number} config.maxTokensPerMinute - Maximum number of tokens per minute
   * @param {string} apiKey - Google AI API key (required)
   */
  constructor(config, apiKey) {
    const model = config.model || 'gemini-2.5-flash-lite';
    super(`Google AI (${model})`, config, apiKey);
    this.model = model;
  }

  buildRequestOptions() {
    return {
      hostname: 'generativelanguage.googleapis.com',
      port: 443,
      path: `/v1beta/models/${this.model}:generateContent?key=${this.apiKey}`,
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'User-Agent': 'Compose-CI/1.0',
      },
    };
  }

  buildRequestBody(systemPrompt, userPrompt, maxTokens) {
    // Gemini combines system and user prompts
    const combinedPrompt = `${systemPrompt}\n\n${userPrompt}`;
    
    return JSON.stringify({
      contents: [{
        parts: [{ text: combinedPrompt }]
      }],
      generationConfig: {
        maxOutputTokens: maxTokens || this.getMaxTokens(),
        temperature: 0.7,
        topP: 0.95,
        topK: 40,
      },
      safetySettings: [
        { category: "HARM_CATEGORY_HARASSMENT", threshold: "BLOCK_NONE" },
        { category: "HARM_CATEGORY_HATE_SPEECH", threshold: "BLOCK_NONE" },
        { category: "HARM_CATEGORY_SEXUALLY_EXPLICIT", threshold: "BLOCK_NONE" },
        { category: "HARM_CATEGORY_DANGEROUS_CONTENT", threshold: "BLOCK_NONE" }
      ]
    });
  }

  extractContent(response) {
    const text = response.candidates?.[0]?.content?.parts?.[0]?.text;
    if (text) {
      return {
        content: text,
        tokens: response.usageMetadata?.totalTokenCount || null,
      };
    }
    return null;
  }

  getRateLimits() {
    return {
      maxRequestsPerMinute: 15,
      maxTokensPerMinute: 1000000, // 1M tokens per minute
    };
  }

  
}

/**
 * Create Gemini provider
 */
function createGeminiProvider(customModel) {
  const apiKey = process.env.GOOGLE_AI_API_KEY;


  const config = {
    model: customModel,
    maxTokens: 2500,
    maxRequestsPerMinute: 15,
    maxTokensPerMinute: 1000000,
  };

  return new GeminiProvider(config, apiKey);
}

module.exports = {
  GeminiProvider,
  createGeminiProvider,
};

