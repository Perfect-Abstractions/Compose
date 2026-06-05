/**
 * Local plugin: injects <link rel="canonical"> into every HTML file after build.
 * Guarantees the tag is in the initial server-rendered HTML — no JS required.
 */
import { createRequire } from 'module';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const require = createRequire(import.meta.url);
const fs = require('fs-extra');

function findHtmlFiles(dir) {
  const results = [];
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const fullPath = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      results.push(...findHtmlFiles(fullPath));
    } else if (entry.name.endsWith('.html')) {
      results.push(fullPath);
    }
  }
  return results;
}

/**
 * Convert a file path relative to outDir into a URL path.
 * e.g. "/docs/foundations/diamond-contracts/index.html" -> "/docs/foundations/diamond-contracts"
 */
function filePathToUrlPath(filePath, outDir) {
  let rel = path.relative(outDir, filePath).split(path.sep).join('/');
  // /foo/index.html -> /foo
  rel = rel.replace(/\/index\.html$/, '');
  // index.html -> /
  if (rel === 'index') rel = '';
  return '/' + rel;
}

export default function canonicalPlugin(context, options) {
  const { url: siteUrl } = context.siteConfig;
  const tag = '<link rel="canonical" href="';

  return {
    name: 'canonical-inject',
    postBuild({ outDir }) {
      console.log('[canonical-inject] Injecting <link rel="canonical"> into HTML files...');
      const htmlFiles = findHtmlFiles(outDir);
      let count = 0;

      for (const filePath of htmlFiles) {
        let html = fs.readFileSync(filePath, 'utf8');

        // Skip if canonical already exists
        if (html.includes(tag)) continue;

        const urlPath = filePathToUrlPath(filePath, outDir);
        const canonical = `${siteUrl}${urlPath}`;

        // Inject right after <head> or after the last <meta> in <head>
        const headIndex = html.indexOf('<head');
        if (headIndex === -1) continue;

        // Find the closing > of <head> tag
        const headClose = html.indexOf('>', headIndex);
        const insertAt = headClose + 1;

        const canonicalTag = `\n    <link rel="canonical" href="${canonical}">`;
        html = html.slice(0, insertAt) + canonicalTag + html.slice(insertAt);

        fs.writeFileSync(filePath, html, 'utf8');
        count++;
      }
    },
  };
}
