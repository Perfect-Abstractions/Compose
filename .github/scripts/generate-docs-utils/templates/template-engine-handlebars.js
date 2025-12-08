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
  
  // Helper to emit a JSX style literal: returns a string like {{display: "flex", gap: "1rem"}}
  Handlebars.registerHelper('styleLiteral', function(styles) {
    if (!styles || typeof styles !== 'string') return '{{}}';

    const styleObj = {};
    const pairs = styles.split(';').filter(pair => pair.trim());

    pairs.forEach(pair => {
      const [key, value] = pair.split(':').map(s => s.trim());
      if (key && value !== undefined) {
        const camelKey = key.includes('-')
          ? key.replace(/-([a-z])/g, (_, c) => c.toUpperCase())
          : key;
        const cleanValue = value.replace(/^["']|["']$/g, '');
        styleObj[camelKey] = cleanValue;
      }
    });

    const entries = Object.entries(styleObj).map(([k, v]) => {
      const isPureNumber = /^-?\d+\.?\d*$/.test(v.trim());
      // Quote everything except pure numbers
      const valueLiteral = isPureNumber ? v : JSON.stringify(v);
      return `${k}: ${valueLiteral}`;
    }).join(', ');

    // Wrap with double braces so MDX sees style={{...}}
    return `{{${entries}}}`;
  });

  // Helper to wrap code content in template literal for MDX
  // This ensures MDX treats the content as a string, not JSX to parse
  Handlebars.registerHelper('codeContent', function(content) {
    if (!content) return '{``}';
    // Escape backticks in the content
    const escaped = String(content).replace(/`/g, '\\`').replace(/\$/g, '\\$');
    return `{\`${escaped}\`}`;
  });
  
  // Helper to generate JSX style object syntax
  // Accepts CSS string and converts to JSX object format
  // Handles both kebab-case (margin-bottom) and camelCase (marginBottom)
  Handlebars.registerHelper('jsxStyle', function(styles) {
    if (!styles || typeof styles !== 'string') return '{}';
    
    // Parse CSS string like "display: flex; margin-bottom: 1rem;" or "marginBottom: 1rem"
    const styleObj = {};
    const pairs = styles.split(';').filter(pair => pair.trim());
    
    pairs.forEach(pair => {
      const [key, value] = pair.split(':').map(s => s.trim());
      if (key && value) {
        // Convert kebab-case to camelCase if needed
        const camelKey = key.includes('-') 
          ? key.replace(/-([a-z])/g, (g) => g[1].toUpperCase())
          : key;
        // Remove quotes from value if present
        const cleanValue = value.replace(/^["']|["']$/g, '');
        styleObj[camelKey] = cleanValue;
      }
    });
    
    // Convert to JSX object string with proper quoting
    // All CSS values should be quoted as strings unless they're pure numbers
    const entries = Object.entries(styleObj)
      .map(([k, v]) => {
        // Check if it's a pure number (integer or decimal without units)
        if (/^-?\d+\.?\d*$/.test(v.trim())) {
          return `${k}: ${v}`;
        }
        // Everything else (including CSS units like "0.75rem", "2rem", CSS vars, etc.) should be quoted
        return `${k}: ${JSON.stringify(v)}`;
      })
      .join(', ');
    
    // Return the object content wrapped in braces
    // When used with {{{jsxStyle ...}}} in template, this becomes style={...}
    // But we need style={{...}}, so we return with an extra opening brace
    // The template uses {{{jsxStyle ...}}} which outputs raw, giving us style={{{...}}}
    // To get style={{...}}, we need the helper to return {{...}}
    // But with triple braces in template, we'd get style={{{{...}}}} which is wrong
    // Solution: return just the object, template adds one brace manually
    // Return the full JSX object expression with double braces
    // Template will use raw block: {{{{jsxStyle ...}}}}
    // This outputs: style={{{display: "flex", ...}}}
    // But we need: style={{display: "flex", ...}}
    // Actually, let's try: helper returns {{...}}, template uses {{jsxStyle}} (double)
    // Handlebars will output the helper result
    // But it will escape... unless we use raw block
    // Simplest: return {{...}}, use {{{{jsxStyle}}}} raw block
    return `{{${entries}}}`;
  });
  
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

