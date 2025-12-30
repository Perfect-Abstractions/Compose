/**
 * AI-powered documentation enhancement
 * Uses the ai-provider service for multi-provider support
 */

const fs = require('fs');
const path = require('path');
const ai = require('../ai-provider');
const {
  extractSourceContext,
  computeImportPath,
  formatFunctionSignatures,
  formatStorageContext,
  formatRelatedContracts,
  formatStructDefinitions,
  formatEventSignatures,
  formatErrorSignatures,
} = require('./context-extractor');
const { getContractRegistry } = require('./contract-registry');

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

  // Include events and errors for richer context
  const eventNames = (data.events || []).map(e => e.name).join(', ');
  const errorNames = (data.errors || []).map(e => e.name).join(', ');

  // Extract additional context
  const sourceContext = extractSourceContext(data.sourceFilePath);
  const importPath = computeImportPath(data.sourceFilePath);
  const functionSignatures = formatFunctionSignatures(data.functions);
  const eventSignatures = formatEventSignatures(data.events);
  const errorSignatures = formatErrorSignatures(data.errors);
  const structDefinitions = formatStructDefinitions(data.structs);
  
  // Get storage context
  const storageContext = formatStorageContext(
    data.storageInfo,
    data.structs,
    data.stateVariables
  );

  // Get related contracts context
  const registry = getContractRegistry();
  // Try to get category from registry entry, or use empty string
  const registryEntry = registry.byName.get(data.title);
  const category = data.category || (registryEntry ? registryEntry.category : '');
  const relatedContracts = formatRelatedContracts(
    data.title,
    contractType,
    category,
    registry
  );

  const promptTemplate = contractType === 'module' 
    ? AI_PROMPTS.modulePrompt 
    : AI_PROMPTS.facetPrompt;

  // If we have a template from the file, use it with variable substitution
  if (promptTemplate) {
    return promptTemplate
      .replace(/\{\{title\}\}/g, data.title)
      .replace(/\{\{description\}\}/g, data.description || 'No description provided')
      .replace(/\{\{functionNames\}\}/g, functionNames || 'None')
      .replace(/\{\{functionDescriptions\}\}/g, functionDescriptions || '  None')
      .replace(/\{\{eventNames\}\}/g, eventNames || 'None')
      .replace(/\{\{errorNames\}\}/g, errorNames || 'None')
      .replace(/\{\{functionSignatures\}\}/g, functionSignatures || 'None')
      .replace(/\{\{eventSignatures\}\}/g, eventSignatures || 'None')
      .replace(/\{\{errorSignatures\}\}/g, errorSignatures || 'None')
      .replace(/\{\{importPath\}\}/g, importPath || 'N/A')
      .replace(/\{\{pragmaVersion\}\}/g, sourceContext.pragmaVersion || '^0.8.30')
      .replace(/\{\{storageContext\}\}/g, storageContext || 'None')
      .replace(/\{\{relatedContracts\}\}/g, relatedContracts || 'None')
      .replace(/\{\{structDefinitions\}\}/g, structDefinitions || 'None');
  }

  // Fallback to hardcoded prompt if template not loaded
  return `Given this ${contractType} documentation from the Compose diamond proxy framework, enhance it by generating:

1. **description**: A concise one-line description (max 100 chars) for the page subtitle. Derive this from the contract's purpose based on its functions, events, and errors.

2. **overview**: A clear, concise overview (2-3 sentences) explaining what this ${contractType} does and why it's useful in the context of diamond contracts.

3. **usageExample**: A practical Solidity code example (10-20 lines) showing how to use this ${contractType}. For modules, show importing and calling functions. For facets, show how it would be used in a diamond. Use the EXACT import path and function signatures provided below.

4. **bestPractices**: 2-3 bullet points of best practices for using this ${contractType}.

${contractType === 'module' ? '5. **integrationNotes**: A note about how this module works with diamond storage pattern and how changes made through it are visible to facets.' : ''}

${contractType === 'facet' ? '5. **securityConsiderations**: Important security considerations when using this facet (access control, reentrancy, etc.).' : ''}

6. **keyFeatures**: A brief bullet list of key features.

Contract Information:
- Name: ${data.title}
- Current Description: ${data.description || 'No description provided'}
- Import Path: ${importPath || 'N/A'}
- Pragma Version: ${sourceContext.pragmaVersion || '^0.8.30'}
- Functions: ${functionNames || 'None'}
- Function Signatures:
${functionSignatures || '  None'}
- Events: ${eventNames || 'None'}
- Event Signatures:
${eventSignatures || '  None'}
- Errors: ${errorNames || 'None'}
- Error Signatures:
${errorSignatures || '  None'}
- Function Details:
${functionDescriptions || '  None'}
${storageContext && storageContext !== 'None' ? `\n- Storage Information:\n${storageContext}` : ''}
${relatedContracts && relatedContracts !== 'None' ? `\n- Related Contracts:\n${relatedContracts}` : ''}
${structDefinitions && structDefinitions !== 'None' ? `\n- Struct Definitions:\n${structDefinitions}` : ''}

IMPORTANT: Use the EXACT function signatures, import paths, and storage information provided above. Do not invent or modify function names, parameter types, or import paths.

Respond ONLY with valid JSON in this exact format (no markdown code blocks, no extra text):
{
  "description": "concise one-line description here",
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

  // Use AI-generated description if provided, otherwise keep original
  const aiDescription = enhanced.description?.trim();
  const finalDescription = aiDescription || data.description;
  
  return {
    ...data,
    // Description is used for page subtitle - AI improves it from NatSpec
    description: finalDescription,
    subtitle: finalDescription,
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
 * Also removes control characters that break JSON parsing
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

  // Remove control characters (0x00-0x1F except newline, tab, carriage return)
  // These are illegal in JSON strings and cause "Bad control character" parsing errors
  cleaned = cleaned.replace(/[\x00-\x08\x0B\x0C\x0E-\x1F]/g, '');

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

/**
 * Add fallback content when AI is unavailable
 * @param {object} data - Documentation data
 * @param {'module' | 'facet'} contractType - Type of contract
 * @returns {object} Data with fallback content
 */
function addFallbackContent(data, contractType) {
  const enhanced = { ...data }

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


