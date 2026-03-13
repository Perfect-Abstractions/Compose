/**
 * Source Parser
 * 
 * Functions for parsing Solidity source files to extract information.
 */

const path = require('path');
const { readFileSafe } = require('../../workflow-utils');

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

module.exports = {
  extractModuleNameFromPath,
  extractModuleDescriptionFromSource,
  isCodeElementDeclaration,
};

