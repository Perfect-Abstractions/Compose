/**
 * Fallback Content Provider
 * 
 * Provides fallback content when AI enhancement is unavailable.
 * Centralizes fallback content logic to avoid duplication.
 */

const { loadPrompts } = require('./prompt-loader');

/**
 * Add fallback content when AI is unavailable
 * @param {object} data - Documentation data
 * @param {'module' | 'facet'} contractType - Type of contract
 * @returns {object} Data with fallback content
 */
function addFallbackContent(data, contractType) {
  const prompts = loadPrompts();
  const enhanced = { ...data };

  if (contractType === 'module') {
    enhanced.integrationNotes = prompts.moduleFallback.integrationNotes ||
      `This module accesses shared diamond storage, so changes made through this module are immediately visible to facets using the same storage pattern. All functions are internal as per Compose conventions.`;
    enhanced.keyFeatures = prompts.moduleFallback.keyFeatures ||
      `- All functions are \`internal\` for use in custom facets\n- Follows diamond storage pattern (EIP-8042)\n- Compatible with ERC-2535 diamonds\n- No external dependencies or \`using\` directives`;
  } else {
    enhanced.keyFeatures = prompts.facetFallback.keyFeatures ||
      `- Self-contained facet with no imports or inheritance\n- Only \`external\` and \`internal\` function visibility\n- Follows Compose readability-first conventions\n- Ready for diamond integration`;
  }

  return enhanced;
}

module.exports = {
  addFallbackContent,
};

