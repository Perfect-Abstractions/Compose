/**
 * Context Extractor for AI Documentation Enhancement
 * 
 * Extracts and formats additional context from source files and parsed data
 * to provide richer information to the AI for more accurate documentation generation.
 */

const fs = require('fs');
const path = require('path');
const { readFileSafe } = require('../../workflow-utils');
const { findRelatedContracts } = require('../core/relationship-detector');
const { getContractRegistry } = require('../core/contract-registry');

/**
 * Extract context from source file (pragma, imports, etc.)
 * @param {string} sourceFilePath - Path to the Solidity source file
 * @returns {object} Extracted source context
 */
function extractSourceContext(sourceFilePath) {
  if (!sourceFilePath) {
    return {
      pragmaVersion: null,
      imports: [],
    };
  }

  const sourceContent = readFileSafe(sourceFilePath);
  if (!sourceContent) {
    return {
      pragmaVersion: null,
      imports: [],
    };
  }

  // Extract pragma version
  const pragmaMatch = sourceContent.match(/pragma\s+solidity\s+([^;]+);/);
  const pragmaVersion = pragmaMatch ? pragmaMatch[1].trim() : null;

  // Extract imports
  const importMatches = sourceContent.matchAll(/import\s+["']([^"']+)["']/g);
  const imports = Array.from(importMatches, m => m[1]);

  return {
    pragmaVersion,
    imports,
  };
}

/**
 * Compute import path from source file path
 * Converts: src/access/AccessControl/AccessControlFacet.sol
 * To: @compose/access/AccessControl/AccessControlFacet
 * @param {string} sourceFilePath - Path to the Solidity source file
 * @returns {string} Import path
 */
function computeImportPath(sourceFilePath) {
  if (!sourceFilePath) {
    return null;
  }

  // Remove src/ prefix and .sol extension
  let importPath = sourceFilePath
    .replace(/^src\//, '')
    .replace(/\.sol$/, '');

  // Convert to @compose/ format
  return `@compose/${importPath}`;
}

/**
 * Format complete function signatures with parameter types and return types
 * @param {Array} functions - Array of function objects
 * @returns {string} Formatted function signatures
 */
function formatFunctionSignatures(functions) {
  if (!functions || functions.length === 0) {
    return 'None';
  }

  return functions.map(fn => {
    // Format parameters
    const params = (fn.params || []).map(p => {
      const type = p.type || '';
      const name = p.name || '';
      if (!type && !name) return '';
      return name ? `${type} ${name}` : type;
    }).filter(Boolean).join(', ');

    // Format return types
    const returns = (fn.returns || []).map(r => r.type || '').filter(Boolean);
    const returnStr = returns.length > 0 ? ` returns (${returns.join(', ')})` : '';

    // Include visibility and mutability if available in signature
    const signature = fn.signature || '';
    const visibility = signature.match(/\b(public|external|internal|private)\b/)?.[0] || '';
    const mutability = signature.match(/\b(view|pure|payable)\b/)?.[0] || '';
    
    const modifiers = [visibility, mutability].filter(Boolean).join(' ');

    return `function ${fn.name}(${params})${modifiers ? ' ' + modifiers : ''}${returnStr}`;
  }).join('\n');
}

/**
 * Format storage context information
 * @param {object} storageInfo - Storage info object
 * @param {Array} structs - Array of struct definitions
 * @param {Array} stateVariables - Array of state variables
 * @returns {string} Formatted storage context
 */
function formatStorageContext(storageInfo, structs, stateVariables) {
  const parts = [];

  // Extract storage position from state variables
  const storagePositionVar = (stateVariables || []).find(v => 
    v.name && (v.name.includes('STORAGE_POSITION') || v.name.includes('STORAGE') || v.name.includes('_POSITION'))
  );

  if (storagePositionVar) {
    parts.push(`Storage Position: ${storagePositionVar.name}`);
    if (storagePositionVar.value) {
      parts.push(`Value: ${storagePositionVar.value}`);
    }
    if (storagePositionVar.description) {
      parts.push(`Description: ${storagePositionVar.description}`);
    }
  }

  // Extract storage struct
  const storageStruct = (structs || []).find(s => 
    s.name && s.name.includes('Storage')
  );

  if (storageStruct) {
    parts.push(`Storage Struct: ${storageStruct.name}`);
    if (storageStruct.definition) {
      // Extract key fields from struct definition
      const fieldMatches = storageStruct.definition.matchAll(/(\w+)\s+(\w+)(?:\[.*?\])?;/g);
      const fields = Array.from(fieldMatches, m => `${m[1]} ${m[2]}`);
      if (fields.length > 0) {
        parts.push(`Key Fields: ${fields.slice(0, 5).join(', ')}${fields.length > 5 ? '...' : ''}`);
      }
    }
  }

  // Add storage info if available
  if (storageInfo) {
    if (typeof storageInfo === 'string') {
      parts.push(storageInfo);
    } else if (storageInfo.storagePosition) {
      parts.push(`Storage Position: ${storageInfo.storagePosition}`);
    }
  }

  return parts.length > 0 ? parts.join('\n') : 'None';
}

/**
 * Format related contracts context
 * @param {string} contractName - Name of the contract
 * @param {string} contractType - Type of contract ('module' or 'facet')
 * @param {string} category - Category of the contract
 * @param {object} registry - Contract registry (optional)
 * @returns {string} Formatted related contracts context
 */
function formatRelatedContracts(contractName, contractType, category, registry = null) {
  const related = findRelatedContracts(contractName, contractType, category, registry);
  
  if (related.length === 0) {
    return 'None';
  }

  return related.map(r => `- ${r.title}: ${r.description}`).join('\n');
}

/**
 * Format struct definitions with field types
 * @param {Array} structs - Array of struct objects
 * @returns {string} Formatted struct definitions
 */
function formatStructDefinitions(structs) {
  if (!structs || structs.length === 0) {
    return 'None';
  }

  return structs.map(s => {
    const fields = (s.fields || []).map(f => {
      const type = f.type || '';
      const name = f.name || '';
      return name ? `${type} ${name}` : type;
    }).join(', ');

    return `struct ${s.name} { ${fields} }`;
  }).join('\n');
}

/**
 * Format event signatures with parameters
 * @param {Array} events - Array of event objects
 * @returns {string} Formatted event signatures
 */
function formatEventSignatures(events) {
  if (!events || events.length === 0) {
    return 'None';
  }

  return events.map(e => {
    const params = (e.params || []).map(p => {
      const indexed = p.indexed ? 'indexed ' : '';
      const type = p.type || '';
      const name = p.name || '';
      return name ? `${indexed}${type} ${name}` : `${indexed}${type}`;
    }).join(', ');

    return `event ${e.name}(${params})`;
  }).join('\n');
}

/**
 * Format error signatures with parameters
 * @param {Array} errors - Array of error objects
 * @returns {string} Formatted error signatures
 */
function formatErrorSignatures(errors) {
  if (!errors || errors.length === 0) {
    return 'None';
  }

  return errors.map(e => {
    const params = (e.params || []).map(p => {
      const type = p.type || '';
      const name = p.name || '';
      return name ? `${type} ${name}` : type;
    }).join(', ');

    return `error ${e.name}(${params})`;
  }).join('\n');
}

module.exports = {
  extractSourceContext,
  computeImportPath,
  formatFunctionSignatures,
  formatStorageContext,
  formatRelatedContracts,
  formatStructDefinitions,
  formatEventSignatures,
  formatErrorSignatures,
};

