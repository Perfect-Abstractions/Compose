/**
 * Documentation Generation Utilities
 *
 * Provides helper functions for:
 * - Finding and reading Solidity source files
 * - Detecting contract types (module vs facet)
 * - Computing output paths (mirrors src/ structure)
 * - Extracting documentation from source files
 */

const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');
const { readFileSafe } = require('../workflow-utils');
const CONFIG = require('./config');
const {
  computeOutputPath,
  ensureCategoryFiles,
} = require('./category/category-generator');

// ============================================================================
// Git Integration
// ============================================================================

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

// ============================================================================
// Forge Doc Integration
// ============================================================================

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

// ============================================================================
// Contract Type Detection
// ============================================================================

/**
 * Determine if a contract is an interface
 * Interfaces should be skipped from documentation generation
 * @param {string} title - Contract title/name
 * @param {string} content - File content (forge doc markdown)
 * @returns {boolean} True if this is an interface
 */
function isInterface(title, content) {
  // Check if title follows interface naming convention: starts with "I" followed by uppercase
  if (title && /^I[A-Z]/.test(title)) {
    return true;
  }

  // Check if content indicates it's an interface
  if (content) {
    const firstLines = content.split('\n').slice(0, 20).join('\n').toLowerCase();
    if (firstLines.includes('interface ') || firstLines.includes('*interface*')) {
      return true;
    }
  }

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

// ============================================================================
// Output Path Computation
// ============================================================================

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

/**
 * Get sidebar position for a contract
 * @param {string} contractName - Name of the contract
 * @returns {number} Sidebar position
 */
function getSidebarPosition(contractName) {
  if (CONFIG.contractPositions && CONFIG.contractPositions[contractName] !== undefined) {
    return CONFIG.contractPositions[contractName];
  }
  return CONFIG.defaultSidebarPosition || 50;
}

// ============================================================================
// Source File Parsing
// ============================================================================

/**
 * Extract module name from file path
 * @param {string} filePath - Path to the file
 * @returns {string} Module name
 */
function extractModuleNameFromPath(filePath) {
  // If it's a constants file, extract from filename
  const basename = path.basename(filePath);
  if (basename.startsWith('constants.')) {
    const match = basename.match(/^constants\.(.+)\.md$/);
    if (match) {
      return match[1];
    }
  }

  // Extract from .sol file path
  if (filePath.endsWith('.sol')) {
    return path.basename(filePath, '.sol');
  }

  // Extract from directory structure
  const parts = filePath.split(path.sep);
  for (let i = parts.length - 1; i >= 0; i--) {
    if (parts[i].endsWith('.sol')) {
      return path.basename(parts[i], '.sol');
    }
  }

  // Fallback: use basename without extension
  return path.basename(filePath, path.extname(filePath));
}

/**
 * Check if a line is a code element declaration
 * @param {string} line - Trimmed line to check
 * @returns {boolean} True if line is a code element declaration
 */
function isCodeElementDeclaration(line) {
  if (!line) return false;
  return (
    line.startsWith('function ') ||
    line.startsWith('error ') ||
    line.startsWith('event ') ||
    line.startsWith('struct ') ||
    line.startsWith('enum ') ||
    line.startsWith('contract ') ||
    line.startsWith('library ') ||
    line.startsWith('interface ') ||
    line.startsWith('modifier ') ||
    /^\w+\s+(constant|immutable)\s/.test(line) ||
    /^(bytes32|uint\d*|int\d*|address|bool|string)\s+constant\s/.test(line)
  );
}

/**
 * Extract module description from source file NatSpec comments
 * @param {string} solFilePath - Path to the Solidity source file
 * @returns {string} Description extracted from @title and @notice tags
 */
function extractModuleDescriptionFromSource(solFilePath) {
  const content = readFileSafe(solFilePath);
  if (!content) {
    return '';
  }

  const lines = content.split('\n');
  let inComment = false;
  let commentBuffer = [];
  let title = '';
  let notice = '';

  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];
    const trimmed = line.trim();

    // Skip SPDX and pragma lines
    if (trimmed.startsWith('// SPDX') || trimmed.startsWith('pragma ')) {
      continue;
    }

    // Check if we've reached a code element without finding a file-level comment
    if (!inComment && isCodeElementDeclaration(trimmed)) {
      break;
    }

    // Start of block comment
    if (trimmed.startsWith('/**') || trimmed.startsWith('/*')) {
      inComment = true;
      commentBuffer = [];
      continue;
    }

    // End of block comment
    if (inComment && trimmed.includes('*/')) {
      inComment = false;
      const commentText = commentBuffer.join(' ');

      // Look ahead to see if next non-empty line is a code element
      let nextCodeLine = '';
      for (let j = i + 1; j < lines.length && j < i + 5; j++) {
        const nextTrimmed = lines[j].trim();
        if (nextTrimmed && !nextTrimmed.startsWith('//') && !nextTrimmed.startsWith('/*')) {
          nextCodeLine = nextTrimmed;
          break;
        }
      }

      // If the comment has @title, it's a file-level comment
      const titleMatch = commentText.match(/@title\s+(.+?)(?:\s+@|\s*$)/);
      if (titleMatch) {
        title = titleMatch[1].trim();
        const noticeMatch = commentText.match(/@notice\s+(.+?)(?:\s+@|\s*$)/);
        if (noticeMatch) {
          notice = noticeMatch[1].trim();
        }
        break;
      }

      // If next line is a code element, this comment belongs to that element
      if (isCodeElementDeclaration(nextCodeLine)) {
        commentBuffer = [];
        continue;
      }

      // Standalone comment with @notice
      const standaloneNotice = commentText.match(/@notice\s+(.+?)(?:\s+@|\s*$)/);
      if (standaloneNotice && !isCodeElementDeclaration(nextCodeLine)) {
        notice = standaloneNotice[1].trim();
        break;
      }

      commentBuffer = [];
      continue;
    }

    // Collect comment lines
    if (inComment) {
      let cleanLine = trimmed
        .replace(/^\*\s*/, '')
        .replace(/^\s*\*/, '')
        .trim();
      if (cleanLine && !cleanLine.startsWith('*/')) {
        commentBuffer.push(cleanLine);
      }
    }
  }

  // Combine title and notice
  if (title && notice) {
    return `${title} - ${notice}`;
  } else if (notice) {
    return notice;
  } else if (title) {
    return title;
  }

  return '';
}

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

// ============================================================================
// Exports
// ============================================================================

module.exports = {
  // Git integration
  getChangedSolFiles,
  getAllSolFiles,
  readChangedFilesFromFile,

  // Forge doc integration
  findForgeDocFiles,

  // Contract type detection
  isInterface,
  getContractType,

  // Output path computation
  getOutputPath,
  getSidebarPosition,

  // Source file parsing
  extractModuleNameFromPath,
  extractModuleDescriptionFromSource,
  generateDescriptionFromName,
};
