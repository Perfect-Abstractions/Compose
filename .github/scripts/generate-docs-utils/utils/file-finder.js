/**
 * File Finder
 * 
 * Functions for finding forge doc output files.
 */

const fs = require('fs');
const path = require('path');
const CONFIG = require('../config');

/**
 * Find forge doc output files for a given source file
 * @param {string} solFilePath - Path to .sol file (e.g., 'src/access/AccessControl/AccessControlMod.sol')
 * @returns {string[]} Array of markdown file paths from forge doc output
 */
function findForgeDocFiles(solFilePath) {
  // Transform: src/access/AccessControl/AccessControlMod.sol
  // To: docs/src/src/access/AccessControl/AccessControlMod.sol/
  const relativePath = solFilePath.replace(/^src\//, '');
  const docsDir = path.join(CONFIG.forgeDocsDir, relativePath);

  if (!fs.existsSync(docsDir)) {
    return [];
  }

  try {
    const files = fs.readdirSync(docsDir);
    return files.filter((f) => f.endsWith('.md')).map((f) => path.join(docsDir, f));
  } catch (error) {
    console.error(`Error reading docs dir ${docsDir}:`, error.message);
    return [];
  }
}

module.exports = {
  findForgeDocFiles,
};

