/**
 * Contract Classifier
 * 
 * Functions for detecting contract types (interface, module, facet).
 */

const path = require('path');

/**
 * Determine if a contract is an interface
 * Interfaces should be skipped from documentation generation
 * Only checks the naming pattern (I[A-Z]) to avoid false positives
 * @param {string} title - Contract title/name
 * @param {string} content - File content (forge doc markdown) - unused but kept for API compatibility
 * @returns {boolean} True if this is an interface
 */
function isInterface(title, content) {
  // Only check if title follows interface naming convention: starts with "I" followed by uppercase
  // This is the most reliable indicator and avoids false positives from content that mentions "interface"
  if (title && /^I[A-Z]/.test(title)) {
    return true;
  }

  // Removed content-based check to avoid false positives
  // Facets and contracts often mention "interface" in their descriptions
  // (e.g., "ERC-165 Standard Interface Detection Facet") which would incorrectly filter them

  return false;
}

/**
 * Determine if a contract is a module or facet
 * @param {string} filePath - Path to the file
 * @param {string} content - File content
 * @returns {'module' | 'facet'} Contract type
 */
function getContractType(filePath, content) {
  const lowerPath = filePath.toLowerCase();
  const normalizedPath = lowerPath.replace(/\\/g, '/');
  const baseName = path.basename(filePath, path.extname(filePath)).toLowerCase();

  // Explicit modules folder
  if (normalizedPath.includes('/modules/')) {
    return 'module';
  }

  // File naming conventions (e.g., AccessControlMod.sol, NonReentrancyModule.sol)
  if (baseName.endsWith('mod') || baseName.endsWith('module')) {
    return 'module';
  }

  if (lowerPath.includes('facet')) {
    return 'facet';
  }

  // Libraries folder typically contains modules
  if (normalizedPath.includes('/libraries/')) {
    return 'module';
  }

  // Default to facet for contracts
  return 'facet';
}

module.exports = {
  isInterface,
  getContractType,
};

