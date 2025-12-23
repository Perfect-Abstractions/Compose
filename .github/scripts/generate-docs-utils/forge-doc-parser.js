/**
 * Parser for forge doc markdown output
 * Extracts structured data from forge-generated markdown files
 */

const config = require('./config');

/**
 * Parse forge doc markdown output into structured data
 * @param {string} content - Markdown content from forge doc
 * @param {string} filePath - Path to the markdown file
 * @returns {object} Parsed documentation data
 */
function parseForgeDocMarkdown(content, filePath) {
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

  const lines = content.split('\n');
  let currentSection = null;
  let currentItem = null;
  let itemType = null;
  let collectingDescription = false;
  let descriptionBuffer = [];

  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];
    const trimmedLine = line.trim();

    // Parse title (# heading)
    if (line.startsWith('# ') && !data.title) {
      data.title = line.replace('# ', '').trim();
      continue;
    }

    // Parse git source link
    if (trimmedLine.startsWith('[Git Source]')) {
      const match = trimmedLine.match(/\[Git Source\]\((.*?)\)/);
      if (match) {
        data.gitSource = config.normalizeGitSource(match[1]);
      }
      continue;
    }

    // Parse description (first non-empty lines after title, before sections)
    if (data.title && !currentSection && trimmedLine && !line.startsWith('#') && !line.startsWith('[')) {
      const sanitizedLine = cleanDescription(sanitizeBrokenLinks(trimmedLine));
      if (!data.description) {
        data.description = sanitizedLine;
        data.subtitle = sanitizedLine;
      } else if (!data.overview) {
        // Capture additional lines as overview
        data.overview = data.description + '\n\n' + sanitizedLine;
      }
      continue;
    }

    // Parse main sections
    if (line.startsWith('## ')) {
      const sectionName = line.replace('## ', '').trim().toLowerCase();
      
      // Save current item before switching sections
      if (currentItem) {
        saveCurrentItem(data, currentItem, itemType);
        currentItem = null;
        itemType = null;
      }

      if (sectionName === 'functions') {
        currentSection = 'functions';
      } else if (sectionName === 'events') {
        currentSection = 'events';
      } else if (sectionName === 'errors') {
        currentSection = 'errors';
      } else if (sectionName === 'structs') {
        currentSection = 'structs';
      } else if (sectionName === 'state variables') {
        currentSection = 'stateVariables';
      } else {
        currentSection = null;
      }
      continue;
    }

    // Parse item definitions (### heading)
    if (line.startsWith('### ') && currentSection) {
      // Save previous item
      if (currentItem) {
        saveCurrentItem(data, currentItem, itemType);
      }

      const name = line.replace('### ', '').trim();
      itemType = currentSection;
      currentItem = createNewItem(name, currentSection);
      collectingDescription = true;
      descriptionBuffer = [];
      continue;
    }

    // Process content within current item
    if (currentItem) {
      // Code block with signature
      if (line.startsWith('```solidity')) {
        const codeLines = [];
        i++;
        while (i < lines.length && !lines[i].startsWith('```')) {
          codeLines.push(lines[i]);
          i++;
        }
        const codeContent = codeLines.join('\n').trim();
        
        if (currentSection === 'functions' || currentSection === 'events' || currentSection === 'errors') {
          currentItem.signature = codeContent;
          
          // Extract mutability from signature
          if (codeContent.includes(' view ')) {
            currentItem.mutability = 'view';
          } else if (codeContent.includes(' pure ')) {
            currentItem.mutability = 'pure';
          } else if (codeContent.includes(' payable ')) {
            currentItem.mutability = 'payable';
          }
        } else if (currentSection === 'structs') {
          currentItem.definition = codeContent;
        } else if (currentSection === 'stateVariables') {
          // Extract type and value from constant definition
          // Format: "bytes32 constant NAME = value;" or "bytes32 NAME = value;"
          // Handle both with and without "constant" keyword
          // Note: name is already known from the ### heading, so we just need type and value
          const constantMatch = codeContent.match(/(\w+(?:\s*\d+)?)\s+(?:constant\s+)?\w+\s*=\s*(.+?)(?:\s*;)?$/);
          if (constantMatch) {
            currentItem.type = constantMatch[1];
            currentItem.value = constantMatch[2].trim();
          } else {
            // Fallback: try to extract just the value part if it's a simple assignment
            const simpleMatch = codeContent.match(/=\s*(.+?)(?:\s*;)?$/);
            if (simpleMatch) {
              currentItem.value = simpleMatch[1].trim();
            }
            // Try to extract type from the beginning
            const typeMatch = codeContent.match(/^(\w+(?:\s*\d+)?)\s+/);
            if (typeMatch) {
              currentItem.type = typeMatch[1];
            }
          }
        }
        continue;
      }

      // Description text (before **Parameters** or **Returns**)
      if (collectingDescription && trimmedLine && !trimmedLine.startsWith('**') && !trimmedLine.startsWith('|')) {
        descriptionBuffer.push(trimmedLine);
        continue;
      }

      // End description collection on special markers
      if (trimmedLine.startsWith('**Parameters**') || trimmedLine.startsWith('**Returns**')) {
        if (descriptionBuffer.length > 0) {
          const description = cleanDescription(sanitizeBrokenLinks(descriptionBuffer.join(' ').trim()));
          currentItem.description = description;
          currentItem.notice = description;
          descriptionBuffer = [];
        }
        collectingDescription = false;
      }

      // Parse table rows (Parameters or Returns)
      if (trimmedLine.startsWith('|') && !trimmedLine.includes('----')) {
        const cells = trimmedLine.split('|').map(c => c.trim()).filter(c => c);
        
        // Skip header row
        if (cells.length >= 3 && cells[0] !== 'Name' && cells[0] !== 'Parameter') {
          const paramName = cells[0].replace(/`/g, '').trim();
          const paramType = cells[1].replace(/`/g, '').trim();
          const paramDesc = sanitizeBrokenLinks(cells[2] || '');

          // Skip if parameter name matches the function name (parsing error)
          if (currentItem && paramName === currentItem.name) {
            continue;
          }

          // Determine if Parameters or Returns based on preceding lines
          const precedingLines = lines.slice(Math.max(0, i - 10), i).join('\n');
          
          if (precedingLines.includes('**Returns**')) {
            currentItem.returns = currentItem.returns || [];
            currentItem.returns.push({
              name: paramName === '<none>' ? '' : paramName,
              type: paramType,
              description: paramDesc,
            });
          } else if (precedingLines.includes('**Parameters**')) {
            // Only add if it looks like a valid parameter (has a type or starts with underscore)
            if (paramType || paramName.startsWith('_')) {
              currentItem.params = currentItem.params || [];
              currentItem.params.push({
                name: paramName,
                type: paramType,
                description: paramDesc,
              });
            }
          }
        }
      }
    }
  }

  // Save last item
  if (currentItem) {
    saveCurrentItem(data, currentItem, itemType);
  }

  // Ensure overview is set
  if (!data.overview) {
    data.overview = data.description || `Documentation for ${data.title}.`;
  }

  return data;
}

/**
 * Create a new item object based on section type
 * @param {string} name - Item name
 * @param {string} section - Section type
 * @returns {object} New item object
 */
function createNewItem(name, section) {
  const base = {
    name,
    description: '',
    notice: '',
  };

  switch (section) {
    case 'functions':
      return {
        ...base,
        signature: '',
        params: [],
        returns: [],
        mutability: 'nonpayable',
      };
    case 'events':
      return {
        ...base,
        signature: '',
        params: [],
      };
    case 'errors':
      return {
        ...base,
        signature: '',
        params: [],
      };
    case 'structs':
      return {
        ...base,
        definition: '',
        fields: [],
      };
    case 'stateVariables':
      return {
        ...base,
        type: '',
        value: '',
      };
    default:
      return base;
  }
}

/**
 * Save current item to data object
 * @param {object} data - Data object to save to
 * @param {object} item - Item to save
 * @param {string} type - Item type
 */
function saveCurrentItem(data, item, type) {
  if (!type || !item) return;

  switch (type) {
    case 'functions':
      data.functions.push(item);
      break;
    case 'events':
      data.events.push(item);
      break;
    case 'errors':
      data.errors.push(item);
      break;
    case 'structs':
      data.structs.push(item);
      break;
    case 'stateVariables':
      data.stateVariables.push(item);
      break;
  }
}

/**
 * Sanitize markdown links that point to non-existent files
 * Removes or converts broken links to plain text
 * @param {string} text - Text that may contain markdown links
 * @returns {string} Sanitized text
 */
function sanitizeBrokenLinks(text) {
  if (!text) return text;
  
  // Remove markdown links that point to /src/ paths (forge doc links)
  // Pattern: [text](/src/...)
  return text.replace(/\[([^\]]+)\]\(\/src\/[^\)]+\)/g, '$1');
}

/**
 * Clean description text by removing markdown artifacts
 * Strips **Parameters**, **Returns**, **Note:** and other section markers
 * that get incorrectly included in descriptions from forge doc output
 * @param {string} text - Description text that may contain markdown artifacts
 * @returns {string} Cleaned description text
 */
function cleanDescription(text) {
  if (!text) return text;
  
  let cleaned = text;
  
  // Remove markdown section headers that shouldn't be in descriptions
  // These patterns appear when forge doc parsing doesn't stop at section boundaries
  const artifactPatterns = [
    /\s*\*\*Parameters\*\*\s*/g,
    /\s*\*\*Returns\*\*\s*/g,
    /\s*\*\*Note:\*\*\s*/g,
    /\s*\*\*Events\*\*\s*/g,
    /\s*\*\*Errors\*\*\s*/g,
    /\s*\*\*See Also\*\*\s*/g,
    /\s*\*\*Example\*\*\s*/g,
  ];
  
  for (const pattern of artifactPatterns) {
    cleaned = cleaned.replace(pattern, ' ');
  }
  
  // Remove @custom: tags that may leak through (e.g., "@custom:error AccessControlUnauthorizedAccount")
  cleaned = cleaned.replace(/@custom:\w+\s+/g, '');
  
  // Clean up "error: ErrorName" patterns that appear inline
  // Keep the error name but format it better: "error: ErrorName If..." -> "Reverts with ErrorName if..."
  cleaned = cleaned.replace(/\berror:\s+(\w+)\s+/gi, 'Reverts with $1 ');
  
  // Normalize whitespace: collapse multiple spaces, trim
  cleaned = cleaned.replace(/\s+/g, ' ').trim();
  
  return cleaned;
}

/**
 * Extract storage information from parsed data
 * @param {object} data - Parsed documentation data
 * @returns {string | null} Storage information or null
 */
function extractStorageInfo(data) {
  // Look for STORAGE_POSITION in state variables
  const storageVar = data.stateVariables.find(v => 
    v.name.includes('STORAGE') || v.name.includes('storage')
  );

  if (storageVar) {
    return `Storage position: \`${storageVar.name}\` - ${storageVar.description || 'Used for diamond storage pattern.'}`;
  }

  // Look for storage struct
  const storageStruct = data.structs.find(s => 
    s.name.includes('Storage')
  );

  if (storageStruct) {
    return `Uses the \`${storageStruct.name}\` struct following the ERC-8042 diamond storage pattern.`;
  }

  return null;
}

/**
 * Detect item type from filename
 * @param {string} filePath - Path to the markdown file
 * @returns {string | null} Item type ('function', 'error', 'struct', 'event', 'enum', 'constants', or null)
 */
function detectItemTypeFromFilename(filePath) {
  const basename = require('path').basename(filePath);
  
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
  const path = require('path');
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
  parseForgeDocMarkdown,
  extractStorageInfo,
  parseIndividualItemFile,
  aggregateParsedItems,
  detectItemTypeFromFilename,
};


