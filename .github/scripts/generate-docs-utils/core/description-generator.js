/**
 * Description Generator
 * 
 * Generates fallback descriptions from contract names.
 */

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

module.exports = {
  generateDescriptionFromName,
};

