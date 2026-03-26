/**
 * Relationship Detector
 *
 * Detects relationships between contracts (modules and facets) for
 * cross-reference generation in documentation.
 *
 * Features:
 * - Find related contracts (module/facet pairs, same category, extensions)
 * - Enrich documentation data with relationship information
 */

const { getContractRegistry } = require('./contract-registry');

/**
 * Find related contracts for a given contract
 * @param {string} contractName - Name of the contract
 * @param {string} contractType - Type of contract ('module' or 'facet')
 * @param {string} category - Category of the contract
 * @param {object} registry - Contract registry (optional, uses global if not provided)
 * @returns {Array} Array of related contract objects with title, href, description, icon
 */
function findRelatedContracts(contractName, contractType, category, registry = null) {
  const reg = registry || getContractRegistry();
  const related = [];
  const contract = reg.byName.get(contractName);
  if (!contract) return related;
  
  // 1. Find corresponding module/facet pair
  if (contractType === 'facet') {
    const moduleName = contractName.replace('Facet', 'Mod');
    const module = reg.byName.get(moduleName);
    if (module) {
      related.push({
        title: moduleName,
        href: `/docs/library/${module.path}`,
        description: `Module used by ${contractName}`,
        icon: '📦'
      });
    }
  } else if (contractType === 'module') {
    const facetName = contractName.replace('Mod', 'Facet');
    const facet = reg.byName.get(facetName);
    if (facet) {
      related.push({
        title: facetName,
        href: `/docs/library/${facet.path}`,
        description: `Facet using ${contractName}`,
        icon: '💎'
      });
    }
  }
  
  // 2. Find related contracts in same category (excluding self)
  const sameCategory = reg.byCategory.get(category) || [];
  sameCategory.forEach(c => {
    if (c.name !== contractName && c.type === contractType) {
      related.push({
        title: c.name,
        href: `/docs/library/${c.path}`,
        description: `Related ${contractType} in ${category}`,
        icon: contractType === 'module' ? '📦' : '💎'
      });
    }
  });
  
  // 3. Find extension contracts (e.g., ERC20Facet → ERC20BurnFacet)
  if (contractType === 'facet') {
    const baseName = contractName.replace(/BurnFacet$|PermitFacet$|BridgeableFacet$|EnumerableFacet$/, 'Facet');
    if (baseName !== contractName) {
      const base = reg.byName.get(baseName);
      if (base) {
        related.push({
          title: baseName,
          href: `/docs/library/${base.path}`,
          description: `Base facet for ${contractName}`,
          icon: '💎'
        });
      }
    }
  }
  
  // 4. Find core dependencies (e.g., all facets depend on DiamondCutFacet)
  if (contractType === 'facet' && contractName !== 'DiamondCutFacet') {
    const diamondCut = reg.byName.get('DiamondCutFacet');
    if (diamondCut) {
      related.push({
        title: 'DiamondCutFacet',
        href: `/docs/library/${diamondCut.path}`,
        description: 'Required for adding facets to diamonds',
        icon: '🔧'
      });
    }
  }
  
  return related.slice(0, 4); // Limit to 4 related items
}

/**
 * Enrich contract data with relationship information
 * @param {object} data - Contract documentation data
 * @param {object} pathInfo - Output path information
 * @param {object} registry - Contract registry (optional, uses global if not provided)
 * @returns {object} Enriched data with relatedDocs property
 */
function enrichWithRelationships(data, pathInfo, registry = null) {
  const relatedDocs = findRelatedContracts(
    data.title,
    data.contractType,
    pathInfo.category,
    registry
  );
  
  return {
    ...data,
    relatedDocs: relatedDocs.length > 0 ? relatedDocs : null
  };
}

module.exports = {
  findRelatedContracts,
  enrichWithRelationships,
};

