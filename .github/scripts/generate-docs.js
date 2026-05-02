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

const { clearContractRegistry } = require('./generate-docs-utils/core/contract-registry');
const { syncDocsStructure, regenerateAllIndexFiles } = require('./generate-docs-utils/category/category-generator');
const { processSolFile } = require('./generate-docs-utils/core/file-processor');
const { getFilesToProcess } = require('./generate-docs-utils/core/file-selector');
const { SummaryTracker } = require('./generate-docs-utils/tracking/summary-tracker');


// ============================================================================
// Main Entry Point
// ============================================================================

/**
 * Main entry point
 */
async function main() {
  console.log('Compose Documentation Generator\n');

  // Initialize tracker
  const tracker = new SummaryTracker();

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
  const solFiles = getFilesToProcess(args);

  if (solFiles.length === 0) {
    console.log('No Solidity files to process');
    return;
  }

  console.log(`Found ${solFiles.length} Solidity file(s) to process\n`);

  // Step 3: Process each file
  for (const solFile of solFiles) {
    await processSolFile(solFile, tracker);
  }

  // Step 4: Regenerate all index pages now that docs are created
  console.log('📄 Regenerating category index pages...');
  const indexResult = regenerateAllIndexFiles(true);
  if (indexResult.regenerated.length > 0) {
    console.log(`   Regenerated ${indexResult.regenerated.length} index pages`);
  }
  console.log('');

  // Step 5: Print summary
  tracker.printSummary();
  tracker.writeSummaryFile();
}

main().catch((error) => {
  console.error(`Fatal error: ${error}`);
  process.exit(1);
});
