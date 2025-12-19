/**
 * MDX Templates for Docusaurus documentation
 * Uses Handlebars template engine for reliable MDX generation
 */

const { loadAndRenderTemplate } = require('./template-engine-handlebars');
const { sanitizeForMdx } = require('./helpers');
const { readFileSafe } = require('../../workflow-utils');

/**
 * Extract function parameters directly from Solidity source file
 * @param {string} sourceFilePath - Path to the Solidity source file
 * @param {string} functionName - Name of the function to extract parameters from
 * @returns {Array} Array of parameter objects with name and type
 */
function extractParamsFromSource(sourceFilePath, functionName) {
  if (!sourceFilePath || !functionName) return [];
  
  const sourceContent = readFileSafe(sourceFilePath);
  if (!sourceContent) {
    if (process.env.DEBUG_PARAMS) {
      console.log(`[DEBUG] Could not read source file: ${sourceFilePath}`);
    }
    return [];
  }

  // Remove comments to avoid parsing issues
  const withoutComments = sourceContent
    .replace(/\/\*[\s\S]*?\*\//g, '') // Remove block comments
    .replace(/\/\/.*$/gm, ''); // Remove line comments

  // Find function definition - match function name followed by opening parenthesis
  // Handle both regular functions and free functions
  const functionPattern = new RegExp(
    `function\\s+${functionName.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}\\s*\\(([^)]*)\\)`,
    's'
  );
  
  const match = withoutComments.match(functionPattern);
  if (!match || !match[1]) {
    if (process.env.DEBUG_PARAMS) {
      console.log(`[DEBUG] Function ${functionName} not found in source file`);
    }
    return [];
  }

  const paramsStr = match[1].trim();
  if (!paramsStr) {
    return []; // Function has no parameters
  }

  // Parse parameters - handle complex types like mappings, arrays, structs
  const params = [];
  let currentParam = '';
  let depth = 0;
  let inString = false;
  let stringChar = '';

  for (let i = 0; i < paramsStr.length; i++) {
    const char = paramsStr[i];
    
    // Handle string literals
    if ((char === '"' || char === "'") && (i === 0 || paramsStr[i - 1] !== '\\')) {
      if (!inString) {
        inString = true;
        stringChar = char;
      } else if (char === stringChar) {
        inString = false;
      }
      currentParam += char;
      continue;
    }
    
    if (inString) {
      currentParam += char;
      continue;
    }

    // Track nesting depth for generics, arrays, mappings
    if (char === '<' || char === '[' || char === '(') {
      depth++;
      currentParam += char;
    } else if (char === '>' || char === ']' || char === ')') {
      depth--;
      currentParam += char;
    } else if (char === ',' && depth === 0) {
      // Found a parameter boundary
      const trimmed = currentParam.trim();
      if (trimmed) {
        const parsed = parseParameter(trimmed);
        if (parsed) {
          params.push(parsed);
        }
      }
      currentParam = '';
    } else {
      currentParam += char;
    }
  }

  // Handle last parameter
  const trimmed = currentParam.trim();
  if (trimmed) {
    const parsed = parseParameter(trimmed);
    if (parsed) {
      params.push(parsed);
    }
  }

  if (process.env.DEBUG_PARAMS) {
    console.log(`[DEBUG] Extracted ${params.length} params from source for ${functionName}:`, JSON.stringify(params, null, 2));
  }

  return params;
}

/**
 * Parse a single parameter string into name and type
 * @param {string} paramStr - Parameter string (e.g., "uint256 amount" or "address")
 * @returns {object|null} Object with name and type, or null if invalid
 */
function parseParameter(paramStr) {
  if (!paramStr || !paramStr.trim()) return null;

  // Remove storage location keywords
  const cleaned = paramStr
    .replace(/\b(memory|storage|calldata)\b/g, '')
    .replace(/\s+/g, ' ')
    .trim();

  // Split by whitespace - last token is usually the name, rest is type
  const parts = cleaned.split(/\s+/);
  
  if (parts.length === 0) return null;
  
  // If only one part, it's just a type (unnamed parameter)
  if (parts.length === 1) {
    return { name: '', type: parts[0], description: '' };
  }
  
  // Last part is the name, everything before is the type
  const name = parts[parts.length - 1];
  const type = parts.slice(0, -1).join(' ');
  
  // Validate: name should be a valid identifier
  if (!/^[a-zA-Z_$][a-zA-Z0-9_$]*$/.test(name)) {
    // If name doesn't look valid, treat the whole thing as a type
    return { name: '', type: cleaned, description: '' };
  }
  
  return { name, type, description: '' };
}

/**
 * Extract parameters from function signature string
 * @param {string} signature - Function signature string
 * @returns {Array} Array of parameter objects with name and type
 */
function extractParamsFromSignature(signature) {
  if (!signature || typeof signature !== 'string') return [];
  
  // Match function parameters: function name(params) or just (params)
  const paramMatch = signature.match(/\(([^)]*)\)/);
  if (!paramMatch || !paramMatch[1]) return [];
  
  const paramsStr = paramMatch[1].trim();
  if (!paramsStr) return [];
  
  // Split by comma, but be careful with nested generics
  const params = [];
  let currentParam = '';
  let depth = 0;
  
  for (let i = 0; i < paramsStr.length; i++) {
    const char = paramsStr[i];
    if (char === '<') depth++;
    else if (char === '>') depth--;
    else if (char === ',' && depth === 0) {
      const trimmed = currentParam.trim();
      if (trimmed) {
        // Parse "type name" or just "type"
        const parts = trimmed.split(/\s+/);
        if (parts.length >= 2) {
          // Has both type and name
          const type = parts.slice(0, -1).join(' ');
          const name = parts[parts.length - 1];
          params.push({ name, type, description: '' });
        } else if (parts.length === 1) {
          // Just type, no name
          params.push({ name: '', type: parts[0], description: '' });
        }
      }
      currentParam = '';
      continue;
    }
    currentParam += char;
  }
  
  // Handle last parameter
  const trimmed = currentParam.trim();
  if (trimmed) {
    const parts = trimmed.split(/\s+/);
    if (parts.length >= 2) {
      const type = parts.slice(0, -1).join(' ');
      const name = parts[parts.length - 1];
      params.push({ name, type, description: '' });
    } else if (parts.length === 1) {
      params.push({ name: '', type: parts[0], description: '' });
    }
  }
  
  return params;
}

/**
 * Filter function parameters, removing invalid entries
 * Invalid parameters include: empty names or names matching the function name (parsing error)
 * @param {Array} params - Raw parameters array
 * @param {string} functionName - Name of the function (to detect parsing errors)
 * @returns {Array} Filtered and normalized parameters
 */
function filterAndNormalizeParams(params, functionName) {
  return (params || [])
    .filter(p => {
      // Handle different possible data structures
      const paramName = (p && (p.name || p.param || p.parameter || '')).trim();
      const paramType = (p && (p.type || p.paramType || '')).trim();
      
      // Filter out parameters with empty or missing names
      if (!paramName) return false;
      // Filter out parameters where name matches function name (indicates parsing error)
      if (paramName === functionName) {
        if (process.env.DEBUG_PARAMS) {
          console.log(`[DEBUG] Filtered out invalid param: name="${paramName}" matches function name`);
        }
        return false;
      }
      // Filter out if type is empty AND name looks like it might be a function name (starts with lowercase, no underscore)
      if (!paramType && /^[a-z]/.test(paramName) && !paramName.includes('_')) {
        if (process.env.DEBUG_PARAMS) {
          console.log(`[DEBUG] Filtered out suspicious param: name="${paramName}" has no type`);
        }
        return false;
      }
      return true;
    })
    .map(p => ({
      name: (p.name || p.param || p.parameter || '').trim(),
      type: (p.type || p.paramType || '').trim(),
      description: (p.description || p.desc || '').trim(),
    }));
}

/**
 * Prepare function data for template rendering (shared between facet and module)
 * @param {object} fn - Function data
 * @param {string} sourceFilePath - Path to the Solidity source file
 * @param {boolean} useSourceExtraction - Whether to try extracting params from source file (for modules)
 * @returns {object} Prepared function data
 */
function prepareFunctionData(fn, sourceFilePath, useSourceExtraction = false) {
  // Debug: log the raw function data
  if (process.env.DEBUG_PARAMS) {
    console.log(`\n[DEBUG] Function: ${fn.name}`);
    console.log(`[DEBUG] Raw params:`, JSON.stringify(fn.params, null, 2));
    console.log(`[DEBUG] Signature:`, fn.signature);
  }
  
  // Build parameters array, filtering out invalid parameters
  let paramsArray = filterAndNormalizeParams(fn.params, fn.name);
  
  // If no valid parameters found, try extracting from source file (for modules) or signature
  if (paramsArray.length === 0) {
    // Try source file extraction for modules
    if (useSourceExtraction && sourceFilePath) {
      if (process.env.DEBUG_PARAMS) {
        console.log(`[DEBUG] No valid params found, extracting from source file: ${sourceFilePath}`);
      }
      const extractedParams = extractParamsFromSource(sourceFilePath, fn.name);
      if (extractedParams.length > 0) {
        paramsArray = extractedParams;
      }
    }
    
    // Fallback to signature extraction if still no params
    if (paramsArray.length === 0 && fn.signature) {
      if (process.env.DEBUG_PARAMS) {
        console.log(`[DEBUG] No valid params found, extracting from signature`);
      }
      const extractedParams = extractParamsFromSignature(fn.signature);
      paramsArray = filterAndNormalizeParams(extractedParams, fn.name);
      if (process.env.DEBUG_PARAMS) {
        console.log(`[DEBUG] Extracted params from signature:`, JSON.stringify(paramsArray, null, 2));
      }
    }
  }
  
  if (process.env.DEBUG_PARAMS) {
    console.log(`[DEBUG] Final paramsArray:`, JSON.stringify(paramsArray, null, 2));
  }
  
  // Build returns array for table rendering
  const returnsArray = (fn.returns || []).map(r => ({
    name: r.name || '-',
    type: r.type,
    description: r.description || '',
  }));

  return {
    name: fn.name,
    signature: fn.signature,
    description: fn.notice || fn.description || '',
    params: paramsArray,
    returns: returnsArray,
    hasReturns: returnsArray.length > 0,
    hasParams: paramsArray.length > 0,
  };
}

/**
 * Prepare event data for template rendering
 * @param {object} event - Event data
 * @returns {object} Prepared event data
 */
function prepareEventData(event) {
  return {
    name: event.name,
    description: event.description || '',
    signature: event.signature,
    params: (event.params || []).map(p => ({
      name: p.name,
      type: p.type,
      description: p.description || '',
    })),
    hasParams: (event.params || []).length > 0,
  };
}

/**
 * Prepare error data for template rendering
 * @param {object} error - Error data
 * @returns {object} Prepared error data
 */
function prepareErrorData(error) {
  return {
    name: error.name,
    description: error.description || '',
    signature: error.signature,
  };
}

/**
 * Prepare struct data for template rendering
 * @param {object} struct - Struct data
 * @returns {object} Prepared struct data
 */
function prepareStructData(struct) {
  return {
    name: struct.name,
    description: struct.description || '',
    definition: struct.definition,
  };
}

/**
 * Validate documentation data
 * @param {object} data - Documentation data to validate
 * @throws {Error} If data is invalid
 */
function validateData(data) {
  if (!data || typeof data !== 'object') {
    throw new Error('Invalid data: expected an object');
  }
  if (!data.title || typeof data.title !== 'string') {
    throw new Error('Invalid data: missing or invalid title');
  }
}

/**
 * Generate fallback description for state variables/constants based on naming patterns
 * @param {string} name - Variable name (e.g., "STORAGE_POSITION", "DEFAULT_ADMIN_ROLE")
 * @param {string} moduleName - Name of the module/contract for context
 * @returns {string} Generated description or empty string
 */
function generateStateVariableDescription(name, moduleName) {
  if (!name) return '';
  
  const upperName = name.toUpperCase();
  
  // Common patterns for diamond/ERC contracts
  const patterns = {
    // Storage position patterns
    'STORAGE_POSITION': 'Diamond storage slot position for this module',
    'STORAGE_SLOT': 'Diamond storage slot identifier',
    '_STORAGE_POSITION': 'Diamond storage slot position',
    '_STORAGE_SLOT': 'Diamond storage slot identifier',
    
    // Role patterns
    'DEFAULT_ADMIN_ROLE': 'Default administrative role identifier (bytes32(0))',
    'ADMIN_ROLE': 'Administrative role identifier',
    'MINTER_ROLE': 'Minter role identifier',
    'PAUSER_ROLE': 'Pauser role identifier',
    'BURNER_ROLE': 'Burner role identifier',
    
    // ERC patterns  
    'INTERFACE_ID': 'ERC-165 interface identifier',
    'EIP712_DOMAIN': 'EIP-712 domain separator',
    'PERMIT_TYPEHASH': 'EIP-2612 permit type hash',
    
    // Reentrancy patterns
    'NON_REENTRANT_SLOT': 'Reentrancy guard storage slot',
    '_NOT_ENTERED': 'Reentrancy status: not entered',
    '_ENTERED': 'Reentrancy status: entered',
  };
  
  // Check exact matches first
  if (patterns[upperName]) {
    return patterns[upperName];
  }
  
  // Check partial matches
  if (upperName.includes('STORAGE') && (upperName.includes('POSITION') || upperName.includes('SLOT'))) {
    return 'Diamond storage slot position for this module';
  }
  if (upperName.includes('_ROLE')) {
    const roleName = name.replace(/_ROLE$/i, '').replace(/_/g, ' ').toLowerCase();
    return `${roleName.charAt(0).toUpperCase() + roleName.slice(1)} role identifier`;
  }
  if (upperName.includes('TYPEHASH')) {
    return 'Type hash for EIP-712 structured data';
  }
  if (upperName.includes('INTERFACE')) {
    return 'ERC-165 interface identifier';
  }
  
  // Generic fallback
  return '';
}

/**
 * Prepare base data common to both facet and module templates
 * @param {object} data - Documentation data
 * @param {number} position - Sidebar position
 * @returns {object} Base prepared data
 */
function prepareBaseData(data, position = 99) {
  validateData(data);
  
  const description = data.description || `Contract documentation for ${data.title}`;
  const subtitle = data.subtitle || data.description || `Contract documentation for ${data.title}`;
  const overview = data.overview || data.description || `Documentation for ${data.title}.`;

  return {
    position,
    title: data.title,
    description,
    subtitle,
    overview,
    generatedDate: data.generatedDate || new Date().toISOString(),
    gitSource: data.gitSource || '',
    keyFeatures: data.keyFeatures || '',
    usageExample: data.usageExample || '',
    bestPractices: (data.bestPractices && data.bestPractices.trim()) ? data.bestPractices : null,
    securityConsiderations: (data.securityConsiderations && data.securityConsiderations.trim()) ? data.securityConsiderations : null,
    integrationNotes: (data.integrationNotes && data.integrationNotes.trim()) ? data.integrationNotes : null,
    storageInfo: data.storageInfo || '',
    
    // Events
    events: (data.events || []).map(prepareEventData),
    hasEvents: (data.events || []).length > 0,
    
    // Errors
    errors: (data.errors || []).map(prepareErrorData),
    hasErrors: (data.errors || []).length > 0,
    
    // Structs
    structs: (data.structs || []).map(prepareStructData),
    hasStructs: (data.structs || []).length > 0,
    
    // State variables (for modules) - with fallback description generation
    stateVariables: (data.stateVariables || []).map(v => ({
      name: v.name,
      type: v.type || '',
      value: v.value || '',
      description: v.description || generateStateVariableDescription(v.name, data.title),
    })),
    hasStateVariables: (data.stateVariables || []).length > 0,
    hasStorage: Boolean(data.storageInfo || (data.stateVariables && data.stateVariables.length > 0)),
  };
}

/**
 * Prepare data for facet template rendering
 * @param {object} data - Documentation data
 * @param {number} position - Sidebar position
 * @returns {object} Prepared data for facet template
 */
function prepareFacetData(data, position = 99) {
  const baseData = prepareBaseData(data, position);
  const sourceFilePath = data.sourceFilePath;
  
  return {
    ...baseData,
    // Contract type flags for unified template
    isFacet: true,
    isModule: false,
    contractType: 'facet',
    // Functions with APIReference-compatible format (no source extraction for facets)
    functions: (data.functions || []).map(fn => prepareFunctionData(fn, sourceFilePath, false)),
    hasFunctions: (data.functions || []).length > 0,
  };
}

/**
 * Prepare data for module template rendering
 * @param {object} data - Documentation data
 * @param {number} position - Sidebar position
 * @returns {object} Prepared data for module template
 */
function prepareModuleData(data, position = 99) {
  const baseData = prepareBaseData(data, position);
  const sourceFilePath = data.sourceFilePath;
  
  return {
    ...baseData,
    // Contract type flags for unified template
    isFacet: false,
    isModule: true,
    contractType: 'module',
    // Functions with table-compatible format (with source extraction for modules)
    functions: (data.functions || []).map(fn => prepareFunctionData(fn, sourceFilePath, true)),
    hasFunctions: (data.functions || []).length > 0,
  };
}

/**
 * Generate complete facet documentation
 * Uses the unified contract template with isFacet=true
 * @param {object} data - Documentation data
 * @param {number} position - Sidebar position
 * @returns {string} Complete MDX document
 */
function generateFacetDoc(data, position = 99) {
  const preparedData = prepareFacetData(data, position);
  return loadAndRenderTemplate('contract', preparedData);
}

/**
 * Generate complete module documentation
 * Uses the unified contract template with isModule=true
 * @param {object} data - Documentation data
 * @param {number} position - Sidebar position
 * @returns {string} Complete MDX document
 */
function generateModuleDoc(data, position = 99) {
  const preparedData = prepareModuleData(data, position);
  return loadAndRenderTemplate('contract', preparedData);
}

module.exports = {
  generateFacetDoc,
  generateModuleDoc,
};
