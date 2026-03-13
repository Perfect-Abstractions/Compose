# AI Provider Service

Simple, configurable AI service for CI workflows supporting multiple providers.

## Features

- **Simple API**: One function to call any AI model
- **Multiple Providers**: GitHub Models (GPT-4o) and Google Gemini
- **Auto-detection**: Automatically uses available provider
- **Rate Limiting**: Built-in request and token-based rate limiting
- **Configurable**: Override provider and model via environment variables

## Supported Providers

| Provider | Models | Rate Limits | API Key |
|----------|--------|-------------|---------|
| **GitHub Models** | gpt-4o, gpt-4o-mini | 10 req/min, 40k tokens/min | `GITHUB_TOKEN` |
| **Google Gemini** | gemini-1.5-flash, gemini-1.5-pro | 15 req/min, 1M tokens/min | `GOOGLE_AI_API_KEY` |

## Usage

### Basic Usage

```javascript
const ai = require('./ai-provider');

const response = await ai.call(
  'You are a helpful assistant',  // system prompt
  'Explain quantum computing'      // user prompt
);

console.log(response);
```

### With Options

```javascript
const response = await ai.call(
  systemPrompt,
  userPrompt,
  {
    maxTokens: 1000,
    onSuccess: (text, tokens) => {
      console.log(`Success! Used ${tokens} tokens`);
    },
    onError: (error) => {
      console.error('Failed:', error);
    }
  }
);
```

## Environment Variables

### Provider Selection

```bash
# Auto-detect (default) - Try other provider with fallback to Github
AI_PROVIDER=auto

# Use specific provider
AI_PROVIDER=github    # Use GitHub Models
AI_PROVIDER=gemini    # Use Google Gemini
```

### Model Override

```bash
# Override default model for the provider
AI_MODEL=gpt-4o              # For GitHub Models
AI_MODEL=gemini-1.5-pro      # For Gemini
```

### API Keys

```bash
# Google Gemini
GOOGLE_AI_API_KEY=
```

## Examples

## GitHub Actions Integration

```yaml
- name: Run AI-powered task
  env:
    # Option 1: Auto-detect (recommended)
    GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
    GOOGLE_AI_API_KEY: ${{ secrets.GOOGLE_AI_API_KEY }}
    
    # Option 2: Force specific provider
    # AI_PROVIDER: 'gemini'
    # AI_MODEL: 'gemini-1.5-pro'
  run: node .github/scripts/your-script.js
```

## Architecture

```
ai-provider/
├── index.js                 # Main service (singleton)
├── base-provider.js         # Base provider class
├── provider-factory.js      # Provider creation logic
├── rate-limiter.js          # Rate limiting logic
└── providers/
    ├── github-models.js     # GitHub Models implementation
    └── gemini.js            # Gemini implementation
```

## Adding a New Provider

1. Create a new provider class in `providers/`:

```javascript
const BaseAIProvider = require('../base-provider');

class MyProvider extends BaseAIProvider {
  constructor(config, apiKey) {
    super('My Provider', config, apiKey);
  }

  buildRequestOptions() {
    // Return HTTP request options
  }

  buildRequestBody(systemPrompt, userPrompt, maxTokens) {
    // Return JSON.stringify(...) of request body
  }

  extractContent(response) {
    // Return { content: string, tokens: number|null }
  }
}

module.exports = MyProvider;
```

2. Register in `provider-factory.js`:

```javascript
const MyProvider = require('./providers/my-provider');

function createMyProvider(customModel) {
  const apiKey = process.env.MY_PROVIDER_API_KEY;
  if (!apiKey) return null;
  
  return new MyProvider({ model: customModel || 'default-model' }, apiKey);
}
```

3. Add to auto-detection or switch statement.

## Rate Limiting

The service automatically handles rate limiting:

- **Request-based**: Ensures minimum delay between requests
- **Token-based**: Tracks token consumption in a 60-second rolling window
- **Smart waiting**: Calculates exact wait time needed

Rate limits are provider-specific and configured automatically.

## Error Handling

```javascript
try {
  const response = await ai.call(systemPrompt, userPrompt);
  // Use response
} catch (error) {
  if (error.message.includes('429')) {
    console.log('Rate limited - try again later');
  } else if (error.message.includes('401')) {
    console.log('Invalid API key');
  } else {
    console.log('Other error:', error.message);
  }
}
```
