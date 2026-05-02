#!/usr/bin/env node
/**
 * Sync Documentation Structure
 *
 * Standalone script to mirror the src/ folder structure in website/docs/library/
 * Creates _category_.json files for Docusaurus navigation.
 *
 * Usage:
 *   node .github/scripts/sync-docs-structure.js [options]
 *
 * Options:
 *   --dry-run    Show what would be created without making changes
 *   --verbose    Show detailed output
 *   --help       Show this help message
 *
 * Examples:
 *   node .github/scripts/sync-docs-structure.js
 *   node .github/scripts/sync-docs-structure.js --dry-run
 */

const fs = require('fs');
const path = require('path');

// Handle running from different directories
const scriptDir = __dirname;
process.chdir(path.join(scriptDir, '../..'));

const { syncDocsStructure, scanSourceStructure } = require('./generate-docs-utils/category/category-generator');

// ============================================================================
// CLI Parsing
// ============================================================================

const args = process.argv.slice(2);
const options = {
  dryRun: args.includes('--dry-run'),
  verbose: args.includes('--verbose'),
  help: args.includes('--help') || args.includes('-h'),
};

// ============================================================================
// Help
// ============================================================================

function showHelp() {
  console.log(`
Sync Documentation Structure

Mirrors the src/ folder structure in website/docs/library/
Creates _category_.json files for Docusaurus navigation.

Usage:
  node .github/scripts/sync-docs-structure.js [options]

Options:
  --dry-run    Show what would be created without making changes
  --verbose    Show detailed output
  --help, -h   Show this help message

Examples:
  node .github/scripts/sync-docs-structure.js
  node .github/scripts/sync-docs-structure.js --dry-run
`);
}

// ============================================================================
// Tree Display
// ============================================================================

/**
 * Display the source structure as a tree
 * @param {Map<string, object>} structure - Structure map from scanSourceStructure
 */
function displayTree(structure) {
  console.log('\n📂 Source Structure (src/)\n');

  // Sort by path for consistent display
  const sorted = Array.from(structure.entries()).sort((a, b) => a[0].localeCompare(b[0]));

  // Build tree visualization
  const tree = new Map();
  for (const [pathStr] of sorted) {
    const parts = pathStr.split('/');
    let current = tree;
    for (const part of parts) {
      if (!current.has(part)) {
        current.set(part, new Map());
      }
      current = current.get(part);
    }
  }

  // Print tree
  function printTree(node, prefix = '', isLast = true) {
    const entries = Array.from(node.entries());
    entries.forEach(([name, children], index) => {
      const isLastItem = index === entries.length - 1;
      const connector = isLastItem ? '└── ' : '├── ';
      const icon = children.size > 0 ? '📁' : '📄';
      console.log(`${prefix}${connector}${icon} ${name}`);

      if (children.size > 0) {
        const newPrefix = prefix + (isLastItem ? '    ' : '│   ');
        printTree(children, newPrefix, isLastItem);
      }
    });
  }

  printTree(tree);
  console.log('');
}

// ============================================================================
// Dry Run Mode
// ============================================================================

/**
 * Simulate sync without making changes
 * @param {Map<string, object>} structure - Structure map
 */
function dryRun(structure) {
  console.log('\n🔍 Dry Run Mode - No changes will be made\n');

  const libraryDir = 'website/docs/library';
  let wouldCreate = 0;
  let alreadyExists = 0;

  // Check base category
  const baseCategoryFile = path.join(libraryDir, '_category_.json');
  if (fs.existsSync(baseCategoryFile)) {
    console.log(`   ✓ ${baseCategoryFile} (exists)`);
    alreadyExists++;
  } else {
    console.log(`   + ${baseCategoryFile} (would create)`);
    wouldCreate++;
  }

  // Check each category
  for (const [relativePath] of structure) {
    const categoryFile = path.join(libraryDir, relativePath, '_category_.json');
    if (fs.existsSync(categoryFile)) {
      if (options.verbose) {
        console.log(`   ✓ ${categoryFile} (exists)`);
      }
      alreadyExists++;
    } else {
      console.log(`   + ${categoryFile} (would create)`);
      wouldCreate++;
    }
  }

  console.log(`\nSummary:`);
  console.log(`   Would create: ${wouldCreate} category files`);
  console.log(`   Already exist: ${alreadyExists} category files`);
  console.log(`\nRun without --dry-run to apply changes.\n`);
}

// ============================================================================
// Main
// ============================================================================

function main() {
  if (options.help) {
    showHelp();
    return;
  }

  console.log('📚 Sync Documentation Structure\n');
  console.log('Scanning src/ directory...');

  const structure = scanSourceStructure();
  console.log(`Found ${structure.size} directories with Solidity files`);

  if (options.verbose || structure.size <= 20) {
    displayTree(structure);
  }

  if (options.dryRun) {
    dryRun(structure);
    return;
  }

  console.log('Creating documentation structure...\n');
  const result = syncDocsStructure();

  // Display results
  console.log('='.repeat(50));
  console.log('Summary');
  console.log('='.repeat(50));
  console.log(`Created:  ${result.created.length} categories`);
  console.log(`Existing: ${result.existing.length} categories`);
  console.log(`Total:    ${result.total} categories`);

  if (result.created.length > 0) {
    console.log('\nNewly created:');
    result.created.forEach((c) => console.log(`   ✅ ${c}`));
  }

  console.log('\n✨ Done!\n');

  // Show next steps
  console.log('Next steps:');
  console.log('   1. Run documentation generator to populate content:');
  console.log('      node .github/scripts/generate-docs.js --all\n');
  console.log('   2. Or generate docs for specific files:');
  console.log('      node .github/scripts/generate-docs.js path/to/changed-files.txt\n');
}

main();

