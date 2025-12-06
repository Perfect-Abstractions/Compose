/**
 * Simple Template Engine
 * 
 * A lightweight template engine with no external dependencies.
 * 
 * Supports:
 * - Variable substitution: {{variable}} (HTML escaped)
 * - Unescaped output: {{{variable}}} (raw output)
 * - Conditionals: {{#if variable}}...{{/if}}
 * - Loops: {{#each array}}...{{/each}}
 * - Helper functions: {{helperName variable}} or {{helperName(arg1, arg2)}}
 * - Dot notation: {{object.property.nested}}
 */

const fs = require('fs');
const path = require('path');

// Import helpers from separate module
const helpers = require('./helpers');
const { escapeHtml } = helpers;

/**
 * Get value from object using dot notation path
 * @param {object} obj - Object to get value from
 * @param {string} dotPath - Dot notation path (e.g., "user.name")
 * @returns {*} Value at path or undefined
 */
function getValue(obj, dotPath) {
  if (!dotPath || !obj) return undefined;
  
  const parts = dotPath.split('.');
  let value = obj;
  
  for (const part of parts) {
    if (value == null) return undefined;
    value = value[part];
  }
  
  return value;
}

/**
 * Check if a value is truthy for template conditionals
 * - null/undefined → false
 * - empty array → false
 * - empty object → false
 * - empty string → false
 * - false → false
 * - everything else → true
 * 
 * @param {*} value - Value to check
 * @returns {boolean} Whether value is truthy
 */
function isTruthy(value) {
  if (value == null) return false;
  if (Array.isArray(value)) return value.length > 0;
  if (typeof value === 'object') return Object.keys(value).length > 0;
  if (typeof value === 'string') return value.trim().length > 0;
  return Boolean(value);
}

/**
 * Process a helper function call
 * @param {string} helperName - Name of the helper
 * @param {string[]} args - Argument strings (variable paths or literals)
 * @param {object} context - Current template context
 * @param {object} helperRegistry - Registry of helper functions
 * @returns {string} Result of helper function
 */
function processHelper(helperName, args, context, helperRegistry) {
  const helper = helperRegistry[helperName];
  if (!helper) {
    console.warn(`Unknown template helper: ${helperName}`);
    return '';
  }
  
  // Process arguments - can be variable paths or quoted literals
  const processedArgs = args.map(arg => {
    arg = arg.trim();
    // Check for quoted literal strings
    if ((arg.startsWith('"') && arg.endsWith('"')) || 
        (arg.startsWith("'") && arg.endsWith("'"))) {
      return arg.slice(1, -1);
    }
    // Otherwise treat as variable path
    return getValue(context, arg);
  });
  
  return helper(...processedArgs);
}

/**
 * Process a variable expression (helper or simple variable)
 * @param {string} expression - The expression inside {{ }}
 * @param {object} context - Current template context
 * @param {boolean} escapeOutput - Whether to HTML-escape the output
 * @param {object} helperRegistry - Registry of helper functions
 * @returns {string} Processed value
 */
function processExpression(expression, context, escapeOutput, helperRegistry) {
  const expr = expression.trim();
  
  // Check for helper with parentheses: helperName(arg1, arg2)
  const parenMatch = expr.match(/^(\w+)\((.*)\)$/);
  if (parenMatch) {
    const [, helperName, argsStr] = parenMatch;
    const args = argsStr ? argsStr.split(',').map(a => a.trim()) : [];
    return processHelper(helperName, args, context, helperRegistry);
  }
  
  // Check for helper with space: helperName variable
  const spaceMatch = expr.match(/^(\w+)\s+(.+)$/);
  if (spaceMatch && helperRegistry[spaceMatch[1]]) {
    const [, helperName, arg] = spaceMatch;
    return processHelper(helperName, [arg], context, helperRegistry);
  }
  
  // Regular variable lookup
  const value = getValue(context, expr);
  if (value == null) return '';
  
  const str = String(value);
  return escapeOutput ? escapeHtml(str) : str;
}

/**
 * Find the matching closing tag for a block, handling nesting
 * @param {string} content - Content to search
 * @param {string} openTag - Opening tag pattern (e.g., '#if', '#each')
 * @param {string} closeTag - Closing tag (e.g., '/if', '/each')
 * @param {number} startPos - Position after the opening tag
 * @returns {number} Position of the matching closing tag, or -1 if not found
 */
function findMatchingClose(content, openTag, closeTag, startPos) {
  let depth = 1;
  let pos = startPos;
  
  const openPattern = new RegExp(`\\{\\{${openTag}\\s+[^}]+\\}\\}`, 'g');
  const closePattern = new RegExp(`\\{\\{${closeTag}\\}\\}`, 'g');
  
  while (depth > 0 && pos < content.length) {
    // Find next open and close tags
    openPattern.lastIndex = pos;
    closePattern.lastIndex = pos;
    
    const openMatch = openPattern.exec(content);
    const closeMatch = closePattern.exec(content);
    
    if (!closeMatch) {
      return -1; // No matching close found
    }
    
    // If open comes before close, increase depth
    if (openMatch && openMatch.index < closeMatch.index) {
      depth++;
      pos = openMatch.index + openMatch[0].length;
    } else {
      depth--;
      if (depth === 0) {
        return closeMatch.index;
      }
      pos = closeMatch.index + closeMatch[0].length;
    }
  }
  
  return -1;
}

/**
 * Process nested conditionals: {{#if variable}}...{{/if}}
 * @param {string} content - Template content
 * @param {object} context - Data context
 * @param {object} helperRegistry - Registry of helper functions
 * @returns {string} Processed content
 */
function processConditionals(content, context, helperRegistry) {
  let result = content;
  const openPattern = /\{\{#if\s+([^}]+)\}\}/g;
  
  let match;
  while ((match = openPattern.exec(result)) !== null) {
    const condition = match[1].trim();
    const startPos = match.index;
    const afterOpen = startPos + match[0].length;
    
    const closePos = findMatchingClose(result, '#if', '/if', afterOpen);
    if (closePos === -1) {
      console.warn(`Unmatched {{#if ${condition}}} at position ${startPos}`);
      break;
    }
    
    const ifContent = result.substring(afterOpen, closePos);
    const closeEndPos = closePos + '{{/if}}'.length;
    
    // Evaluate condition and get replacement
    const value = getValue(context, condition);
    const replacement = isTruthy(value) 
      ? processContent(ifContent, context, helperRegistry)
      : '';
    
    // Replace in result
    result = result.substring(0, startPos) + replacement + result.substring(closeEndPos);
    
    // Reset pattern to start from beginning since we modified the string
    openPattern.lastIndex = 0;
  }
  
  return result;
}

/**
 * Process nested loops: {{#each array}}...{{/each}}
 * @param {string} content - Template content
 * @param {object} context - Data context
 * @param {object} helperRegistry - Registry of helper functions
 * @returns {string} Processed content
 */
function processLoops(content, context, helperRegistry) {
  let result = content;
  const openPattern = /\{\{#each\s+([^}]+)\}\}/g;
  
  let match;
  while ((match = openPattern.exec(result)) !== null) {
    const arrayPath = match[1].trim();
    const startPos = match.index;
    const afterOpen = startPos + match[0].length;
    
    const closePos = findMatchingClose(result, '#each', '/each', afterOpen);
    if (closePos === -1) {
      console.warn(`Unmatched {{#each ${arrayPath}}} at position ${startPos}`);
      break;
    }
    
    const loopContent = result.substring(afterOpen, closePos);
    const closeEndPos = closePos + '{{/each}}'.length;
    
    // Get array and process each item
    const array = getValue(context, arrayPath);
    let replacement = '';
    
    if (Array.isArray(array) && array.length > 0) {
      replacement = array.map((item, index) => {
        const itemContext = { ...context, ...item, index };
        return processContent(loopContent, itemContext, helperRegistry);
      }).join('');
    }
    
    // Replace in result
    result = result.substring(0, startPos) + replacement + result.substring(closeEndPos);
    
    // Reset pattern to start from beginning since we modified the string
    openPattern.lastIndex = 0;
  }
  
  return result;
}

/**
 * Process template content with the given context
 * Handles all variable substitutions, helpers, conditionals, and loops
 * 
 * IMPORTANT: Processing order matters!
 * 1. Loops first - so nested conditionals are evaluated with correct item context
 * 2. Conditionals second - after loops have expanded their content
 * 3. Variables last - after all control structures are resolved
 * 
 * @param {string} content - Template content to process
 * @param {object} context - Data context
 * @param {object} helperRegistry - Registry of helper functions
 * @returns {string} Processed content
 */
function processContent(content, context, helperRegistry) {
  let result = content;
  
  // 1. Process loops FIRST (handles nesting properly)
  result = processLoops(result, context, helperRegistry);
  
  // 2. Process conditionals SECOND (handles nesting properly)
  result = processConditionals(result, context, helperRegistry);
  
  // 3. Process triple braces for unescaped output: {{{variable}}}
  const tripleBracePattern = /\{\{\{([^}]+)\}\}\}/g;
  result = result.replace(tripleBracePattern, (match, expr) => {
    return processExpression(expr, context, false, helperRegistry);
  });
  
  // 4. Process double braces for escaped output: {{variable}}
  const doubleBracePattern = /\{\{([^}]+)\}\}/g;
  result = result.replace(doubleBracePattern, (match, expr) => {
    return processExpression(expr, context, true, helperRegistry);
  });
  
  return result;
}

/**
 * Render a template string with data
 * @param {string} template - Template string
 * @param {object} data - Data to render
 * @returns {string} Rendered template
 */
function renderTemplate(template, data) {
  if (!template) return '';
  if (!data) data = {};
  
  return processContent(template, { ...data }, helpers);
}

/**
 * List available template files
 * @returns {string[]} Array of template names (without extension)
 */
function listAvailableTemplates() {
  const templatesDir = path.join(__dirname, 'pages');
  try {
    return fs.readdirSync(templatesDir)
      .filter(f => f.endsWith('.mdx.template'))
      .map(f => f.replace('.mdx.template', ''));
  } catch (e) {
    return [];
  }
}

/**
 * Load and render a template file
 * @param {string} templateName - Name of template (without extension)
 * @param {object} data - Data to render
 * @returns {string} Rendered template
 * @throws {Error} If template cannot be loaded
 */
function loadAndRenderTemplate(templateName, data) {
  console.log('Loading template:', templateName);
  console.log('Data:', data);
  
  const templatePath = path.join(__dirname, 'pages', `${templateName}.mdx.template`);
  
  try {
    if (!fs.existsSync(templatePath)) {
      const available = listAvailableTemplates();
      throw new Error(
        `Template '${templateName}' not found at: ${templatePath}\n` +
        `Available templates: ${available.length > 0 ? available.join(', ') : 'none'}`
      );
    }
    
    const template = fs.readFileSync(templatePath, 'utf8');
    return renderTemplate(template, data);
  } catch (error) {
    if (error.code === 'ENOENT') {
      const available = listAvailableTemplates();
      throw new Error(
        `Template file not found: ${templatePath}\n` +
        `Available templates: ${available.length > 0 ? available.join(', ') : 'none'}`
      );
    }
    throw error;
  }
}

module.exports = {
  renderTemplate,
  loadAndRenderTemplate,
  getValue,
  isTruthy,
  listAvailableTemplates,
};
