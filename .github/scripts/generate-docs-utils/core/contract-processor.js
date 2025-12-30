/**
 * Contract Processing Pipeline
 * 
 * Shared processing logic for both regular and aggregated contract files.
 * Handles the complete pipeline from parsed data to written MDX file.
 */

const fs = require('fs');
const { extractStorageInfo } = require('../parsing/storage-extractor');
const { getOutputPath } = require('../utils/path-computer');
const { getSidebarPosition } = require('../utils/sidebar-position-calculator');
const { registerContract, getContractRegistry } = require('./contract-registry');
const { generateFacetDoc, generateModuleDoc } = require('../templates/templates');
const { enhanceWithAI, shouldSkipEnhancement } = require('../ai/ai-enhancement');
const { addFallbackContent } = require('../ai/fallback-content-provider');
const { applyDescriptionFallback } = require('./description-manager');
const { writeFileSafe } = require('../../workflow-utils');

/**
 * Process contract data through the complete pipeline
 * @param {object} data - Parsed documentation data
 * @param {string} solFilePath - Path to source Solidity file
 * @param {'module' | 'facet'} contractType - Type of contract
 * @param {object} tracker - Tracker object for recording results (temporary, will be replaced with SummaryTracker)
 * @returns {Promise<{success: boolean, error?: string}>} Processing result
 */
async function processContractData(data, solFilePath, contractType, tracker) {
  // 1. Extract storage info for modules
  if (contractType === 'module') {
    data.storageInfo = extractStorageInfo(data);
  }

  // 2. Apply description fallback
  data = applyDescriptionFallback(data, contractType, solFilePath);

  // 3. Compute output path (mirrors src/ structure)
  const pathInfo = getOutputPath(solFilePath, contractType);

  // 4. Get registry for relationship detection
  const registry = getContractRegistry();

  // 5. Get smart sidebar position (uses registry if available)
  data.position = getSidebarPosition(data.title, contractType, pathInfo.category, registry);

  // 6. Set contract type for registry (before registering)
  data.contractType = contractType;

  // 7. Register contract in registry (before AI enhancement so it's available for relationship detection)
  registerContract(data, pathInfo);

  // 8. Enhance with AI if not skipped
  const skipAIEnhancement = shouldSkipEnhancement(data) || process.env.SKIP_ENHANCEMENT === 'true';
  let enhancedData = data;
  let usedFallback = false;
  let enhancementError = null;

  if (!skipAIEnhancement) {
    const token = process.env.GITHUB_TOKEN;
    const result = await enhanceWithAI(data, contractType, token);
    enhancedData = result.data;
    usedFallback = result.usedFallback;
    enhancementError = result.error;
    
    // Track fallback usage
    if (usedFallback) {
      tracker.recordFallback(data.title, pathInfo.outputFile, enhancementError || 'Unknown error');
    }
  } else {
    enhancedData = addFallbackContent(data, contractType);
  }

  // Ensure contractType is preserved after AI enhancement
  enhancedData.contractType = contractType;

  // 9. Generate MDX content with registry for relationship detection
  const mdxContent = contractType === 'module' 
    ? generateModuleDoc(enhancedData, enhancedData.position, pathInfo, registry)
    : generateFacetDoc(enhancedData, enhancedData.position, pathInfo, registry);

  // 10. Ensure output directory exists
  fs.mkdirSync(pathInfo.outputDir, { recursive: true });

  // 11. Write the file
  if (writeFileSafe(pathInfo.outputFile, mdxContent)) {
    // Track success
    if (contractType === 'module') {
      tracker.recordModule(data.title, pathInfo.outputFile);
    } else {
      tracker.recordFacet(data.title, pathInfo.outputFile);
    }
    return { success: true };
  }

  // Track write error
  tracker.recordError(pathInfo.outputFile, 'Could not write file');
  return { success: false, error: 'Could not write file' };
}

module.exports = {
  processContractData,
};

