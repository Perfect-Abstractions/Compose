/**
 * GitHub Models (Azure OpenAI) Provider
 * Uses GitHub token for authentication in GitHub Actions
 */
const BaseAIProvider = require('./base-provider');

class GitHubModelsProvider extends BaseAIProvider {
  constructor(config, apiKey) {
    const model = config.model || 'gpt-4o';
    super(`GitHub Models (${model})`, config, apiKey);
    this.model = model;
  }

  buildRequestOptions() {
    return {
      hostname: 'models.inference.ai.azure.com',
      port: 443,
      path: '/chat/completions',
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${this.apiKey}`,
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'User-Agent': 'Compose-CI/1.0',
      },
    };
  }

  buildRequestBody(systemPrompt, userPrompt, maxTokens) {
    return JSON.stringify({
      messages: [
        { role: 'system', content: systemPrompt },
        { role: 'user', content: userPrompt },
      ],
      model: this.model,
      max_tokens: maxTokens || this.getMaxTokens(),
      temperature: 0.7,
    });
  }

  extractContent(response) {
    if (response.choices?.[0]?.message?.content) {
      return {
        content: response.choices[0].message.content,
        tokens: response.usage?.total_tokens || null,
      };
    }
    return null;
  }

  getRateLimits() {
    return {
      maxRequestsPerMinute: 10,
      maxTokensPerMinute: 40000,
    };
  }
}

/**
 * Create GitHub Models provider
 */
function createGitHubProvider(customModel) {
  const apiKey = process.env.GITHUB_TOKEN;

  const config = {
    model: customModel,
    maxTokens: 2500,
    maxRequestsPerMinute: 10,
    maxTokensPerMinute: 40000,
  };

  return new GitHubModelsProvider(config, apiKey);
}

module.exports = {
  GitHubModelsProvider,
  createGitHubProvider,
};

