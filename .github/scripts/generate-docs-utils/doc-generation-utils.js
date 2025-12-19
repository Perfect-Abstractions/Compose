const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');
const { readFileSafe } = require('../workflow-utils');
const CONFIG = require('./config');

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
    return output.trim().split('\n').filter(f => f.endsWith('.sol'));
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
    return output.trim().split('\n').filter(f => f);
  } catch (error) {
    console.error('Error getting all sol files:', error.message);
    return [];
  }
}

/**
 * Find forge doc output files for a given source file
 * @param {string} solFilePath - Path to .sol file (e.g., 'src/access/AccessControl/LibAccessControl.sol')
 * @returns {string[]} Array of markdown file paths from forge doc output
 */
function findForgeDocFiles(solFilePath) {
  // Transform: src/access/AccessControl/LibAccessControl.sol
  // To: docs/src/src/access/AccessControl/LibAccessControl.sol/
  const relativePath = solFilePath.replace(/^src\//, '');
  const docsDir = path.join(CONFIG.forgeDocsDir, relativePath);

  if (!fs.existsSync(docsDir)) {
    return [];
  }

  try {
    const files = fs.readdirSync(docsDir);
    return files
      .filter(f => f.endsWith('.md'))
      .map(f => path.join(docsDir, f));
  } catch (error) {
    console.error(`Error reading docs dir ${docsDir}:`, error.message);
    return [];
  }
}

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
  // Forge doc marks interfaces with "interface" in the first few lines
  if (content) {
    const firstLines = content.split('\n').slice(0, 20).join('\n').toLowerCase();
    if (firstLines.includes('interface ') || firstLines.includes('*interface*')) {
      return true;
    }
  }
  
  return false;
}

/**
 * Extract module name from file path
 * @param {string} filePath - Path to the file (e.g., 'src/modules/LibNonReentrancy.sol' or 'constants.LibNonReentrancy.md')
 * @returns {string} Module name (e.g., 'LibNonReentrancy')
 */
function extractModuleNameFromPath(filePath) {
  const path = require('path');
  
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
  
  // Extract from directory structure (e.g., docs/src/src/libraries/LibNonReentrancy.sol/function.enter.md)
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
 * Check if a line is a code element declaration (event, error, function, struct, etc.)
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
 * Only extracts TRUE file-level comments (those with @title, or comments not immediately followed by code elements)
 * Skips comments that belong to events, errors, functions, etc.
 * @param {string} solFilePath - Path to the Solidity source file
 * @returns {string} Description extracted from @title and @notice tags, or empty string
 */
function extractModuleDescriptionFromSource(solFilePath) {
  const content = readFileSafe(solFilePath);
  if (!content) {
    return '';
  }

  const lines = content.split('\n');
  let inComment = false;
  let commentStartLine = -1;
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
      // We hit code without finding a file-level comment
      break;
    }

    // Start of block comment
    if (trimmed.startsWith('/**') || trimmed.startsWith('/*')) {
      inComment = true;
      commentStartLine = i;
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
        break; // Found file-level comment, stop searching
      }
      
      // If next line is a code element (event, error, function, etc.), 
      // this comment belongs to that element, not the file
      if (isCodeElementDeclaration(nextCodeLine)) {
        // This is an item-level comment, skip it and continue looking
        commentBuffer = [];
        continue;
      }
      
      // If it's a standalone comment with @notice (no code element following), use it
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
      // Remove comment markers
      let cleanLine = trimmed.replace(/^\*\s*/, '').replace(/^\s*\*/, '').trim();
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
 * Generate a meaningful description from module/facet name when no source description exists
 * @param {string} contractName - Name of the contract (e.g., "AccessControlMod", "ERC20Facet")
 * @returns {string} Generated description
 */
function generateDescriptionFromName(contractName) {
  if (!contractName) return '';
  
  // Remove common suffixes
  let baseName = contractName
    .replace(/Mod$/, '')
    .replace(/Module$/, '')
    .replace(/Facet$/, '');
  
  // Add spaces before capitals (CamelCase to spaces)
  const readable = baseName
    .replace(/([A-Z])/g, ' $1')
    .replace(/([A-Z]+)([A-Z][a-z])/g, '$1 $2') // Handle acronyms like ERC20
    .trim();
  
  // Detect contract type
  const isModule = contractName.endsWith('Mod') || contractName.endsWith('Module');
  const isFacet = contractName.endsWith('Facet');
  
  // Generate description based on known patterns
  const lowerName = baseName.toLowerCase();
  
  // Common patterns
  if (lowerName.includes('accesscontrol')) {
    if (lowerName.includes('pausable')) {
      return `Role-based access control with pause functionality for Compose diamonds`;
    }
    if (lowerName.includes('temporal')) {
      return `Time-limited role-based access control for Compose diamonds`;
    }
    return `Role-based access control (RBAC) ${isModule ? 'module' : 'facet'} for Compose diamonds`;
  }
  if (lowerName.startsWith('erc20')) {
    const variant = baseName.replace(/^ERC20/, '').trim();
    if (variant) {
      return `ERC-20 token ${variant.toLowerCase()} ${isModule ? 'module' : 'facet'} for Compose diamonds`;
    }
    return `ERC-20 fungible token ${isModule ? 'module' : 'facet'} for Compose diamonds`;
  }
  if (lowerName.startsWith('erc721')) {
    const variant = baseName.replace(/^ERC721/, '').trim();
    if (variant) {
      return `ERC-721 NFT ${variant.toLowerCase()} ${isModule ? 'module' : 'facet'} for Compose diamonds`;
    }
    return `ERC-721 non-fungible token ${isModule ? 'module' : 'facet'} for Compose diamonds`;
  }
  if (lowerName.startsWith('erc1155')) {
    return `ERC-1155 multi-token ${isModule ? 'module' : 'facet'} for Compose diamonds`;
  }
  if (lowerName.startsWith('erc6909')) {
    return `ERC-6909 minimal multi-token ${isModule ? 'module' : 'facet'} for Compose diamonds`;
  }
  if (lowerName.includes('owner')) {
    if (lowerName.includes('twostep')) {
      return `Two-step ownership transfer ${isModule ? 'module' : 'facet'} for Compose diamonds`;
    }
    return `Ownership management ${isModule ? 'module' : 'facet'} for Compose diamonds`;
  }
  if (lowerName.includes('diamond')) {
    if (lowerName.includes('cut')) {
      return `Diamond upgrade (cut) ${isModule ? 'module' : 'facet'} for ERC-2535 diamonds`;
    }
    if (lowerName.includes('loupe')) {
      return `Diamond introspection (loupe) ${isModule ? 'module' : 'facet'} for ERC-2535 diamonds`;
    }
    return `Diamond core ${isModule ? 'module' : 'facet'} for ERC-2535 implementation`;
  }
  if (lowerName.includes('royalty')) {
    return `ERC-2981 royalty ${isModule ? 'module' : 'facet'} for Compose diamonds`;
  }
  if (lowerName.includes('nonreentran') || lowerName.includes('reentrancy')) {
    return `Reentrancy guard ${isModule ? 'module' : 'facet'} for Compose diamonds`;
  }
  if (lowerName.includes('erc165')) {
    return `ERC-165 interface detection ${isModule ? 'module' : 'facet'} for Compose diamonds`;
  }
  
  // Generic fallback
  const typeLabel = isModule ? 'module' : isFacet ? 'facet' : 'contract';
  return `${readable} ${typeLabel} for Compose diamonds`;
}

/**
 * Determine if a contract is a module or facet
 * Modules are Solidity files whose top-level code lives outside of contracts and Solidity libraries.
 * They contain reusable logic that gets pulled into other contracts at compile time.
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
  
  // Default to facet for contracts
  return 'facet';
}

/**
 * Get output directory based on contract type
 * @param {'module' | 'facet'} contractType - Type of contract
 * @returns {string} Output directory path
 */
function getOutputDir(contractType) {
  return contractType === 'module' 
    ? CONFIG.modulesOutputDir 
    : CONFIG.facetsOutputDir;
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
  return content.trim().split('\n').filter(f => f.endsWith('.sol'));
}

module.exports = {
  getChangedSolFiles,
  getAllSolFiles,
  findForgeDocFiles,
  isInterface,
  getContractType,
  getOutputDir,
  readChangedFilesFromFile,
  extractModuleNameFromPath,
  extractModuleDescriptionFromSource,
  generateDescriptionFromName,
};


