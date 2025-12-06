/**
 * Docusaurus Documentation Generator
 * 
 * Converts forge doc output to Docusaurus MDX format
 * with optional GitHub Copilot enhancement.
 * 
 * Environment variables:
 *   GITHUB_TOKEN - GitHub token for Copilot API (optional)
 *   SKIP_ENHANCEMENT - Set to 'true' to skip Copilot enhancement
 */

const path = require('path');
const {
  getAllSolFiles,
  findForgeDocFiles,
  isInterface,
  getContractType,
  getOutputDir,
  readChangedFilesFromFile,
  extractModuleNameFromPath,
  extractModuleDescriptionFromSource,
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

// Track processed files for summary
const processedFiles = {
  facets: [],
  modules: [],
  skipped: [],
  errors: [],
};

/**
 * Process a single forge doc markdown file
 * @param {string} forgeDocFile - Path to forge doc markdown file
 * @param {string} solFilePath - Original .sol file path
 * @returns {Promise<boolean>} True if processed successfully
 */
async function processForgeDocFile(forgeDocFile, solFilePath) {
  const content = readFileSafe(forgeDocFile);
  if (!content) {
    console.log(`Could not read: ${forgeDocFile}`);
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
    console.log(`Could not parse title from: ${forgeDocFile}`);
    processedFiles.skipped.push({ file: forgeDocFile, reason: 'No title found' });
    return false;
  }

  // Skip interfaces - only generate docs for facets and modules
  if (isInterface(data.title, content)) {
    console.log(`Skipping interface: ${data.title}`);
    processedFiles.skipped.push({ file: forgeDocFile, reason: 'Interface (filtered)' });
    return false;
  }

  // Determine contract type
  const contractType = getContractType(forgeDocFile, content);
  console.log(`Type: ${contractType} - ${data.title}`);

  // Extract storage info for modules
  if (contractType === 'module') {
    data.storageInfo = extractStorageInfo(data);
  }

  // Check if we should skip AI enhancement (e.g., for interfaces or when SKIP_ENHANCEMENT is set)
  const skipAIEnhancement = shouldSkipEnhancement(data) || process.env.SKIP_ENHANCEMENT === 'true';

  // Enhance with Copilot if not skipped, otherwise add fallback content
  let enhancedData = data;
  if (!skipAIEnhancement) {
    const token = process.env.GITHUB_TOKEN;
    enhancedData = await enhanceWithCopilot(data, contractType, token);
  } else {
    console.log(`Skipping AI enhancement for ${data.title}`);
    // Add fallback content when skipping AI enhancement
    const { addFallbackContent } = require('./generate-docs-utils/copilot-enhancement');
    enhancedData = addFallbackContent(data, contractType);
  }

  const mdxContent = contractType === 'module'
    ? generateModuleDoc(enhancedData)
    : generateFacetDoc(enhancedData);

  const outputDir = getOutputDir(contractType);
  const outputFile = path.join(outputDir, `${data.title}.mdx`);

  if (writeFileSafe(outputFile, mdxContent)) {
    console.log('✅  Generated:', outputFile);
    
    if (contractType === 'module') {
      processedFiles.modules.push({ title: data.title, file: outputFile });
    } else {
      processedFiles.facets.push({ title: data.title, file: outputFile });
    }
    
    return true;
  }

  processedFiles.errors.push({ file: outputFile, error: 'Could not write file' });
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
  console.log(`Aggregating ${forgeDocFiles.length} files for: ${solFilePath}`);

  const parsedItems = [];
  let gitSource = '';

  for (const forgeDocFile of forgeDocFiles) {
    const content = readFileSafe(forgeDocFile);
    if (!content) {
      console.log(`Could not read: ${forgeDocFile}`);
      continue;
    }

    console.log(`Reading: ${path.basename(forgeDocFile)}`);
    const parsed = parseIndividualItemFile(content, forgeDocFile);
    if (parsed) {
      parsedItems.push(parsed);
      if (parsed.gitSource && !gitSource) {
        gitSource = parsed.gitSource;
      }
    }
  }

  if (parsedItems.length === 0) {
    console.log(`No valid items found in files for: ${solFilePath}`);
    processedFiles.errors.push({ file: solFilePath, error: 'No valid items parsed' });
    return false;
  }

  const data = aggregateParsedItems(parsedItems, solFilePath);
  
  data.sourceFilePath = solFilePath;

  if (!data.title) {
    data.title = extractModuleNameFromPath(solFilePath);
  }

  const sourceDescription = extractModuleDescriptionFromSource(solFilePath);
  if (sourceDescription) {
    data.description = sourceDescription;
    data.subtitle = sourceDescription;
    data.overview = sourceDescription;
  } else {
    // Use a generic description if no source description found
    const genericDescription = `Module providing internal functions for ${data.title}`;
    if (!data.description || data.description.includes('Event emitted') || data.description.includes('Thrown when')) {
      data.description = genericDescription;
      data.subtitle = genericDescription;
      data.overview = genericDescription;
    }
  }

  if (gitSource) {
    data.gitSource = gitSource;
  }

  const contractType = getContractType(solFilePath, '');
  console.log(`Type: ${contractType} - ${data.title}`);

  if (contractType === 'module') {
    data.storageInfo = extractStorageInfo(data);
  }

  const skipAIEnhancement = shouldSkipEnhancement(data) || process.env.SKIP_ENHANCEMENT === 'true';

  let enhancedData = data;
  if (!skipAIEnhancement) {
    const token = process.env.GITHUB_TOKEN;
    enhancedData = await enhanceWithAI(data, contractType, token);
  } else {
    console.log(`Skipping AI enhancement for ${data.title}`);
    // Add fallback content when skipping AI enhancement
    enhancedData = addFallbackContent(data, contractType);
  }

  // Generate MDX content
  const mdxContent = contractType === 'module'
    ? generateModuleDoc(enhancedData)
    : generateFacetDoc(enhancedData);

  // Determine output path
  const outputDir = getOutputDir(contractType);
  const outputFile = path.join(outputDir, `${data.title}.mdx`);

  // Write the file
  if (writeFileSafe(outputFile, mdxContent)) {
    console.log('✅  Generated:', outputFile);
    
    if (contractType === 'module') {
      processedFiles.modules.push({ title: data.title, file: outputFile });
    } else {
      processedFiles.facets.push({ title: data.title, file: outputFile });
    }
    
    return true;
  }

  processedFiles.errors.push({ file: outputFile, error: 'Could not write file' });
  return false;
}

/**
 * Process a Solidity source file
 * @param {string} solFilePath - Path to .sol file
 * @returns {Promise<void>}
 */
async function processSolFile(solFilePath) {
  console.log(`Processing: ${solFilePath}`);

  const forgeDocFiles = findForgeDocFiles(solFilePath);

  if (forgeDocFiles.length === 0) {
    console.log(`No forge doc output found for: ${solFilePath}`);
    processedFiles.skipped.push({ file: solFilePath, reason: 'No forge doc output' });
    return;
  }

  if (needsAggregation(forgeDocFiles)) {
    await processAggregatedFiles(forgeDocFiles, solFilePath);
  } else {
    for (const forgeDocFile of forgeDocFiles) {
      console.log(`Reading: ${path.basename(forgeDocFile)}`);
      await processForgeDocFile(forgeDocFile, solFilePath);
    }
  }
}

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
    totalGenerated: processedFiles.facets.length + processedFiles.modules.length,
  };

  writeFileSafe('docgen-summary.json', JSON.stringify(summary, null, 2));
}

/**
 * Main entry point
 */
async function main() {
  console.log('Compose Documentation Generator\n');

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

  for (const solFile of solFiles) {
    await processSolFile(solFile);
    console.log('');
  }

  printSummary();
  writeSummaryFile();
}

main().catch((error) => {
  console.error(`Fatal error: ${error}`);
  process.exit(1);
});


