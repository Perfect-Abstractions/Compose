/**
 * Sidebar Position Calculator
 * 
 * Calculates sidebar positions for contracts in documentation.
 */

const CONFIG = require('../config');
const { getContractRegistry } = require('../core/contract-registry');

/**
 * Get sidebar position for a contract
 * @param {string} contractName - Name of the contract
 * @param {string} contractType - Type of contract ('module' or 'facet')
 * @param {string} category - Category of the contract
 * @param {object} registry - Contract registry (optional, uses global if not provided)
 * @returns {number} Sidebar position
 */
function getSidebarPosition(contractName, contractType = null, category = null, registry = null) {
  // First check explicit config
  if (CONFIG.contractPositions && CONFIG.contractPositions[contractName] !== undefined) {
    return CONFIG.contractPositions[contractName];
  }
  
  // If we don't have enough info, use default
  if (!contractType || !category) {
    return CONFIG.defaultSidebarPosition || 50;
  }
  
  // Calculate smart position based on:
  // 1. Category base offset
  const categoryOffsets = {
    diamond: 0,
    access: 100,
    token: 200,
    utils: 300,
    interfaceDetection: 400
  };
  
  let basePosition = categoryOffsets[category] || 500;
  
  // 2. Contract type offset (modules before facets)
  const typeOffset = contractType === 'module' ? 0 : 10;
  basePosition += typeOffset;
  
  // 3. Position within category based on dependencies
  const reg = registry || getContractRegistry();
  if (reg && reg.byCategory.has(category)) {
    const categoryContracts = reg.byCategory.get(category) || [];
    const sameTypeContracts = categoryContracts.filter(c => c.type === contractType);
    
    // Sort by name for consistent ordering
    sameTypeContracts.sort((a, b) => a.name.localeCompare(b.name));
    
    const index = sameTypeContracts.findIndex(c => c.name === contractName);
    if (index !== -1) {
      basePosition += index;
    }
  }
  
  return basePosition;
}

module.exports = {
  getSidebarPosition,
};

