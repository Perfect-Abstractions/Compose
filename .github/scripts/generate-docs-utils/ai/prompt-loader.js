/**
 * Prompt Loader
 * 
 * Loads and parses AI prompts from markdown files.
 */

const fs = require('fs');
const path = require('path');

const AI_PROMPT_PATH = path.join(__dirname, '../../../docs-gen-prompts.md');
const REPO_INSTRUCTIONS_PATH = path.join(__dirname, '../../../copilot-instructions.md');

// Cache loaded prompts
let cachedPrompts = null;
let cachedRepoInstructions = null;

/**
 * Load repository instructions for context
 * @returns {string} Repository instructions content
 */
function loadRepoInstructions() {
  if (cachedRepoInstructions !== null) {
    return cachedRepoInstructions;
  }

  try {
    cachedRepoInstructions = fs.readFileSync(REPO_INSTRUCTIONS_PATH, 'utf8');
  } catch (e) {
    console.warn('Could not load copilot-instructions.md:', e.message);
    cachedRepoInstructions = '';
  }

  return cachedRepoInstructions;
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
 * Load AI prompts from markdown file
 * @returns {object} Parsed prompts object
 */
function loadPrompts() {
  if (cachedPrompts !== null) {
    return cachedPrompts;
  }

  const defaultPrompts = {
    systemPrompt: '',
    modulePrompt: '',
    facetPrompt: '',
    relevantSections: [],
    moduleFallback: { integrationNotes: '', keyFeatures: '' },
    facetFallback: { keyFeatures: '' },
  };

  try {
    const promptsContent = fs.readFileSync(AI_PROMPT_PATH, 'utf8');
    cachedPrompts = parsePromptsFile(promptsContent);
  } catch (e) {
    console.warn('Could not load ai-prompts.md:', e.message);
    cachedPrompts = defaultPrompts;
  }

  return cachedPrompts;
}

module.exports = {
  loadPrompts,
  loadRepoInstructions,
};

