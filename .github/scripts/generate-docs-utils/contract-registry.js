/**
 * Contract Registry System
 *
 * Tracks all contracts (modules and facets) for relationship detection
 * and cross-reference generation in documentation.
 *
 * Features:
 * - Register contracts with metadata (name, type, category, path)
 * - Find related contracts (module/facet pairs, same category, extensions)
 * - Enrich documentation data with relationship information
 */

// ============================================================================
// Registry State
// ============================================================================

/**
 * Global registry to track all contracts for relationship detection
 * This allows us to find related contracts and generate cross-references
 */
const contractRegistry = {
  byName: new Map(),
  byCategory: new Map(),
  byType: { modules: [], facets: [] }
};

// ============================================================================
// Registry Management
// ============================================================================

/**
 * Register a contract in the global registry
 * @param {object} contractData - Contract documentation data
 * @param {object} outputPath - Output path information from getOutputPath
 * @returns {object} Registered contract entry
 */
function registerContract(contractData, outputPath) {
  // Construct full path including filename (without .mdx extension)
  // This ensures RelatedDocs links point to the actual page, not the category index
  const fullPath = outputPath.relativePath 
    ? `${outputPath.relativePath}/${outputPath.fileName}`
    : outputPath.fileName;
  
  const entry = {
    name: contractData.title,
    type: contractData.contractType, // 'module' or 'facet'
    category: outputPath.category,
    path: fullPath,
    sourcePath: contractData.sourceFilePath,
    functions: contractData.functions || [],
    storagePosition: contractData.storageInfo?.storagePosition
  };
  
  contractRegistry.byName.set(contractData.title, entry);
  
  if (!contractRegistry.byCategory.has(outputPath.category)) {
    contractRegistry.byCategory.set(outputPath.category, []);
  }
  contractRegistry.byCategory.get(outputPath.category).push(entry);
  
  if (contractData.contractType === 'module') {
    contractRegistry.byType.modules.push(entry);
  } else {
    contractRegistry.byType.facets.push(entry);
  }
  
  return entry;
}

/**
 * Get the contract registry
 * @returns {object} The contract registry
 */
function getContractRegistry() {
  return contractRegistry;
}

/**
 * Clear the contract registry (useful for testing or reset)
 */
function clearContractRegistry() {
  contractRegistry.byName.clear();
  contractRegistry.byCategory.clear();
  contractRegistry.byType.modules = [];
  contractRegistry.byType.facets = [];
}

// ============================================================================
// Relationship Detection
// ============================================================================

/**
 * Find related contracts for a given contract
 * @param {string} contractName - Name of the contract
 * @param {string} contractType - Type of contract ('module' or 'facet')
 * @param {string} category - Category of the contract
 * @param {object} registry - Contract registry (optional, uses global if not provided)
 * @returns {Array} Array of related contract objects with title, href, description, icon
 */
function findRelatedContracts(contractName, contractType, category, registry = null) {
  const reg = registry || contractRegistry;
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
  
  return related.slice(0, 6); // Limit to 6 related items
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

// ============================================================================
// Exports
// ============================================================================

module.exports = {
  // Registry management
  registerContract,
  getContractRegistry,
  clearContractRegistry,
  
  // Relationship detection
  findRelatedContracts,
  enrichWithRelationships,
};

