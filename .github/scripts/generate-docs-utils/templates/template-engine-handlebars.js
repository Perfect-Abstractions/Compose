/**
 * Handlebars Template Engine for MDX Documentation Generation
 * 
 * Replaces the custom template engine with Handlebars for better reliability
 * and proper MDX formatting.
 */

const Handlebars = require('handlebars');
const fs = require('fs');
const path = require('path');
const helpers = require('./helpers');

// Track if helpers have been registered (only register once)
let helpersRegistered = false;

/**
 * Register custom helpers for Handlebars
 * All helpers from helpers.js are registered for use in templates
 */
function registerHelpers() {
  if (helpersRegistered) return;
  
  // Register escape helpers
  Handlebars.registerHelper('escapeYaml', helpers.escapeYaml);
  Handlebars.registerHelper('escapeJsx', helpers.escapeJsx);
  Handlebars.registerHelper('sanitizeMdx', helpers.sanitizeMdx);
  Handlebars.registerHelper('escapeMarkdownTable', helpers.escapeMarkdownTable);
  
  // Custom helper for better null/empty string handling
  // Handlebars' default #if treats empty strings as falsy, but we want to be explicit
  Handlebars.registerHelper('ifTruthy', function(value, options) {
    if (value != null && 
        !(Array.isArray(value) && value.length === 0) &&
        !(typeof value === 'string' && value.trim().length === 0) &&
        !(typeof value === 'object' && Object.keys(value).length === 0)) {
      return options.fn(this);
    }
    return options.inverse(this);
  });
  
  helpersRegistered = true;
}

/**
 * Normalize MDX formatting to ensure proper blank lines
 * MDX requires blank lines between:
 * - Import statements and JSX
 * - JSX components and markdown
 * - JSX components and other JSX
 * 
 * @param {string} content - MDX content to normalize
 * @returns {string} Properly formatted MDX
 */
function normalizeMdxFormatting(content) {
  if (!content) return '';
  
  let normalized = content;
  
  // 1. Ensure blank line after import statements (before JSX)
  // Pattern: import ...;\n<Component
  normalized = normalized.replace(/(import\s+[^;]+;)\n(<[A-Z])/g, '$1\n\n$2');
  
  // 2. Ensure blank line after JSX closing tags (before markdown headings)
  // Pattern: />\n##
  normalized = normalized.replace(/(\/>)\n(##)/g, '$1\n\n$2');
  
  // 3. Ensure blank line after JSX closing tags (before other JSX)
  // Pattern: </Component>\n<Component
  normalized = normalized.replace(/(<\/[A-Z][a-zA-Z]+>)\n(<[A-Z])/g, '$1\n\n$2');
  
  // 4. Ensure blank line after JSX closing tags (before markdown content)
  // Pattern: </Component>\n## or </Component>\n[text]
  normalized = normalized.replace(/(<\/[A-Z][a-zA-Z]+>)\n(##|[A-Z])/g, '$1\n\n$2');
  
  // 5. Ensure blank line before JSX components (after markdown)
  // Pattern: ]\n<Component or ##\n<Component
  normalized = normalized.replace(/(\]|##)\n(<[A-Z])/g, '$1\n\n$2');
  
  // 6. Remove excessive blank lines (more than 2 consecutive)
  normalized = normalized.replace(/\n{3,}/g, '\n\n');
  
  // 7. Remove trailing whitespace from lines
  normalized = normalized.split('\n').map(line => line.trimEnd()).join('\n');
  
  // 8. Ensure file ends with single newline
  normalized = normalized.trimEnd() + '\n';
  
  return normalized;
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
 * Load and render a template file with Handlebars
 * @param {string} templateName - Name of template (without extension)
 * @param {object} data - Data to render
 * @returns {string} Rendered template with proper MDX formatting
 * @throws {Error} If template cannot be loaded
 */
function loadAndRenderTemplate(templateName, data) {
  const templatePath = path.join(__dirname, 'pages', `${templateName}.mdx.template`);
  
  if (!fs.existsSync(templatePath)) {
    const available = listAvailableTemplates();
    throw new Error(
      `Template '${templateName}' not found at: ${templatePath}\n` +
      `Available templates: ${available.length > 0 ? available.join(', ') : 'none'}`
    );
  }
  
  // Register helpers (only once, but safe to call multiple times)
  registerHelpers();
  
  try {
    // Load template
    const templateContent = fs.readFileSync(templatePath, 'utf8');
    
    // Compile template with Handlebars
    const template = Handlebars.compile(templateContent);
    
    // Render with data
    let rendered = template(data);
    
    // Post-process: normalize MDX formatting
    rendered = normalizeMdxFormatting(rendered);
    
    return rendered;
  } catch (error) {
    if (error.message.includes('Parse error')) {
      throw new Error(
        `Template parsing error in ${templateName}: ${error.message}\n` +
        `Template path: ${templatePath}`
      );
    }
    throw error;
  }
}

module.exports = {
  loadAndRenderTemplate,
  registerHelpers,
  listAvailableTemplates,
};

