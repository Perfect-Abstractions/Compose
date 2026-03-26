/**
 * Response Parser
 * 
 * Parses and cleans AI response content.
 */

/**
 * Extract and clean JSON from API response
 * Handles markdown code blocks, wrapped text, and attempts to fix truncated JSON
 * Also removes control characters that break JSON parsing
 * @param {string} content - Raw API response content
 * @returns {string} Cleaned JSON string ready for parsing
 */
function extractJSON(content) {
  if (!content || typeof content !== 'string') {
    return content;
  }

  let cleaned = content.trim();

  // Remove markdown code blocks (```json ... ``` or ``` ... ```)
  // Handle both at start and anywhere in the string
  cleaned = cleaned.replace(/^```(?:json)?\s*\n?/gm, '');
  cleaned = cleaned.replace(/\n?```\s*$/gm, '');
  cleaned = cleaned.trim();

  // Remove control characters (0x00-0x1F except newline, tab, carriage return)
  // These are illegal in JSON strings and cause "Bad control character" parsing errors
  cleaned = cleaned.replace(/[\x00-\x08\x0B\x0C\x0E-\x1F]/g, '');

  // Find the first { and last } to extract JSON object
  const firstBrace = cleaned.indexOf('{');
  const lastBrace = cleaned.lastIndexOf('}');

  if (firstBrace !== -1 && lastBrace !== -1 && lastBrace > firstBrace) {
    cleaned = cleaned.substring(firstBrace, lastBrace + 1);
  } else if (firstBrace !== -1) {
    // We have a { but no closing }, JSON might be truncated
    cleaned = cleaned.substring(firstBrace);
  }

  // Try to fix common truncation issues
  const openBraces = (cleaned.match(/\{/g) || []).length;
  const closeBraces = (cleaned.match(/\}/g) || []).length;
  
  if (openBraces > closeBraces) {
    // JSON might be truncated - try to close incomplete strings and objects
    // Check if we're in the middle of a string (simple heuristic)
    const lastChar = cleaned[cleaned.length - 1];
    const lastQuote = cleaned.lastIndexOf('"');
    const lastBraceInCleaned = cleaned.lastIndexOf('}');
    
    // If last quote is after last brace and not escaped, we might be in a string
    if (lastQuote > lastBraceInCleaned && lastChar !== '"') {
      // Check if the quote before last is escaped
      let isEscaped = false;
      for (let i = lastQuote - 1; i >= 0 && cleaned[i] === '\\'; i--) {
        isEscaped = !isEscaped;
      }
      
      if (!isEscaped) {
        // We're likely in an incomplete string, close it
        cleaned = cleaned + '"';
      }
    }
    
    // Close any incomplete objects/arrays
    const missingBraces = openBraces - closeBraces;
    // Try to intelligently close - if we're in the middle of a property, add a value first
    const trimmed = cleaned.trim();
    if (trimmed.endsWith(',') || trimmed.endsWith(':')) {
      // We're in the middle of a property, add null and close
      cleaned = cleaned.replace(/[,:]\s*$/, ': null');
    }
    cleaned = cleaned + '\n' + '}'.repeat(missingBraces);
  }

  return cleaned.trim();
}

/**
 * Convert literal \n strings to actual newlines
 * @param {string} str - String with escaped newlines
 * @returns {string} String with actual newlines
 */
function convertNewlines(str) {
  if (!str || typeof str !== 'string') return str;
  return str.replace(/\\n/g, '\n');
}

/**
 * Decode HTML entities (for code blocks)
 * @param {string} str - String with HTML entities
 * @returns {string} Decoded string
 */
function decodeHtmlEntities(str) {
  if (!str || typeof str !== 'string') return str;
  return str
    .replace(/&quot;/g, '"')
    .replace(/&#x3D;/g, '=')
    .replace(/&#x3D;&gt;/g, '=>')
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .replace(/&#39;/g, "'")
    .replace(/&amp;/g, '&');
}

/**
 * Convert enhanced data fields (newlines, HTML entities)
 * @param {object} enhanced - Parsed JSON from API
 * @param {object} data - Original documentation data
 * @returns {object} Enhanced data with converted fields
 */
function convertEnhancedFields(enhanced, data) {
  // Use AI-generated description if provided, otherwise keep original
  const aiDescription = enhanced.description?.trim();
  const finalDescription = aiDescription || data.description;
  
  return {
    ...data,
    // Description is used for page subtitle - AI improves it from NatSpec
    description: finalDescription,
    subtitle: finalDescription,
    overview: convertNewlines(enhanced.overview) || data.overview,
    usageExample: decodeHtmlEntities(convertNewlines(enhanced.usageExample)) || null,
    bestPractices: convertNewlines(enhanced.bestPractices) || null,
    keyFeatures: convertNewlines(enhanced.keyFeatures) || null,
    integrationNotes: convertNewlines(enhanced.integrationNotes) || null,
    securityConsiderations: convertNewlines(enhanced.securityConsiderations) || null,
  };
}

module.exports = {
  extractJSON,
  convertEnhancedFields,
};

