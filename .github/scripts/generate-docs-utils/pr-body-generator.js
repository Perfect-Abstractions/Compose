/**
 * PR Body Generator
 * 
 * Generates a PR body from the docgen-summary.json file
 * 
 * Usage:
 *   node pr-body-generator.js [summary-file-path]
 * 
 * Outputs the PR body in GitHub Actions format to stdout
 */

const fs = require('fs');
const path = require('path');

/**
 * Generate PR body from summary data
 * @param {Object} summary - Summary data from docgen-summary.json
 * @returns {string} PR body markdown
 */
function generatePRBody(summary) {
  const facets = summary.facets || [];
  const modules = summary.modules || [];
  const total = summary.totalGenerated || 0;

  let body = '## Auto-Generated Contract Documentation\n\n';
  body += 'This PR contains auto-generated documentation from contract comments using `forge doc`.\n\n';
  
  body += '### Summary\n';
  body += `- **Total generated:** ${total} files\n\n`;

  if (facets.length > 0) {
    body += '### Facets\n';
    facets.forEach(facet => {
      body += `- ${facet.title}\n`;
    });
    body += '\n';
  }

  if (modules.length > 0) {
    body += '### Modules\n';
    modules.forEach(module => {
      body += `- ${module.title}\n`;
    });
    body += '\n';
  }

  body += '### What was done\n';
  body += '1. Extracted NatSpec using `forge doc`\n';
  body += '2. Converted to Docusaurus MDX format\n';
  body += '3. Enhanced content with GitHub Copilot (optional)\n';
  body += '4. Verified documentation build\n\n';

  body += '### Review Checklist\n';
  body += '- [ ] Review generated content for accuracy\n';
  body += '- [ ] Verify code examples are correct\n';
  body += '- [ ] Check for any missing documentation\n';
  body += '- [ ] Ensure consistency with existing docs\n\n';

  body += '---\n';
  body += '<b* This PR was automatically generated. Please review before merging.*\n';

  return body;
}

/**
 * Main function
 */
function main() {
  const summaryPath = process.argv[2] || 'docgen-summary.json';
  
  if (!fs.existsSync(summaryPath)) {
    console.error(`Error: Summary file not found: ${summaryPath}`);
    process.exit(1);
  }

  try {
    const summaryContent = fs.readFileSync(summaryPath, 'utf8');
    const summary = JSON.parse(summaryContent);
    
    const prBody = generatePRBody(summary);
    
    // Output in GitHub Actions format
    console.log('body<<EOF');
    console.log(prBody);
    console.log('EOF');
  } catch (error) {
    console.error(`Error generating PR body: ${error.message}`);
    process.exit(1);
  }
}

// Run if called directly
if (require.main === module) {
  main();
}

module.exports = {
  generatePRBody,
};

