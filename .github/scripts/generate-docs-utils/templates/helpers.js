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

module.exports = {
  escapeYaml,
  escapeJsx,
  sanitizeForMdx,
  sanitizeMdx: sanitizeForMdx, // Alias for template usage
  toJsxExpression,
  escapeMarkdownTable,
  escapeHtml,
};

