/**
 * Markdown Parser
 * 
 * Main parser for forge doc markdown output.
 */

const config = require('../config');
const { createNewItem, saveCurrentItem } = require('./item-builder');
const { sanitizeBrokenLinks, cleanDescription } = require('./text-sanitizer');

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

module.exports = {
  parseForgeDocMarkdown,
};

