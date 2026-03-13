/**
 * Path Computer
 * 
 * Functions for computing output paths for documentation files.
 */

const {
  computeOutputPath,
  ensureCategoryFiles,
} = require('../category/category-generator');

/**
 * Get output directory and file path based on source file path
 * Mirrors the src/ structure in website/docs/contracts/
 *
 * @param {string} solFilePath - Path to the source .sol file
 * @param {'module' | 'facet'} contractType - Type of contract (for logging)
 * @returns {object} { outputDir, outputFile, relativePath, fileName, category }
 */
function getOutputPath(solFilePath, contractType) {
  // Compute path using the new structure-mirroring logic
  const pathInfo = computeOutputPath(solFilePath);

  // Ensure all parent category files exist
  ensureCategoryFiles(pathInfo.outputDir);

  return pathInfo;
}

module.exports = {
  getOutputPath,
};

