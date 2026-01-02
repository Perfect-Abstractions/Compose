/**
 * Prompt Builder
 * 
 * Builds system and user prompts for AI enhancement.
 */

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
const { getContractRegistry } = require('../core/contract-registry');
const { loadPrompts, loadRepoInstructions } = require('./prompt-loader');

/**
 * Build the system prompt with repository context
 * Uses the system prompt from the prompts file, or a fallback if not found
 * @returns {string} System prompt for AI
 */
function buildSystemPrompt() {
  const prompts = loadPrompts();
  const repoInstructions = loadRepoInstructions();

  let systemPrompt = prompts.systemPrompt || `You are a Solidity smart contract documentation expert for the Compose framework. 
Always respond with valid JSON only, no markdown formatting.
Follow the project conventions and style guidelines strictly.`;

  if (repoInstructions) {
    const relevantSections = prompts.relevantSections.length > 0
      ? prompts.relevantSections
      : [
          '## 3. Core Philosophy',
          '## 4. Facet Design Principles', 
          '## 5. Banned Solidity Features',
          '## 6. Composability Guidelines',
          '## 11. Code Style Guide',
        ];
    
    let contextSnippets = [];
    for (const section of relevantSections) {
      const startIdx = repoInstructions.indexOf(section);
      if (startIdx !== -1) {
        // Extract section content (up to next ## or 2000 chars max)
        const nextSection = repoInstructions.indexOf('\n## ', startIdx + section.length);
        const endIdx = nextSection !== -1 ? nextSection : startIdx + 2000;
        const snippet = repoInstructions.slice(startIdx, Math.min(endIdx, startIdx + 2000));
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
 * Build the prompt for AI based on contract type
 * @param {object} data - Parsed documentation data
 * @param {'module' | 'facet'} contractType - Type of contract
 * @returns {string} Prompt for AI
 */
function buildPrompt(data, contractType) {
  const prompts = loadPrompts();

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
    ? prompts.modulePrompt 
    : prompts.facetPrompt;

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

module.exports = {
  buildSystemPrompt,
  buildPrompt,
};

