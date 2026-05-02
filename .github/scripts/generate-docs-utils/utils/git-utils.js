/**
 * Git Utilities
 * 
 * Functions for interacting with git to find changed files.
 */

const { execSync } = require('child_process');
const { readFileSafe } = require('../../workflow-utils');

/**
 * Get list of changed Solidity files from git diff
 * @param {string} baseBranch - Base branch to compare against
 * @returns {string[]} Array of changed .sol file paths
 */
function getChangedSolFiles(baseBranch = 'HEAD~1') {
  try {
    const output = execSync(`git diff --name-only ${baseBranch} HEAD -- 'src/**/*.sol'`, {
      encoding: 'utf8',
    });
    return output
      .trim()
      .split('\n')
      .filter((f) => f.endsWith('.sol'));
  } catch (error) {
    console.error('Error getting changed files:', error.message);
    return [];
  }
}

/**
 * Get all Solidity files in src directory
 * @returns {string[]} Array of .sol file paths
 */
function getAllSolFiles() {
  try {
    const output = execSync('find src -name "*.sol" -type f', {
      encoding: 'utf8',
    });
    return output
      .trim()
      .split('\n')
      .filter((f) => f);
  } catch (error) {
    console.error('Error getting all sol files:', error.message);
    return [];
  }
}

/**
 * Read changed files from a file (used in CI)
 * @param {string} filePath - Path to file containing list of changed files
 * @returns {string[]} Array of file paths
 */
function readChangedFilesFromFile(filePath) {
  const content = readFileSafe(filePath);
  if (!content) {
    return [];
  }
  return content
    .trim()
    .split('\n')
    .filter((f) => f.endsWith('.sol'));
}

module.exports = {
  getChangedSolFiles,
  getAllSolFiles,
  readChangedFilesFromFile,
};

