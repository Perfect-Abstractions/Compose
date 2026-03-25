/**
 * Item Parser
 * 
 * Functions for parsing individual item files and aggregating them.
 */

const path = require('path');
const config = require('../config');
const { sanitizeBrokenLinks, cleanDescription } = require('./text-sanitizer');

/**
 * Detect item type from filename
 * @param {string} filePath - Path to the markdown file
 * @returns {string | null} Item type ('function', 'error', 'struct', 'event', 'enum', 'constants', or null)
 */
function detectItemTypeFromFilename(filePath) {
  const basename = path.basename(filePath);
  
  if (basename.startsWith('function.')) return 'function';
  if (basename.startsWith('error.')) return 'error';
  if (basename.startsWith('struct.')) return 'struct';
  if (basename.startsWith('event.')) return 'event';
  if (basename.startsWith('enum.')) return 'enum';
  if (basename.startsWith('constants.')) return 'constants';
  
  return null;
}

/**
 * Parse an individual item file (function, error, constant, etc.)
 * @param {string} content - Markdown content from forge doc
 * @param {string} filePath - Path to the markdown file
 * @returns {object | null} Parsed item object or null if parsing fails
 */
function parseIndividualItemFile(content, filePath) {
  const itemType = detectItemTypeFromFilename(filePath);
  if (!itemType) {
    return null;
  }

  const lines = content.split('\n');
  let itemName = '';
  let gitSource = '';
  let description = '';
  let signature = '';
  let definition = '';
  let descriptionBuffer = [];
  let inCodeBlock = false;
  let codeBlockLines = [];
  let params = [];
  let returns = [];
  let constants = [];

  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];
    const trimmedLine = line.trim();

    // Parse title (# heading)
    if (line.startsWith('# ') && !itemName) {
      itemName = line.replace('# ', '').trim();
      continue;
    }

    // Parse git source link
    if (trimmedLine.startsWith('[Git Source]')) {
      const match = trimmedLine.match(/\[Git Source\]\((.*?)\)/);
      if (match) {
        gitSource = config.normalizeGitSource(match[1]);
      }
      continue;
    }

    // Parse code block
    if (line.startsWith('```solidity')) {
      inCodeBlock = true;
      codeBlockLines = [];
      i++;
      while (i < lines.length && !lines[i].startsWith('```')) {
        codeBlockLines.push(lines[i]);
        i++;
      }
      const codeContent = codeBlockLines.join('\n').trim();
      
      if (itemType === 'constants') {
        // For constants, parse multiple constant definitions
        // Format: "bytes32 constant NON_REENTRANT_SLOT = keccak256(...)"
        // Handle both single and multiple constants in one code block
        const constantMatches = codeContent.match(/(\w+(?:\s*\d+)?)\s+constant\s+(\w+)\s*=\s*(.+?)(?:\s*;)?/g);
        if (constantMatches) {
          for (const match of constantMatches) {
            const parts = match.match(/(\w+(?:\s*\d+)?)\s+constant\s+(\w+)\s*=\s*(.+?)(?:\s*;)?$/);
            if (parts) {
              constants.push({
                name: parts[2],
                type: parts[1],
                value: parts[3].trim(),
                description: descriptionBuffer.join(' ').trim(),
              });
            }
          }
        } else {
          // Single constant definition (more flexible regex)
          const singleMatch = codeContent.match(/(\w+(?:\s*\d+)?)\s+constant\s+(\w+)\s*=\s*(.+?)(?:\s*;)?$/);
          if (singleMatch) {
            constants.push({
              name: singleMatch[2],
              type: singleMatch[1],
              value: singleMatch[3].trim(),
              description: descriptionBuffer.join(' ').trim(),
            });
          }
        }
        // Clear description buffer after processing constants
        descriptionBuffer = [];
      } else {
        signature = codeContent;
      }
      inCodeBlock = false;
      continue;
    }

    // Parse constants with ### heading format
    if (itemType === 'constants' && line.startsWith('### ')) {
      const constantName = line.replace('### ', '').trim();
      // Clear description buffer for this constant (only text before this heading)
      // Filter out code block delimiters and empty lines
      const currentConstantDesc = descriptionBuffer
        .filter(l => l && !l.trim().startsWith('```') && l.trim() !== '')
        .join(' ')
        .trim();
      descriptionBuffer = [];
      
      // Look ahead for code block (within next 15 lines)
      let foundCodeBlock = false;
      let codeBlockEndIndex = i;
      for (let j = i + 1; j < lines.length && j < i + 15; j++) {
        if (lines[j].startsWith('```solidity')) {
          foundCodeBlock = true;
          const constCodeLines = [];
          j++;
          while (j < lines.length && !lines[j].startsWith('```')) {
            constCodeLines.push(lines[j]);
            j++;
          }
          codeBlockEndIndex = j; // j now points to the line after closing ```
          const constCode = constCodeLines.join('\n').trim();
          // Match: type constant name = value
          // Handle complex types like "bytes32", "uint256", etc.
          const constMatch = constCode.match(/(\w+(?:\s*\d+)?)\s+constant\s+(\w+)\s*=\s*(.+?)(?:\s*;)?$/);
          if (constMatch) {
            constants.push({
              name: constantName,
              type: constMatch[1],
              value: constMatch[3].trim(),
              description: currentConstantDesc,
            });
          } else {
            // Fallback: if no match, still add constant with name from heading
            constants.push({
              name: constantName,
              type: '',
              value: constCode,
              description: currentConstantDesc,
            });
          }
          break;
        }
      }
      if (!foundCodeBlock) {
        // No code block found, but we have a heading - might be a constant without definition
        // This shouldn't happen in forge doc output, but handle it gracefully
        constants.push({
          name: constantName,
          type: '',
          value: '',
          description: currentConstantDesc,
        });
      } else {
        // Skip to the end of the code block (the loop will increment i, so we set it to one before)
        i = codeBlockEndIndex - 1;
      }
      continue;
    }

    // Collect description (text before code block or after title)
    // Skip code block delimiters, empty lines, and markdown table separators
    if (!inCodeBlock && trimmedLine && 
        !trimmedLine.startsWith('#') && 
        !trimmedLine.startsWith('[') && 
        !trimmedLine.startsWith('|') &&
        !trimmedLine.startsWith('```') &&
        trimmedLine !== '') {
      if (itemType !== 'constants' || !line.startsWith('###')) {
        descriptionBuffer.push(trimmedLine);
      }
      continue;
    }

    // Parse table rows (Parameters or Returns)
    if (trimmedLine.startsWith('|') && !trimmedLine.includes('----')) {
      const cells = trimmedLine.split('|').map(c => c.trim()).filter(c => c);
      
      if (cells.length >= 3 && cells[0] !== 'Name' && cells[0] !== 'Parameter') {
        const paramName = cells[0].replace(/`/g, '').trim();
        const paramType = cells[1].replace(/`/g, '').trim();
        const paramDesc = sanitizeBrokenLinks(cells[2] || '');

        // Determine if Parameters or Returns based on preceding lines
        const precedingLines = lines.slice(Math.max(0, i - 10), i).join('\n');
        
        if (precedingLines.includes('**Returns**')) {
          returns.push({
            name: paramName === '<none>' ? '' : paramName,
            type: paramType,
            description: paramDesc,
          });
        } else if (precedingLines.includes('**Parameters**')) {
          if (paramType || paramName.startsWith('_')) {
            params.push({
              name: paramName,
              type: paramType,
              description: paramDesc,
            });
          }
        }
      }
    }
  }

  // Combine description buffer and clean it
  if (descriptionBuffer.length > 0) {
    description = cleanDescription(sanitizeBrokenLinks(descriptionBuffer.join(' ').trim()));
  }

  // For constants, return array of constant objects
  if (itemType === 'constants') {
    return {
      type: 'constants',
      constants: constants.length > 0 ? constants : [{
        name: itemName || 'Constants',
        type: '',
        value: '',
        description: description,
      }],
      gitSource: gitSource,
    };
  }

  // For structs, use definition instead of signature
  if (itemType === 'struct') {
    definition = signature;
    signature = '';
  }

  // Create item object based on type
  const item = {
    name: itemName,
    description: description,
    notice: description,
    signature: signature,
    definition: definition,
    params: params,
    returns: returns,
    gitSource: gitSource,
  };

  // Add mutability for functions
  if (itemType === 'function' && signature) {
    if (signature.includes(' view ')) {
      item.mutability = 'view';
    } else if (signature.includes(' pure ')) {
      item.mutability = 'pure';
    } else if (signature.includes(' payable ')) {
      item.mutability = 'payable';
    } else {
      item.mutability = 'nonpayable';
    }
  }

  return {
    type: itemType,
    item: item,
  };
}

/**
 * Aggregate multiple parsed items into a single data structure
 * @param {Array} parsedItems - Array of parsed item objects from parseIndividualItemFile
 * @param {string} sourceFilePath - Path to the source Solidity file
 * @returns {object} Aggregated documentation data
 */
function aggregateParsedItems(parsedItems, sourceFilePath) {
  const data = {
    title: '',
    description: '',
    subtitle: '',
    overview: '',
    gitSource: '',
    functions: [],
    events: [],
    errors: [],
    structs: [],
    stateVariables: [],
  };

  // Extract module name from source file path
  const basename = path.basename(sourceFilePath, '.sol');
  data.title = basename;

  // Extract git source from first item
  for (const parsed of parsedItems) {
    if (parsed && parsed.gitSource) {
      data.gitSource = config.normalizeGitSource(parsed.gitSource);
      break;
    }
  }

  // Group items by type
  for (const parsed of parsedItems) {
    if (!parsed) continue;

    if (parsed.type === 'function' && parsed.item) {
      data.functions.push(parsed.item);
    } else if (parsed.type === 'error' && parsed.item) {
      data.errors.push(parsed.item);
    } else if (parsed.type === 'event' && parsed.item) {
      data.events.push(parsed.item);
    } else if (parsed.type === 'struct' && parsed.item) {
      data.structs.push(parsed.item);
    } else if (parsed.type === 'enum' && parsed.item) {
      // Enums can be treated as structs for display purposes
      data.structs.push(parsed.item);
    } else if (parsed.type === 'constants' && parsed.constants) {
      // Add constants as state variables
      for (const constant of parsed.constants) {
        data.stateVariables.push({
          name: constant.name,
          type: constant.type,
          value: constant.value,
          description: constant.description,
        });
      }
    }
  }

  // Set default description if not provided
  // Don't use item descriptions as module description - they'll be overridden by source file parsing
  if (!data.description || 
      data.description.includes('Event emitted') || 
      data.description.includes('Thrown when') ||
      data.description.includes('function to') ||
      data.description.length < 20) {
    data.description = `Documentation for ${data.title}`;
    data.subtitle = data.description;
    data.overview = data.description;
  }

  return data;
}

module.exports = {
  detectItemTypeFromFilename,
  parseIndividualItemFile,
  aggregateParsedItems,
};

