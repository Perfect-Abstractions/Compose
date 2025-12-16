/**
 * GitHub Models integration for documentation enhancement
 * Uses Azure AI inference endpoint with GitHub token auth
 * See: https://github.blog/changelog/2025-04-14-github-actions-token-integration-now-generally-available-in-github-models/
 */

const fs = require('fs');
const path = require('path');
const { models: MODELS_CONFIG } = require('./config');
const { sleep, makeHttpsRequest } = require('../workflow-utils');
const {
  estimateTokenUsage,
  waitForRateLimit,
  recordTokenConsumption,
  updateLastTokenConsumption,
  calculate429WaitTime,
} = require('./token-rate-limiter');

// Maximum number of times to retry a single request after hitting a 429
const MAX_RATE_LIMIT_RETRIES = 3;

const AI_PROMPT_PATH = path.join(__dirname, '../../docs-gen-prompts.md');
const REPO_INSTRUCTIONS_PATH = path.join(__dirname, '../../copilot-instructions.md');

// Load repository instructions for context
let REPO_INSTRUCTIONS = '';
try {
  REPO_INSTRUCTIONS = fs.readFileSync(REPO_INSTRUCTIONS_PATH, 'utf8');
} catch (e) {
  console.warn('Could not load copilot-instructions.md:', e.message);
}

// Load AI prompts from markdown file
let AI_PROMPTS = {
  systemPrompt: '',
  modulePrompt: '',
  facetPrompt: '',
  relevantSections: [],
  moduleFallback: { integrationNotes: '', keyFeatures: '' },
  facetFallback: { keyFeatures: '' },
};
try {
  const promptsContent = fs.readFileSync(AI_PROMPT_PATH, 'utf8');
  AI_PROMPTS = parsePromptsFile(promptsContent);
} catch (e) {
  console.warn('Could not load ai-prompts.md:', e.message);
}

/**
 * Parse the prompts markdown file to extract individual prompts
 * @param {string} content - Raw markdown content
 * @returns {object} Parsed prompts and configurations
 */
function parsePromptsFile(content) {
  const sections = content.split(/^---$/m).map(s => s.trim()).filter(Boolean);
  
  const prompts = {
    systemPrompt: '',
    modulePrompt: '',
    facetPrompt: '',
    relevantSections: [],
    moduleFallback: { integrationNotes: '', keyFeatures: '' },
    facetFallback: { keyFeatures: '' },
  };
  
  for (const section of sections) {
    if (section.includes('## System Prompt')) {
      const match = section.match(/## System Prompt\s*\n([\s\S]*)/);
      if (match) {
        prompts.systemPrompt = match[1].trim();
      }
    } else if (section.includes('## Relevant Guideline Sections')) {
      // Extract sections from the code block
      const codeMatch = section.match(/```\n([\s\S]*?)```/);
      if (codeMatch) {
        prompts.relevantSections = codeMatch[1]
          .split('\n')
          .map(s => s.trim())
          .filter(s => s.startsWith('## '));
      }
    } else if (section.includes('## Module Prompt Template')) {
      const match = section.match(/## Module Prompt Template\s*\n([\s\S]*)/);
      if (match) {
        prompts.modulePrompt = match[1].trim();
      }
    } else if (section.includes('## Facet Prompt Template')) {
      const match = section.match(/## Facet Prompt Template\s*\n([\s\S]*)/);
      if (match) {
        prompts.facetPrompt = match[1].trim();
      }
    } else if (section.includes('## Module Fallback Content')) {
      // Parse subsections for integrationNotes and keyFeatures
      const integrationMatch = section.match(/### integrationNotes\s*\n([\s\S]*?)(?=###|$)/);
      if (integrationMatch) {
        prompts.moduleFallback.integrationNotes = integrationMatch[1].trim();
      }
      const keyFeaturesMatch = section.match(/### keyFeatures\s*\n([\s\S]*?)(?=###|$)/);
      if (keyFeaturesMatch) {
        prompts.moduleFallback.keyFeatures = keyFeaturesMatch[1].trim();
      }
    } else if (section.includes('## Facet Fallback Content')) {
      const keyFeaturesMatch = section.match(/### keyFeatures\s*\n([\s\S]*?)(?=###|$)/);
      if (keyFeaturesMatch) {
        prompts.facetFallback.keyFeatures = keyFeaturesMatch[1].trim();
      }
    }
  }
  
  return prompts;
}

/**
 * Build the system prompt with repository context
 * Uses the system prompt from the prompts file, or a fallback if not found
 * @returns {string} System prompt for Copilot
 */
function buildSystemPrompt() {
  let systemPrompt = AI_PROMPTS.systemPrompt || `You are a Solidity smart contract documentation expert for the Compose framework. 
Always respond with valid JSON only, no markdown formatting.
Follow the project conventions and style guidelines strictly.`;

  if (REPO_INSTRUCTIONS) {
    const relevantSections = AI_PROMPTS.relevantSections.length > 0
      ? AI_PROMPTS.relevantSections
      : [
          '## 3. Core Philosophy',
          '## 4. Facet Design Principles', 
          '## 5. Banned Solidity Features',
          '## 6. Composability Guidelines',
          '## 11. Code Style Guide',
        ];
    
    let contextSnippets = [];
    for (const section of relevantSections) {
      const startIdx = REPO_INSTRUCTIONS.indexOf(section);
      if (startIdx !== -1) {
        // Extract section content (up to next ## or 2000 chars max)
        const nextSection = REPO_INSTRUCTIONS.indexOf('\n## ', startIdx + section.length);
        const endIdx = nextSection !== -1 ? nextSection : startIdx + 2000;
        const snippet = REPO_INSTRUCTIONS.slice(startIdx, Math.min(endIdx, startIdx + 2000));
        contextSnippets.push(snippet.trim());
      }
    }
    
    if (contextSnippets.length > 0) {
      systemPrompt += `\n\n--- PROJECT GUIDELINES ---\n${contextSnippets.join('\n\n')}`;
    }
  }

  return systemPrompt;
}

/**
 * Build the prompt for Copilot based on contract type
 * @param {object} data - Parsed documentation data
 * @param {'module' | 'facet'} contractType - Type of contract
 * @returns {string} Prompt for Copilot
 */
function buildPrompt(data, contractType) {
  const functionNames = data.functions.map(f => f.name).join(', ');
  const functionDescriptions = data.functions
    .map(f => `- ${f.name}: ${f.description || 'No description'}`)
    .join('\n');

  const promptTemplate = contractType === 'module' 
    ? AI_PROMPTS.modulePrompt 
    : AI_PROMPTS.facetPrompt;

  // If we have a template from the file, use it with variable substitution
  if (promptTemplate) {
    return promptTemplate
      .replace(/\{\{title\}\}/g, data.title)
      .replace(/\{\{description\}\}/g, data.description || 'No description provided')
      .replace(/\{\{functionNames\}\}/g, functionNames || 'None')
      .replace(/\{\{functionDescriptions\}\}/g, functionDescriptions || '  None');
  }

  // Fallback to hardcoded prompt if template not loaded
  return `Given this ${contractType} documentation from the Compose diamond proxy framework, enhance it by generating:

1. **overview**: A clear, concise overview (2-3 sentences) explaining what this ${contractType} does and why it's useful in the context of diamond contracts.

2. **usageExample**: A practical Solidity code example (10-20 lines) showing how to use this ${contractType}. For modules, show importing and calling functions. For facets, show how it would be used in a diamond.

3. **bestPractices**: 2-3 bullet points of best practices for using this ${contractType}.

${contractType === 'module' ? '4. **integrationNotes**: A note about how this module works with diamond storage pattern and how changes made through it are visible to facets.' : ''}

${contractType === 'facet' ? '4. **securityConsiderations**: Important security considerations when using this facet (access control, reentrancy, etc.).' : ''}

5. **keyFeatures**: A brief bullet list of key features.

Contract Information:
- Name: ${data.title}
- Description: ${data.description || 'No description provided'}
- Functions: ${functionNames || 'None'}
- Function Details:
${functionDescriptions || '  None'}

Respond ONLY with valid JSON in this exact format (no markdown code blocks, no extra text):
{
  "overview": "enhanced overview text here",
  "usageExample": "solidity code here (use \\n for newlines)",
  "bestPractices": "- Point 1\\n- Point 2\\n- Point 3",
  "keyFeatures": "- Feature 1\\n- Feature 2",
  ${contractType === 'module' ? '"integrationNotes": "integration notes here"' : '"securityConsiderations": "security notes here"'}
}`;
}

/**
 * Convert enhanced data fields (newlines, HTML entities)
 * @param {object} enhanced - Parsed JSON from API
 * @param {object} data - Original documentation data
 * @returns {object} Enhanced data with converted fields
 */
function convertEnhancedFields(enhanced, data) {
  // Convert literal \n strings to actual newlines
  const convertNewlines = (str) => {
    if (!str || typeof str !== 'string') return str;
    return str.replace(/\\n/g, '\n');
  };
  
  // Decode HTML entities (for code blocks)
  const decodeHtmlEntities = (str) => {
    if (!str || typeof str !== 'string') return str;
    return str
      .replace(/&quot;/g, '"')
      .replace(/&#x3D;/g, '=')
      .replace(/&#x3D;&gt;/g, '=>')
      .replace(/&lt;/g, '<')
      .replace(/&gt;/g, '>')
      .replace(/&#39;/g, "'")
      .replace(/&amp;/g, '&');
  };
  
  return {
    ...data,
    overview: convertNewlines(enhanced.overview) || data.overview,
    usageExample: decodeHtmlEntities(convertNewlines(enhanced.usageExample)) || null,
    bestPractices: convertNewlines(enhanced.bestPractices) || null,
    keyFeatures: convertNewlines(enhanced.keyFeatures) || null,
    integrationNotes: convertNewlines(enhanced.integrationNotes) || null,
    securityConsiderations: convertNewlines(enhanced.securityConsiderations) || null,
  };
}

/**
 * Extract and clean JSON from API response
 * Handles markdown code blocks, wrapped text, and attempts to fix truncated JSON
 * @param {string} content - Raw API response content
 * @returns {string} Cleaned JSON string ready for parsing
 */
function extractJSON(content) {
  if (!content || typeof content !== 'string') {
    return content;
  }

  let cleaned = content.trim();

  // Remove markdown code blocks (```json ... ``` or ``` ... ```)
  // Handle both at start and anywhere in the string
  cleaned = cleaned.replace(/^```(?:json)?\s*\n?/gm, '');
  cleaned = cleaned.replace(/\n?```\s*$/gm, '');
  cleaned = cleaned.trim();

  // Find the first { and last } to extract JSON object
  const firstBrace = cleaned.indexOf('{');
  const lastBrace = cleaned.lastIndexOf('}');

  if (firstBrace !== -1 && lastBrace !== -1 && lastBrace > firstBrace) {
    cleaned = cleaned.substring(firstBrace, lastBrace + 1);
  } else if (firstBrace !== -1) {
    // We have a { but no closing }, JSON might be truncated
    cleaned = cleaned.substring(firstBrace);
  }

  // Try to fix common truncation issues
  const openBraces = (cleaned.match(/\{/g) || []).length;
  const closeBraces = (cleaned.match(/\}/g) || []).length;
  
  if (openBraces > closeBraces) {
    // JSON might be truncated - try to close incomplete strings and objects
    // Check if we're in the middle of a string (simple heuristic)
    const lastChar = cleaned[cleaned.length - 1];
    const lastQuote = cleaned.lastIndexOf('"');
    const lastBraceInCleaned = cleaned.lastIndexOf('}');
    
    // If last quote is after last brace and not escaped, we might be in a string
    if (lastQuote > lastBraceInCleaned && lastChar !== '"') {
      // Check if the quote before last is escaped
      let isEscaped = false;
      for (let i = lastQuote - 1; i >= 0 && cleaned[i] === '\\'; i--) {
        isEscaped = !isEscaped;
      }
      
      if (!isEscaped) {
        // We're likely in an incomplete string, close it
        cleaned = cleaned + '"';
      }
    }
    
    // Close any incomplete objects/arrays
    const missingBraces = openBraces - closeBraces;
    // Try to intelligently close - if we're in the middle of a property, add a value first
    const trimmed = cleaned.trim();
    if (trimmed.endsWith(',') || trimmed.endsWith(':')) {
      // We're in the middle of a property, add null and close
      cleaned = cleaned.replace(/[,:]\s*$/, ': null');
    }
    cleaned = cleaned + '\n' + '}'.repeat(missingBraces);
  }

  return cleaned.trim();
}

/**
 * Enhance documentation data using GitHub Copilot
 * @param {object} data - Parsed documentation data
 * @param {'module' | 'facet'} contractType - Type of contract
 * @param {string} token - GitHub token
 * @returns {Promise<object>} Enhanced data
 */
async function enhanceWithAI(data, contractType, token) {
  if (!token) {
    console.log('    ⚠️ No GitHub token provided, skipping AI enhancement');
    return addFallbackContent(data, contractType);
  }

  const systemPrompt = buildSystemPrompt();
  const userPrompt = buildPrompt(data, contractType);
  const maxTokens = MODELS_CONFIG.maxTokens;

  // Estimate token usage for this request (for rate limiting)
  const estimatedTokens = estimateTokenUsage(systemPrompt, userPrompt, maxTokens);

  const requestBody = JSON.stringify({
    messages: [
      {
        role: 'system',
        content: systemPrompt,
      },
      {
        role: 'user',
        content: userPrompt,
      },
    ],
    model: MODELS_CONFIG.model,
    max_tokens: maxTokens,
  });

  // GitHub Models uses Azure AI inference endpoint
  // Authentication: GITHUB_TOKEN works directly in GitHub Actions
  const options = {
    hostname: MODELS_CONFIG.host,
    port: 443,
    path: '/chat/completions',
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${token}`,
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'User-Agent': 'Compose-DocGen/1.0',
    },
  };

  try {
    // Wait for both time-based and token-based rate limits
    await waitForRateLimit(estimatedTokens);

    // Helper to handle a single API call and common response parsing
    const performApiCall = async () => {
      const response = await makeHttpsRequest(options, requestBody);

      // Only record token consumption if we got a successful response
      // (not a 429 or other error that would throw before reaching here)
      if (response.choices && response.choices[0] && response.choices[0].message) {
        // Record token consumption (use actual if available, otherwise estimated)
        if (response.usage && response.usage.total_tokens) {
          // GitHub Models API provides actual usage - use it for more accurate tracking
          const actualTokens = response.usage.total_tokens;
          recordTokenConsumption(actualTokens);
          console.log(`    📊 Actual token usage: ${actualTokens} tokens`);
        } else {
          // Fallback to estimated tokens if API doesn't provide usage
          recordTokenConsumption(estimatedTokens);
          console.log(`    📊 Estimated token usage: ${estimatedTokens} tokens`);
        }
        
        const content = response.choices[0].message.content;
        
        // Debug: Log full response content
        console.log('    📋 Full API response content:');
        console.log('    ' + '='.repeat(80));
        console.log(content);
        console.log('    ' + '='.repeat(80));
        console.log('    Response length:', content.length, 'chars');
        console.log('    First 100 chars:', JSON.stringify(content.substring(0, 100)));
        console.log('    Last 100 chars:', JSON.stringify(content.substring(Math.max(0, content.length - 100))));
        
        try {
          // First, try to parse directly (most responses should be valid JSON)
          let enhanced;
          try {
            enhanced = JSON.parse(content);
            console.log('✅ AI enhancement successful (direct parse)');
          } catch (directParseError) {
            // If direct parse fails, try to extract and clean JSON
            console.log('    Direct parse failed, attempting to extract JSON...');
            const cleanedContent = extractJSON(content);
            console.log('    Cleaned content length:', cleanedContent.length, 'chars');
            
            enhanced = JSON.parse(cleanedContent);
            console.log('✅ AI enhancement successful (after extraction)');
          }
          
          return convertEnhancedFields(enhanced, data);
        } catch (parseError) {
          console.log('    ⚠️ Could not parse API response as JSON');
          console.log('    Parse error:', parseError.message);
          
          // As a last resort, try one more time with extraction
          try {
            const cleanedContent = extractJSON(content);
            console.log('    Attempting final parse with extracted JSON...');
            const enhanced = JSON.parse(cleanedContent);
            console.log('✅ AI enhancement successful (final attempt with extraction)');
            
            return convertEnhancedFields(enhanced, data);
          } catch (finalError) {
            console.log('    Final parse attempt also failed:', finalError.message);
            console.log('    Error position:', finalError.message.match(/position (\d+)/)?.[1] || 'unknown');
            
            // Show debugging info
            try {
              const cleanedContent = extractJSON(content);
              console.log('    Cleaned content (first 500 chars):', JSON.stringify(cleanedContent.substring(0, 500)));
              console.log('    Cleaned content (last 500 chars):', JSON.stringify(cleanedContent.substring(Math.max(0, cleanedContent.length - 500))));
              
              // Try to find the error position in cleaned content
              const errorPosMatch = finalError.message.match(/position (\d+)/);
              if (errorPosMatch) {
                const errorPos = parseInt(errorPosMatch[1], 10);
                const start = Math.max(0, errorPos - 50);
                const end = Math.min(cleanedContent.length, errorPos + 50);
                console.log('    Error context (chars ' + start + '-' + end + '):', JSON.stringify(cleanedContent.substring(start, end)));
              }
            } catch (e) {
              console.log('    Could not extract/clean content:', e.message);
            }
          }
          
          return addFallbackContent(data, contractType);
        }
      }

      console.log('    ⚠️ Unexpected API response format');
      console.log('    Response structure:', JSON.stringify(response, null, 2).substring(0, 1000));
      return addFallbackContent(data, contractType);
    };

    let attempt = 0;
    // Retry loop for handling minute-token 429s while still eventually
    // progressing through all files in the run.
    // We calculate the exact wait time based on when tokens will be available.
    // eslint-disable-next-line no-constant-condition
    while (true) {
      try {
        return await performApiCall();
      } catch (error) {
        const msg = error && error.message ? error.message : '';

        // Detect GitHub Models minute-token rate limit (HTTP 429)
        if (msg.startsWith('HTTP 429:') && attempt < MAX_RATE_LIMIT_RETRIES) {
          attempt += 1;
          
          // Calculate smart wait time based on token budget
          const waitTime = calculate429WaitTime(estimatedTokens);
          const waitSeconds = Math.ceil(waitTime / 1000);
          
          console.log(
            `    ⚠️ GitHub Models rate limit reached (minute tokens). ` +
            `Waiting ${waitSeconds}s for token budget to reset (retry ${attempt}/${MAX_RATE_LIMIT_RETRIES})...`
          );
          await sleep(waitTime);
          
          // Re-check rate limit before retrying
          await waitForRateLimit(estimatedTokens);
          continue;
        }

        if (msg.startsWith('HTTP 429:')) {
          console.log('    ⚠️ Rate limit persisted after maximum retries, using fallback content');
        } else {
          console.log(`    ⚠️ GitHub Models API error: ${msg}`);
        }

        return addFallbackContent(data, contractType);
      }
    }
  } catch (outerError) {
    console.log(`    ⚠️ GitHub Models API error (outer): ${outerError.message}`);
    return addFallbackContent(data, contractType);
  }
}

/**
 * Add fallback content when AI is unavailable
 * @param {object} data - Documentation data
 * @param {'module' | 'facet'} contractType - Type of contract
 * @returns {object} Data with fallback content
 */
function addFallbackContent(data, contractType) {
  console.log('    Using fallback content');

  const enhanced = { ...data };

  if (contractType === 'module') {
    enhanced.integrationNotes = AI_PROMPTS.moduleFallback.integrationNotes ||
      `This module accesses shared diamond storage, so changes made through this module are immediately visible to facets using the same storage pattern. All functions are internal as per Compose conventions.`;
    enhanced.keyFeatures = AI_PROMPTS.moduleFallback.keyFeatures ||
      `- All functions are \`internal\` for use in custom facets\n- Follows diamond storage pattern (EIP-8042)\n- Compatible with ERC-2535 diamonds\n- No external dependencies or \`using\` directives`;
  } else {
    enhanced.keyFeatures = AI_PROMPTS.facetFallback.keyFeatures ||
      `- Self-contained facet with no imports or inheritance\n- Only \`external\` and \`internal\` function visibility\n- Follows Compose readability-first conventions\n- Ready for diamond integration`;
  }

  return enhanced;
}

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

module.exports = {
  enhanceWithAI,
  addFallbackContent,
  shouldSkipEnhancement,
};


