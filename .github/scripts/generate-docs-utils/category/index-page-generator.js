/**
 * Index Page Generator
 *
 * Generates index.mdx files for category directories with custom DocCard components.
 * This module provides utilities for creating styled category index pages.
 */

const fs = require('fs');
const path = require('path');
const CONFIG = require('../config');

// ============================================================================
// Category Items Discovery
// ============================================================================

/**
 * Get all items (documents and subcategories) in a directory
 * @param {string} outputDir - Directory to scan
 * @param {string} relativePath - Relative path from library dir
 * @param {Function} generateLabel - Function to generate labels from names
 * @param {Function} generateDescription - Function to generate descriptions
 * @returns {Array} Array of items with type, name, label, href, description
 */
function getCategoryItems(outputDir, relativePath, generateLabel, generateDescription) {
  const items = [];

  if (!fs.existsSync(outputDir)) {
    return items;
  }

  const entries = fs.readdirSync(outputDir, { withFileTypes: true });

  for (const entry of entries) {
    // Skip hidden files, category files, and index files
    if (entry.name.startsWith('.') || 
        entry.name === '_category_.json' || 
        entry.name === 'index.mdx') {
      continue;
    }

    if (entry.isFile() && entry.name.endsWith('.mdx')) {
      // It's a document
      const docName = entry.name.replace('.mdx', '');
      const docPath = path.join(outputDir, entry.name);
      
      // Try to read frontmatter for title and description
      let title = generateLabel(docName);
      let description = '';
      
      try {
        const content = fs.readFileSync(docPath, 'utf8');
        const frontmatterMatch = content.match(/^---\n([\s\S]*?)\n---/);
        if (frontmatterMatch) {
          const frontmatter = frontmatterMatch[1];
          const titleMatch = frontmatter.match(/^title:\s*["']?(.*?)["']?$/m);
          const descMatch = frontmatter.match(/^description:\s*["']?(.*?)["']?$/m);
          if (titleMatch) title = titleMatch[1].trim();
          if (descMatch) description = descMatch[1].trim();
        }
      } catch (error) {
        // If reading fails, use defaults
      }

      const docRelativePath = relativePath ? `${relativePath}/${docName}` : docName;
      items.push({
        type: 'doc',
        name: docName,
        label: title,
        description: description,
        href: `/docs/library/${docRelativePath}`,
      });
    } else if (entry.isDirectory()) {
      // It's a subcategory
      const subcategoryName = entry.name;
      const subcategoryLabel = generateLabel(subcategoryName);
      const subcategoryRelativePath = relativePath ? `${relativePath}/${subcategoryName}` : subcategoryName;
      const subcategoryDescription = generateDescription(subcategoryName, relativePath.split('/'));
      
      items.push({
        type: 'category',
        name: subcategoryName,
        label: subcategoryLabel,
        description: subcategoryDescription,
        href: `/docs/library/${subcategoryRelativePath}`,
      });
    }
  }

  // Sort items: categories first, then docs, both alphabetically
  items.sort((a, b) => {
    if (a.type !== b.type) {
      return a.type === 'category' ? -1 : 1;
    }
    return a.label.localeCompare(b.label);
  });

  return items;
}

// ============================================================================
// MDX Content Generation
// ============================================================================

/**
 * Generate MDX content for a category index page
 * @param {string} label - Category label
 * @param {string} description - Category description
 * @param {Array} items - Array of items to display
 * @returns {string} Generated MDX content
 */
function generateIndexMdxContent(label, description, items) {
  // Escape quotes in label and description for frontmatter
  const escapedLabel = label.replace(/"/g, '\\"');
  const escapedDescription = description.replace(/"/g, '\\"');
  
  let mdxContent = `---
title: "${escapedLabel}"
description: "${escapedDescription}"
sidebar_class_name: hidden
---

import DocCard, { DocCardGrid } from '@site/src/components/docs/DocCard';
import DocSubtitle from '@site/src/components/docs/DocSubtitle';
import Icon from '@site/src/components/ui/Icon';

<DocSubtitle>
  ${escapedDescription}
</DocSubtitle>

`;

  if (items.length > 0) {
    mdxContent += `<DocCardGrid columns={2}>\n`;
    
    for (const item of items) {
      const iconName = item.type === 'category' ? 'package' : 'book';
      const itemDescription = item.description ? `"${item.description.replace(/"/g, '\\"')}"` : '""';
      
      mdxContent += `  <DocCard
    title="${item.label.replace(/"/g, '\\"')}"
    description={${itemDescription}}
    href="${item.href}"
    icon={<Icon name="${iconName}" size={28} />}
    size="medium"
  />\n`;
    }
    
    mdxContent += `</DocCardGrid>\n`;
  } else {
    mdxContent += `_No items in this category yet._\n`;
  }

  return mdxContent;
}

// ============================================================================
// Index File Creation
// ============================================================================

/**
 * Generate index.mdx file for a category
 * @param {string} outputDir - Directory to create index file in
 * @param {string} relativePath - Relative path from library dir
 * @param {string} label - Category label
 * @param {string} description - Category description
 * @param {Function} generateLabel - Function to generate labels from names
 * @param {Function} generateDescription - Function to generate descriptions
 * @param {boolean} overwrite - Whether to overwrite existing files (default: false)
 * @returns {boolean} True if file was created/updated, false if skipped
 */
function createCategoryIndexFile(
  outputDir,
  relativePath,
  label,
  description,
  generateLabel,
  generateDescription,
  overwrite = false
) {
  const indexFile = path.join(outputDir, 'index.mdx');

  // Don't overwrite existing index files unless explicitly requested (allows manual customization)
  if (!overwrite && fs.existsSync(indexFile)) {
    return false;
  }

  // Get items in this category
  const items = getCategoryItems(outputDir, relativePath, generateLabel, generateDescription);

  // Generate MDX content
  const mdxContent = generateIndexMdxContent(label, description, items);

  // Ensure directory exists
  fs.mkdirSync(outputDir, { recursive: true });
  fs.writeFileSync(indexFile, mdxContent);

  return true;
}

// ============================================================================
// Exports
// ============================================================================

module.exports = {
  getCategoryItems,
  generateIndexMdxContent,
  createCategoryIndexFile,
};

