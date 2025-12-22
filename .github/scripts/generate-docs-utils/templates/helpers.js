/**
 * Template Helper Functions
 * 
 * Escape and sanitization utilities for MDX/JSX template generation.
 * Used by both template-engine.js and templates.js
 */

/**
 * Escape special characters for YAML frontmatter
 * @param {string} str - String to escape
 * @returns {string} Escaped string safe for YAML
 */
function escapeYaml(str) {
  if (!str) return '';
  return str
    .replace(/\\/g, '\\\\')
    .replace(/"/g, '\\"')
    .replace(/\n/g, ' ')
    .trim();
}

/**
 * Sanitize text to prevent MDX from interpreting it as JSX
 * Converts literal \n strings to actual newlines for proper formatting
 * @param {string} str - String to sanitize
 * @returns {string} Sanitized string
 */
function sanitizeForMdx(str) {
  if (!str) return '';
  return str
    .replace(/\\n/g, '\n')  // Convert literal \n to actual newlines
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/\{/g, '&#123;')
    .replace(/\}/g, '&#125;');
}

/**
 * Convert object/array to a safe JavaScript expression for JSX attributes
 * Returns the value wrapped in curly braces for direct use in JSX: {value}
 * @param {*} obj - Value to convert
 * @returns {string} JSX expression with curly braces: {JSON}
 */
function toJsxExpression(obj) {
  if (obj == null) return '{null}';
  
  try {
    let jsonStr = JSON.stringify(obj);
    // Ensure single line
    jsonStr = jsonStr.replace(/[\n\r]/g, ' ').replace(/\s+/g, ' ').trim();
    // Verify it's valid JSON
    JSON.parse(jsonStr);
    // Return with JSX curly braces included
    return `{${jsonStr}}`;
  } catch (e) {
    console.warn('Invalid JSON generated:', e.message);
    return Array.isArray(obj) ? '{[]}' : '{{}}';
  }
}

/**
 * Escape special characters for JSX string attributes
 * @param {string} str - String to escape
 * @returns {string} Escaped string safe for JSX attributes
 */
function escapeJsx(str) {
  if (!str) return '';
  
  return sanitizeForMdx(str)
    .replace(/\\/g, '\\\\')
    .replace(/"/g, '\\"')
    .replace(/'/g, "\\'")
    .replace(/\n/g, ' ')
    .replace(/\{/g, '&#123;')
    .replace(/\}/g, '&#125;')
    // Don't escape backticks - they should be preserved for code formatting
    .trim();
}

/**
 * Escape markdown table special characters
 * @param {string} str - String to escape
 * @returns {string} Escaped string safe for markdown tables
 */
function escapeMarkdownTable(str) {
  if (!str) return '';
  return str
    .replace(/\|/g, '\\|')
    .replace(/\n/g, ' ')
    .replace(/\{/g, '&#123;')
    .replace(/\}/g, '&#125;'); 
}

/**
 * Escape HTML entities for safe display
 * @param {string} str - String to escape
 * @returns {string} HTML-escaped string
 */
function escapeHtml(str) {
  if (!str) return '';
  return String(str)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}

/**
 * Escape string for use in JavaScript/JSX object literal values
 * Escapes quotes and backslashes for JavaScript strings (not HTML entities)
 * Preserves backticks for code formatting
 * @param {string} str - String to escape
 * @returns {string} Escaped string safe for JavaScript string literals
 */
function escapeJsString(str) {
  if (!str) return '';
  return String(str)
    .replace(/\\/g, '\\\\')  // Escape backslashes first
    .replace(/"/g, '\\"')     // Escape double quotes
    .replace(/'/g, "\\'")     // Escape single quotes
    .replace(/\n/g, '\\n')    // Escape newlines
    .replace(/\r/g, '\\r')    // Escape carriage returns
    .replace(/\t/g, '\\t');   // Escape tabs
    // Note: Backticks are preserved for code formatting in descriptions
}

/**
 * Escape string for JSX string attributes, preserving backticks for code formatting
 * This is specifically for descriptions that may contain code with backticks
 * @param {string} str - String to escape
 * @returns {string} Escaped string safe for JSX string attributes with preserved backticks
 */
function escapeJsxPreserveBackticks(str) {
  if (!str) return '';
  
  // Don't use sanitizeForMdx as it might HTML-escape things
  // Just escape what's needed for JSX string attributes
  return String(str)
    .replace(/\\/g, '\\\\')  // Escape backslashes first
    .replace(/"/g, '\\"')     // Escape double quotes for JSX strings
    .replace(/'/g, "\\'")     // Escape single quotes
    .replace(/\n/g, ' ')      // Replace newlines with spaces
    .replace(/\{/g, '&#123;')  // Escape curly braces for JSX
    .replace(/\}/g, '&#125;') // Escape curly braces for JSX
    // Preserve backticks - don't escape them, they're needed for code formatting
    .trim();
}

module.exports = {
  escapeYaml,
  escapeJsx,
  escapeJsxPreserveBackticks,
  sanitizeForMdx,
  sanitizeMdx: sanitizeForMdx, // Alias for template usage
  toJsxExpression,
  escapeMarkdownTable,
  escapeHtml,
  escapeJsString,
};

