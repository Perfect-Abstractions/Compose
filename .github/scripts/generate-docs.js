/**
 * Docusaurus Documentation Generator
 *
 * Converts forge doc output to Docusaurus MDX format
 * with optional AI enhancement.
 *
 * Features:
 * - Mirrors src/ folder structure in documentation
 * - Auto-generates category navigation files
 * - AI-enhanced content generation
 *
 * Environment variables:
 *   GITHUB_TOKEN - GitHub token for AI API (optional)
 *   SKIP_ENHANCEMENT - Set to 'true' to skip AI enhancement
 */

const fs = require('fs');
const path = require('path');
const {
  getAllSolFiles,
  findForgeDocFiles,
  isInterface,
  getContractType,
  getOutputPath,
  getSidebarPosition,
  readChangedFilesFromFile,
  extractModuleNameFromPath,
  extractModuleDescriptionFromSource,
  generateDescriptionFromName,
  registerContract,
  getContractRegistry,
  clearContractRegistry,
} = require('./generate-docs-utils/doc-generation-utils');
const { readFileSafe, writeFileSafe } = require('./workflow-utils');
const {
  parseForgeDocMarkdown,
  extractStorageInfo,
  parseIndividualItemFile,
  aggregateParsedItems,
  detectItemTypeFromFilename,
} = require('./generate-docs-utils/forge-doc-parser');
const { generateFacetDoc, generateModuleDoc } = require('./generate-docs-utils/templates/templates');
const { enhanceWithAI, shouldSkipEnhancement, addFallbackContent } = require('./generate-docs-utils/ai-enhancement');
const { syncDocsStructure, regenerateAllIndexFiles } = require('./generate-docs-utils/category/category-generator');

// ============================================================================
// Tracking
// ============================================================================

/** Track processed files for summary */
const processedFiles = {
  facets: [],
  modules: [],
  skipped: [],
  errors: [],
  fallbackFiles: [],
};

// ============================================================================
// Processing Functions
// ============================================================================

/**
 * Process a single forge doc markdown file
 * @param {string} forgeDocFile - Path to forge doc markdown file
 * @param {string} solFilePath - Original .sol file path
 * @returns {Promise<boolean>} True if processed successfully
 */
async function processForgeDocFile(forgeDocFile, solFilePath) {
  const content = readFileSafe(forgeDocFile);
  if (!content) {
    processedFiles.errors.push({ file: forgeDocFile, error: 'Could not read file' });
    return false;
  }

  // Parse the forge doc markdown
  const data = parseForgeDocMarkdown(content, forgeDocFile);

  // Add source file path for parameter extraction
  if (solFilePath) {
    data.sourceFilePath = solFilePath;
  }

  if (!data.title) {
    processedFiles.skipped.push({ file: forgeDocFile, reason: 'No title found' });
    return false;
  }

  // Skip interfaces
  if (isInterface(data.title, content)) {
    processedFiles.skipped.push({ file: forgeDocFile, reason: 'Interface (filtered)' });
    return false;
  }

  // Determine contract type
  const contractType = getContractType(forgeDocFile, content);

  // Extract storage info for modules
  if (contractType === 'module') {
    data.storageInfo = extractStorageInfo(data);
  }

  // Apply smart description fallback for facets with generic descriptions
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
      }
    }
  }

  // Get output path (mirrors src/ structure)
  const pathInfo = getOutputPath(solFilePath, contractType);

  // Get registry for relationship detection
  const registry = getContractRegistry();

  // Get smart sidebar position (uses registry if available)
  data.position = getSidebarPosition(data.title, contractType, pathInfo.category, registry);

  // Set contract type for registry (before registering)
  data.contractType = contractType;

  // Register contract in registry (before AI enhancement so it's available for relationship detection)
  registerContract(data, pathInfo);

  // Check if we should skip AI enhancement
  const skipAIEnhancement = shouldSkipEnhancement(data) || process.env.SKIP_ENHANCEMENT === 'true';

  // Enhance with AI if not skipped
  let enhancedData = data;
  if (!skipAIEnhancement) {
    const token = process.env.GITHUB_TOKEN;
    const result = await enhanceWithAI(data, contractType, token);
    enhancedData = result.data;
    // Track fallback usage
    if (result.usedFallback) {
      processedFiles.fallbackFiles.push({
        title: data.title,
        file: pathInfo.outputFile,
        error: result.error || 'Unknown error'
      });
    }
    // Ensure contractType is preserved after AI enhancement
    enhancedData.contractType = contractType;
  } else {
    enhancedData = addFallbackContent(data, contractType);
    // Ensure contractType is preserved
    enhancedData.contractType = contractType;
  }

  // Generate MDX content with registry for relationship detection
  const mdxContent = contractType === 'module' 
    ? generateModuleDoc(enhancedData, enhancedData.position, pathInfo, registry)
    : generateFacetDoc(enhancedData, enhancedData.position, pathInfo, registry);

  // Ensure output directory exists
  fs.mkdirSync(pathInfo.outputDir, { recursive: true });

  // Write the file
  if (writeFileSafe(pathInfo.outputFile, mdxContent)) {
    if (contractType === 'module') {
      processedFiles.modules.push({ title: data.title, file: pathInfo.outputFile });
    } else {
      processedFiles.facets.push({ title: data.title, file: pathInfo.outputFile });
    }

    return true;
  }

  processedFiles.errors.push({ file: pathInfo.outputFile, error: 'Could not write file' });
  return false;
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
 * @returns {Promise<boolean>} True if processed successfully
 */
async function processAggregatedFiles(forgeDocFiles, solFilePath) {
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
    processedFiles.errors.push({ file: solFilePath, error: 'No valid items parsed' });
    return false;
  }

  const data = aggregateParsedItems(parsedItems, solFilePath);

  data.sourceFilePath = solFilePath;

  if (!data.title) {
    data.title = extractModuleNameFromPath(solFilePath);
  }

  // Try to get description from source file
  const sourceDescription = extractModuleDescriptionFromSource(solFilePath);
  if (sourceDescription) {
    data.description = sourceDescription;
    data.subtitle = sourceDescription;
    data.overview = sourceDescription;
  } else {
    // Use smart description generator
    const generatedDescription = generateDescriptionFromName(data.title);
    if (generatedDescription) {
      data.description = generatedDescription;
      data.subtitle = generatedDescription;
      data.overview = generatedDescription;
    } else {
      // Last resort fallback
      const genericDescription = `Module providing internal functions for ${data.title}`;
      if (
        !data.description ||
        data.description.includes('Event emitted') ||
        data.description.includes('Thrown when')
      ) {
        data.description = genericDescription;
        data.subtitle = genericDescription;
        data.overview = genericDescription;
      }
    }
  }

  if (gitSource) {
    data.gitSource = gitSource;
  }

  const contractType = getContractType(solFilePath, '');

  if (contractType === 'module') {
    data.storageInfo = extractStorageInfo(data);
  }

  // Get output path (mirrors src/ structure)
  const pathInfo = getOutputPath(solFilePath, contractType);

  // Get registry for relationship detection
  const registry = getContractRegistry();

  // Get smart sidebar position (uses registry if available)
  data.position = getSidebarPosition(data.title, contractType, pathInfo.category, registry);

  // Set contract type for registry (before registering)
  data.contractType = contractType;

  // Register contract in registry (before AI enhancement so it's available for relationship detection)
  registerContract(data, pathInfo);

  const skipAIEnhancement = shouldSkipEnhancement(data) || process.env.SKIP_ENHANCEMENT === 'true';

  let enhancedData = data;
  if (!skipAIEnhancement) {
    const token = process.env.GITHUB_TOKEN;
    const result = await enhanceWithAI(data, contractType, token);
    enhancedData = result.data;
    // Track fallback usage
    if (result.usedFallback) {
      processedFiles.fallbackFiles.push({
        title: data.title,
        file: pathInfo.outputFile,
        error: result.error || 'Unknown error'
      });
    }
    // Ensure contractType is preserved after AI enhancement
    enhancedData.contractType = contractType;
  } else {
    enhancedData = addFallbackContent(data, contractType);
    // Ensure contractType is preserved
    enhancedData.contractType = contractType;
  }

  // Generate MDX content with registry for relationship detection
  const mdxContent = contractType === 'module' 
    ? generateModuleDoc(enhancedData, enhancedData.position, pathInfo, registry)
    : generateFacetDoc(enhancedData, enhancedData.position, pathInfo, registry);

  // Ensure output directory exists
  fs.mkdirSync(pathInfo.outputDir, { recursive: true });

  // Write the file
  if (writeFileSafe(pathInfo.outputFile, mdxContent)) {
    if (contractType === 'module') {
      processedFiles.modules.push({ title: data.title, file: pathInfo.outputFile });
    } else {
      processedFiles.facets.push({ title: data.title, file: pathInfo.outputFile });
    }

    return true;
  }

  processedFiles.errors.push({ file: pathInfo.outputFile, error: 'Could not write file' });
  return false;
}

/**
 * Process a Solidity source file
 * @param {string} solFilePath - Path to .sol file
 * @returns {Promise<void>}
 */
async function processSolFile(solFilePath) {
  const forgeDocFiles = findForgeDocFiles(solFilePath);

  if (forgeDocFiles.length === 0) {
    processedFiles.skipped.push({ file: solFilePath, reason: 'No forge doc output' });
    return;
  }

  if (needsAggregation(forgeDocFiles)) {
    await processAggregatedFiles(forgeDocFiles, solFilePath);
  } else {
    for (const forgeDocFile of forgeDocFiles) {
      await processForgeDocFile(forgeDocFile, solFilePath);
    }
  }
}

// ============================================================================
// Summary & Reporting
// ============================================================================

/**
 * Print processing summary
 */
function printSummary() {
  console.log('\n' + '='.repeat(50));
  console.log('Documentation Generation Summary');
  console.log('='.repeat(50));

  console.log(`\nFacets generated: ${processedFiles.facets.length}`);
  for (const f of processedFiles.facets) {
    console.log(`   - ${f.title}`);
  }

  console.log(`\nModules generated: ${processedFiles.modules.length}`);
  for (const m of processedFiles.modules) {
    console.log(`   - ${m.title}`);
  }

  if (processedFiles.skipped.length > 0) {
    console.log(`\nSkipped: ${processedFiles.skipped.length}`);
    for (const s of processedFiles.skipped) {
      console.log(`   - ${path.basename(s.file)}: ${s.reason}`);
    }
  }

  if (processedFiles.errors.length > 0) {
    console.log(`\nErrors: ${processedFiles.errors.length}`);
    for (const e of processedFiles.errors) {
      console.log(`   - ${path.basename(e.file)}: ${e.error}`);
    }
  }

  if (processedFiles.fallbackFiles.length > 0) {
    console.log(`\n⚠️  Files using fallback due to AI errors: ${processedFiles.fallbackFiles.length}`);
    for (const f of processedFiles.fallbackFiles) {
      console.log(`   - ${f.title}: ${f.error}`);
    }
  }

  const total = processedFiles.facets.length + processedFiles.modules.length;
  console.log(`\nTotal generated: ${total} documentation files`);
  console.log('='.repeat(50) + '\n');
}

/**
 * Write summary to file for GitHub Action
 */
function writeSummaryFile() {
  const summary = {
    timestamp: new Date().toISOString(),
    facets: processedFiles.facets,
    modules: processedFiles.modules,
    skipped: processedFiles.skipped,
    errors: processedFiles.errors,
    fallbackFiles: processedFiles.fallbackFiles,
    totalGenerated: processedFiles.facets.length + processedFiles.modules.length,
  };

  writeFileSafe('docgen-summary.json', JSON.stringify(summary, null, 2));
}

// ============================================================================
// Main Entry Point
// ============================================================================

/**
 * Main entry point
 */
async function main() {
  console.log('Compose Documentation Generator\n');

  // Step 0: Clear contract registry
  clearContractRegistry();

  // Step 1: Sync docs structure with src structure
  console.log('📁 Syncing documentation structure with source...');
  const syncResult = syncDocsStructure();

  if (syncResult.created.length > 0) {
    console.log(`   Created ${syncResult.created.length} new categories:`);
    syncResult.created.forEach((c) => console.log(`      ✅ ${c}`));
  }
  console.log(`   Total categories: ${syncResult.total}\n`);

  // Step 2: Determine which files to process
  const args = process.argv.slice(2);
  let solFiles = [];

  if (args.includes('--all')) {
    console.log('Processing all Solidity files...');
    solFiles = getAllSolFiles();
  } else if (args.length > 0 && !args[0].startsWith('--')) {
    const changedFilesPath = args[0];
    console.log(`Reading changed files from: ${changedFilesPath}`);
    solFiles = readChangedFilesFromFile(changedFilesPath);

    if (solFiles.length === 0) {
      console.log('No files in list, checking git diff...');
      const { getChangedSolFiles } = require('./generate-docs-utils/doc-generation-utils');
      solFiles = getChangedSolFiles();
    }
  } else {
    console.log('Getting changed Solidity files from git...');
    const { getChangedSolFiles } = require('./generate-docs-utils/doc-generation-utils');
    solFiles = getChangedSolFiles();
  }

  if (solFiles.length === 0) {
    console.log('No Solidity files to process');
    return;
  }

  console.log(`Found ${solFiles.length} Solidity file(s) to process\n`);

  // Step 3: Process each file
  for (const solFile of solFiles) {
    await processSolFile(solFile);
  }

  // Step 4: Regenerate all index pages now that docs are created
  console.log('📄 Regenerating category index pages...');
  const indexResult = regenerateAllIndexFiles(true);
  if (indexResult.regenerated.length > 0) {
    console.log(`   Regenerated ${indexResult.regenerated.length} index pages`);
  }
  console.log('');

  // Step 5: Print summary
  printSummary();
  writeSummaryFile();
}

main().catch((error) => {
  console.error(`Fatal error: ${error}`);
  process.exit(1);
});
