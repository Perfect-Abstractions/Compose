/**
 * Text Sanitizer
 * 
 * Functions for cleaning and sanitizing text content.
 */

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

module.exports = {
  sanitizeBrokenLinks,
  cleanDescription,
};

