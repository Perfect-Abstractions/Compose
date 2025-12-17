/**
 * Google AI (Gemini) Provider
 * Uses Google AI API key for authentication
 */
const BaseAIProvider = require('./base-provider');

class GeminiProvider extends BaseAIProvider {
  constructor(config, apiKey) {
    const model = config.model || 'gemini-1.5-flash';
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
  if (!apiKey) {
    return null;
  }

  const config = {
    model: customModel || 'gemini-1.5-flash',
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

