/**
 * File Processor
 * 
 * Handles processing of Solidity source files and their forge doc outputs.
 */

const { findForgeDocFiles } = require('../utils/file-finder');
const { isInterface, getContractType } = require('../utils/contract-classifier');
const { extractModuleNameFromPath } = require('../utils/source-parser');
const { readFileSafe } = require('../../workflow-utils');
const { parseForgeDocMarkdown } = require('../parsing/markdown-parser');
const {
  parseIndividualItemFile,
  aggregateParsedItems,
  detectItemTypeFromFilename,
} = require('../parsing/item-parser');
const { processContractData } = require('./contract-processor');

/**
 * Process a single forge doc markdown file
 * @param {string} forgeDocFile - Path to forge doc markdown file
 * @param {string} solFilePath - Original .sol file path
 * @param {object} tracker - Tracker instance
 * @returns {Promise<boolean>} True if processed successfully
 */
async function processForgeDocFile(forgeDocFile, solFilePath, tracker) {
  const content = readFileSafe(forgeDocFile);
  if (!content) {
    tracker.recordError(forgeDocFile, 'Could not read file');
    return false;
  }

  // Parse the forge doc markdown
  const data = parseForgeDocMarkdown(content, forgeDocFile);

  // Add source file path for parameter extraction
  if (solFilePath) {
    data.sourceFilePath = solFilePath;
  }

  if (!data.title) {
    tracker.recordSkipped(forgeDocFile, 'No title found');
    return false;
  }

  // Skip interfaces
  if (isInterface(data.title, content)) {
    tracker.recordSkipped(forgeDocFile, 'Interface (filtered)');
    return false;
  }

  // Determine contract type
  const contractType = getContractType(forgeDocFile, content);

  // Process through shared pipeline (includes description fallback)
  const result = await processContractData(data, solFilePath, contractType, tracker);
  return result.success;
}

/**
 * Check if files need aggregation (individual item files vs contract-level files)
 * @param {string[]} forgeDocFiles - Array of forge doc file paths
 * @returns {boolean} True if files are individual items that need aggregation
 */
function needsAggregation(forgeDocFiles) {
  for (const file of forgeDocFiles) {
    const itemType = detectItemTypeFromFilename(file);
    if (itemType) {
      return true;
    }
  }
  return false;
}

/**
 * Process aggregated files (for free function modules)
 * @param {string[]} forgeDocFiles - Array of forge doc file paths
 * @param {string} solFilePath - Original .sol file path
 * @param {object} tracker - Tracker instance
 * @returns {Promise<boolean>} True if processed successfully
 */
async function processAggregatedFiles(forgeDocFiles, solFilePath, tracker) {
  const parsedItems = [];
  let gitSource = '';

  for (const forgeDocFile of forgeDocFiles) {
    const content = readFileSafe(forgeDocFile);
    if (!content) {
      continue;
    }

    const parsed = parseIndividualItemFile(content, forgeDocFile);
    if (parsed) {
      parsedItems.push(parsed);
      if (parsed.gitSource && !gitSource) {
        gitSource = parsed.gitSource;
      }
    }
  }

  if (parsedItems.length === 0) {
    tracker.recordError(solFilePath, 'No valid items parsed');
    return false;
  }

  const data = aggregateParsedItems(parsedItems, solFilePath);

  data.sourceFilePath = solFilePath;

  if (!data.title) {
    data.title = extractModuleNameFromPath(solFilePath);
  }

  if (gitSource) {
    data.gitSource = gitSource;
  }

  const contractType = getContractType(solFilePath, '');

  // Process through shared pipeline (includes description fallback)
  const result = await processContractData(data, solFilePath, contractType, tracker);
  return result.success;
}

/**
 * Process a Solidity source file
 * @param {string} solFilePath - Path to .sol file
 * @param {object} tracker - Tracker instance
 * @returns {Promise<void>}
 */
async function processSolFile(solFilePath, tracker) {
  const forgeDocFiles = findForgeDocFiles(solFilePath);

  if (forgeDocFiles.length === 0) {
    tracker.recordSkipped(solFilePath, 'No forge doc output');
    return;
  }

  if (needsAggregation(forgeDocFiles)) {
    await processAggregatedFiles(forgeDocFiles, solFilePath, tracker);
  } else {
    for (const forgeDocFile of forgeDocFiles) {
      await processForgeDocFile(forgeDocFile, solFilePath, tracker);
    }
  }
}

module.exports = {
  processSolFile,
};

