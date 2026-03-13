/**
 * Description Generator
 * 
 * Generates fallback descriptions from contract names.
 */

const CONFIG = require('../config');

/**
 * Generate a fallback description from contract name
 *
 * This is a minimal, generic fallback used only when:
 * 1. No NatSpec @title/@notice exists in source
 * 2. AI enhancement will improve it later
 *
 * The AI enhancement step receives this as input and generates
 * a richer, context-aware description from the actual code.
 *
 * @param {string} contractName - Name of the contract
 * @returns {string} Generic description (will be enhanced by AI)
 */
function generateDescriptionFromName(contractName) {
  if (!contractName) return '';

  // Detect library type from naming convention
  const isModule = contractName.endsWith('Mod') || contractName.endsWith('Module');
  const isFacet = contractName.endsWith('Facet');
  const typeLabel = isModule ? 'module' : isFacet ? 'facet' : 'library';

  // Remove suffix and convert CamelCase to readable text
  const baseName = contractName
    .replace(/Mod$/, '')
    .replace(/Module$/, '')
    .replace(/Facet$/, '');

  // Convert CamelCase to readable format
  // Handles: ERC20 -> ERC-20, AccessControl -> Access Control
  const readable = baseName
    .replace(/([a-z])([A-Z])/g, '$1 $2') // camelCase splits
    .replace(/([A-Z]+)([A-Z][a-z])/g, '$1 $2') // acronym handling
    .replace(/^ERC(\d+)/, 'ERC-$1') // ERC20 -> ERC-20
    .trim();

  return `${readable} ${typeLabel} for Compose diamonds`;
}

/**
 * Compute an optional sidebar label for a contract.
 *
 * For diamond category, uses config diamondSidebarLabels (e.g. "Module", "Inspect Facet").
 * For other library categories, returns minimal "Facet" or "Module". Utilities keep null.
 *
 * @param {'facet' | 'module' | string} contractType
 * @param {string} category
 * @param {string} [contractName] - Contract name (e.g. DiamondMod), used for diamond-specific labels
 * @returns {string|null} Sidebar label or null when no override should be used
 */
function getSidebarLabel(contractType, category, contractName) {
  if (!contractType) return null;

  const normalizedCategory = (category || '').toLowerCase();

  // Diamond: use short labels from config (e.g. "Module", "Inspect Facet", "Upgrade Module")
  if (normalizedCategory === 'diamond' && contractName && CONFIG.diamondSidebarLabels && CONFIG.diamondSidebarLabels[contractName]) {
    return CONFIG.diamondSidebarLabels[contractName];
  }

  if (normalizedCategory === 'utils') {
    return null;
  }

  if (contractType === 'facet') {
    return 'Facet';
  }

  if (contractType === 'module') {
    return 'Module';
  }

  return null;
}

/**
 * Format contract name as display title for page headers and frontmatter.
 * Adds spacing (splits camelCase) and expands "Mod" to "Module".
 *
 * @param {string} contractName - Raw contract name (e.g. OwnerDataMod, ERC20TransferFacet)
 * @returns {string} Display title (e.g. "Owner Data Module", "ERC-20 Transfer Facet")
 */
function formatDisplayTitle(contractName) {
  if (!contractName || typeof contractName !== 'string') return '';

  const withSpaces = contractName
    .replace(/^ERC(\d+)/, 'ERC-$1')
    .replace(/([a-z])([A-Z])/g, '$1 $2')
    .replace(/(\d)([A-Z])/g, '$1 $2')
    .replace(/([A-Z]+)([A-Z][a-z])/g, '$1 $2')
    .trim();

  const withModule = withSpaces.replace(/\s+Mod$/, ' Module');
  return withModule;
}

module.exports = {
  generateDescriptionFromName,
  getSidebarLabel,
  formatDisplayTitle,
};

