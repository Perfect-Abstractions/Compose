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
  let foundFirstCodeElement = false;

  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];
    const trimmed = line.trim();

    // Skip SPDX and pragma lines
    if (trimmed.startsWith('// SPDX') || trimmed.startsWith('pragma ')) {
      continue;
    }

    // Check if we've reached the first function/constant/error (end of file-level comments)
    if (trimmed && !trimmed.startsWith('//') && !trimmed.startsWith('/*') && !trimmed.startsWith('*') && 
        (trimmed.startsWith('function ') || trimmed.startsWith('error ') || trimmed.startsWith('event ') || 
         trimmed.startsWith('struct ') || trimmed.startsWith('enum ') || trimmed.match(/^\w+\s+constant/))) {
      foundFirstCodeElement = true;
      // If we're in a comment, finish processing it first
      if (inComment) {
        // Process the comment we were collecting
        const commentText = commentBuffer.join(' ');
        const titleMatch = commentText.match(/@title\s+(.+?)(?:\s+@|\s*\*\/|$)/);
        if (titleMatch) {
          title = titleMatch[1].trim();
        }
        const noticeMatch = commentText.match(/@notice\s+(.+?)(?:\s+@|\s*\*\/|$)/);
        if (noticeMatch) {
          notice = noticeMatch[1].trim();
        }
      }
      break;
    }

    // Start of block comment
    if (trimmed.startsWith('/*')) {
      inComment = true;
      commentBuffer = [];
      continue;
    }

    // End of block comment
    if (inComment && trimmed.includes('*/')) {
      inComment = false;
      const commentText = commentBuffer.join(' ');
      
      // Extract @title
      const titleMatch = commentText.match(/@title\s+(.+?)(?:\s+@|\s*\*\/|$)/);
      if (titleMatch) {
        title = titleMatch[1].trim();
      }

      // Extract @notice
      const noticeMatch = commentText.match(/@notice\s+(.+?)(?:\s+@|\s*\*\/|$)/);
      if (noticeMatch) {
        notice = noticeMatch[1].trim();
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
 * Determine if a contract is a module or facet
 * Modules are Solidity files whose top-level code lives outside of contracts and Solidity libraries.
 * They contain reusable logic that gets pulled into other contracts at compile time.
 * @param {string} filePath - Path to the file
 * @param {string} content - File content
 * @returns {'module' | 'facet'} Contract type
 */
function getContractType(filePath, content) {
  const lowerPath = filePath.toLowerCase();
  
  // Check path patterns - files with 'lib' in the path are modules
  if (lowerPath.includes('lib')) {
    return 'module';
  }
  
  if (lowerPath.includes('facet')) {
    return 'facet';
  }

  // Check content patterns - files with 'library' keyword (Solidity libraries) are modules
  if (content && content.includes('library ')) {
    return 'module';
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
};


