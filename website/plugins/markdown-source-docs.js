/**
 * Local plugin: extends docusaurus-markdown-source-plugin to also expose
 * .mdx docs as .md URLs (plugin only copies .md by default).
 */
import { createRequire } from 'module';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const require = createRequire(import.meta.url);
const fs = require('fs-extra');
const basePlugin = require('docusaurus-markdown-source-plugin');

// --- Copied from docusaurus-markdown-source-plugin (for .mdx support) ---
function convertTabsToMarkdown(content) {
  const tabsPattern = /<Tabs[^>]*>([\s\S]*?)<\/Tabs>/g;
  return content.replace(tabsPattern, (fullMatch, tabsContent) => {
    const tabItemPattern = /<TabItem\s+[^>]*value="([^"]*)"[^>]*label="([^"]*)"[^>]*>([\s\S]*?)<\/TabItem>/g;
    let result = [];
    let match;
    while ((match = tabItemPattern.exec(tabsContent)) !== null) {
      const [, , label, itemContent] = match;
      const cleanContent = itemContent
        .split('\n')
        .map((line) => line.replace(/^\s{4}/, ''))
        .join('\n')
        .trim();
      result.push(`**${label}:**\n\n${cleanContent}`);
    }
    return result.join('\n\n---\n\n');
  });
}

function convertDetailsToMarkdown(content) {
  const detailsPattern = /<details>\s*<summary>(<strong>)?([^<]+)(<\/strong>)?<\/summary>([\s\S]*?)<\/details>/g;
  return content.replace(detailsPattern, (fullMatch, strongOpen, summaryText, strongClose, detailsContent) => {
    const cleanContent = detailsContent
      .split('\n')
      .map((line) => line.trim())
      .filter((line) => line.length > 0)
      .join('\n')
      .trim();
    return `### ${summaryText.trim()}\n\n${cleanContent}`;
  });
}

/**
 * Convert DocCardGrid + DocCard blocks to markdown list of links so the
 * generated .md is readable and we avoid leaving JSX fragments.
 */
function convertDocCardGridToMarkdown(content) {
  return content.replace(
    /<DocCardGrid[^>]*>([\s\S]*?)<\/DocCardGrid>/g,
    (_, inner) => {
      // Remove icon={...} so nested JSX doesn't break the DocCard match
      const withoutIcon = inner.replace(/icon=\{[^}]*\}/g, 'icon=""');
      // DocCard attributes can be in any order; match full tag (no nested /> now)
      const cardPattern = /<DocCard\s+([\s\S]*?)\s*\/>/g;
      const items = [];
      let m;
      while ((m = cardPattern.exec(withoutIcon)) !== null) {
        const attrs = m[1];
        const title = attrs.match(/title="([^"]*)"/)?.[1] ?? '';
        const description = attrs.match(/description="([^"]*)"/)?.[1] ?? '';
        const href = attrs.match(/href="([^"]*)"/)?.[1] ?? '';
        if (title && href) items.push(`- [${title}](${href}): ${description}`);
      }
      return items.length ? items.join('\n') + '\n' : '';
    }
  );
}

/**
 * Remove JSX tags (including nested ones) by repeatedly stripping the
 * outermost component until no match. Avoids leaving fragments like " />" or "}".
 */
function stripJsxComponents(content) {
  const componentTag = /<([A-Z][a-zA-Z]*)(?:\s[^>]*?)?(?:\/>|>[\s\S]*?<\/\1>)/g;
  let prev;
  do {
    prev = content;
    content = content.replace(componentTag, '');
  } while (content !== prev);
  return content;
}

function cleanMarkdownForDisplay(content, filepath) {
  const fileDir = filepath.replace(/[^/]*$/, '');
  content = content.replace(/^---\r?\n[\s\S]*?\r?\n---\r?\n/, '');
  content = content.replace(/^import\s+.*?from\s+['"].*?['"];?\s*$/gm, '');
  content = content.replace(
    /<p align="center">\s*\n?\s*<img src=\{require\(['"]([^'"]+)['"]\)\.default\} alt="([^"]*)"(?:\s+width="[^"]*")?\s*\/>\s*\n?\s*<\/p>/g,
    (match, imagePath, alt) => {
      const cleanPath = imagePath.replace('@site/static/', '/');
      return `![${alt}](${cleanPath})`;
    }
  );
  content = content.replace(
    /<iframe[^>]*src="https:\/\/www\.youtube\.com\/embed\/([a-zA-Z0-9_-]+)[^"]*"[^>]*title="([^"]*)"[^>]*>[\s\S]*?<\/iframe>/g,
    'Watch the video: [$2](https://www.youtube.com/watch?v=$1)'
  );
  content = content.replace(
    /<video[^>]*>\s*<source src=["']([^"']+)["'][^>]*>\s*<\/video>/g,
    '<video controls>\n  <source src="$1" type="video/mp4" />\n  <p>Video demonstration: $1</p>\n</video>'
  );
  content = content.replace(/<Head>[\s\S]*?<\/Head>/g, '');
  // Convert SvgThemeRenderer to markdown image so diagram appears in source .md view
  content = content.replace(/<SvgThemeRenderer\s+([\s\S]+?)\/>/g, (_, attrs) => {
    const lightMatch = attrs.match(/lightSrc=\{?["']([^"']+)["']\}?/);
    const darkMatch = attrs.match(/darkSrc=\{?["']([^"']+)["']\}?/);
    const altMatch = attrs.match(/alt=["']([^"']*)["']/);
    const src = (lightMatch && lightMatch[1]) || (darkMatch && darkMatch[1]);
    const alt = (altMatch && altMatch[1]) || 'Diagram';
    return src ? `![${alt}](${src})\n\n` : '';
  });
  content = convertTabsToMarkdown(content);
  content = convertDetailsToMarkdown(content);
  // Convert DocCardGrid + DocCard to markdown links first so .md is readable
  content = convertDocCardGridToMarkdown(content);
  // Strip any remaining JSX (nested-aware) so we don't leave fragments
  content = stripJsxComponents(content);
  content = content.replace(
    /!\[([^\]]*)\]\((\.\/)?img\/([^)]+)\)/g,
    (match, alt, relPrefix, filename) => `![${alt}](/docs/${fileDir}img/${filename})`
  );
  content = content.replace(/^\s*\n/, '');
  return content;
}

function findDocFiles(dir, fileList = [], baseDir = dir) {
  const files = fs.readdirSync(dir);
  files.forEach((file) => {
    const filePath = path.join(dir, file);
    const stat = fs.statSync(filePath);
    if (stat.isDirectory()) {
      findDocFiles(filePath, fileList, baseDir);
    } else if (file.endsWith('.md') || file.endsWith('.mdx')) {
      const relativePath = path.relative(baseDir, filePath);
      fileList.push(relativePath);
    }
  });
  return fileList;
}

async function copyImageDirectories(docsDir, buildDir) {
  const imageDirs = [];
  function findImgDirs(dir, baseDir = dir) {
    const files = fs.readdirSync(dir);
    files.forEach((file) => {
      const filePath = path.join(dir, file);
      const stat = fs.statSync(filePath);
      if (stat.isDirectory()) {
        if (file === 'img') {
          const relativePath = path.relative(baseDir, dir);
          imageDirs.push({ source: filePath, relativePath });
        } else {
          findImgDirs(filePath, baseDir);
        }
      }
    });
  }
  findImgDirs(docsDir);
  let copiedCount = 0;
  for (const { source, relativePath } of imageDirs) {
    const destination = path.join(buildDir, relativePath, 'img');
    try {
      await fs.copy(source, destination);
      const imageCount = fs.readdirSync(source).length;
      console.log(`  ✓ Copied: ${relativePath}/img/ (${imageCount} images)`);
      copiedCount++;
    } catch (error) {
      console.error(`  ✗ Failed to copy ${relativePath}/img/:`, error.message);
    }
  }
  return copiedCount;
}

export default function markdownSourceDocsPlugin(context, options) {
  const base = basePlugin(context, options);
  return {
    ...base,
    async postBuild({ outDir }) {
      const docsDir = path.join(context.siteDir, 'docs');
      const buildDocsDir = path.join(outDir, 'docs');
      console.log('[markdown-source-plugin] Copying markdown source files (.md and .mdx)...');
      const docFiles = findDocFiles(docsDir);
      let copiedCount = 0;
      for (const docFile of docFiles) {
        const sourcePath = path.join(docsDir, docFile);
        const destPath = path.join(buildDocsDir, docFile.replace(/\.mdx?$/, '.md'));
        try {
          await fs.ensureDir(path.dirname(destPath));
          const content = await fs.readFile(sourcePath, 'utf8');
          const cleanedContent = cleanMarkdownForDisplay(content, docFile);
          await fs.writeFile(destPath, cleanedContent, 'utf8');
          copiedCount++;
          console.log(`  ✓ Processed: ${docFile} → docs/${path.relative(buildDocsDir, destPath)}`);
        } catch (error) {
          console.error(`  ✗ Failed to process ${docFile}:`, error.message);
        }
      }
      console.log(`[markdown-source-plugin] Successfully copied ${copiedCount} doc files`);
      console.log('[markdown-source-plugin] Copying image directories...');
      const imgDirCount = await copyImageDirectories(docsDir, buildDocsDir);
      console.log(`[markdown-source-plugin] Successfully copied ${imgDirCount} image directories`);
    },
  };
}
