/**
 * Contract Registry System
 *
 * Tracks all contracts (modules and facets) for relationship detection
 * and cross-reference generation in documentation.
 *
 * Features:
 * - Register contracts with metadata (name, type, category, path)
 * - Provide registry access for relationship detection and other operations
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
// Exports
// ============================================================================

module.exports = {
  // Registry management
  registerContract,
  getContractRegistry,
  clearContractRegistry,
};

