/**
 * Description Manager
 * 
 * Handles description generation and fallback logic for contracts.
 * Consolidates description generation from multiple sources.
 */

const { extractModuleDescriptionFromSource } = require('../utils/source-parser');
const { generateDescriptionFromName } = require('./description-generator');

/**
 * Apply description fallback logic to contract data
 * @param {object} data - Contract documentation data
 * @param {'module' | 'facet'} contractType - Type of contract
 * @param {string} solFilePath - Path to source Solidity file
 * @returns {object} Data with description applied
 */
function applyDescriptionFallback(data, contractType, solFilePath) {
  // For modules, try to get description from source file first
  if (contractType === 'module' && solFilePath) {
    const sourceDescription = extractModuleDescriptionFromSource(solFilePath);
    if (sourceDescription) {
      data.description = sourceDescription;
      data.subtitle = sourceDescription;
      data.overview = sourceDescription;
      return data;
    }
  }

  // For facets, check if description is generic and needs replacement
  if (contractType === 'facet') {
    const looksLikeEnum =
      data.description &&
      /\w+\s*=\s*\d+/.test(data.description) &&
      (data.description.match(/\w+\s*=\s*\d+/g) || []).length >= 2;

    const isGenericDescription =
      !data.description ||
      data.description.startsWith('Contract documentation for') ||
      looksLikeEnum ||
      data.description.length < 20;

    if (isGenericDescription) {
      const generatedDescription = generateDescriptionFromName(data.title);
      if (generatedDescription) {
        data.description = generatedDescription;
        data.subtitle = generatedDescription;
        data.overview = generatedDescription;
        return data;
      }
    }
  }

  // For modules, try generating from name
  if (contractType === 'module') {
    const generatedDescription = generateDescriptionFromName(data.title);
    if (generatedDescription) {
      data.description = generatedDescription;
      data.subtitle = generatedDescription;
      data.overview = generatedDescription;
      return data;
    }

    // Last resort fallback for modules
    const genericDescription = `Module providing internal functions for ${data.title}`;
    if (
      !data.description ||
      data.description.includes('Event emitted') ||
      data.description.includes('Thrown when') ||
      data.description.includes('function to')
    ) {
      data.description = genericDescription;
      data.subtitle = genericDescription;
      data.overview = genericDescription;
    }
  }

  return data;
}

module.exports = {
  applyDescriptionFallback,
};

