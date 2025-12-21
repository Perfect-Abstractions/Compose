/**
 * Category Generator
 *
 * Automatically generates _category_.json files to mirror
 * the src/ folder structure in the documentation.
 *
 * This module provides:
 * - Source structure scanning
 * - Category file generation
 * - Path computation for doc output
 * - Structure synchronization
 */

const fs = require('fs');
const path = require('path');
const CONFIG = require('./config');

// ============================================================================
// Constants
// ============================================================================

/**
 * Human-readable labels for directory names
 * Add new entries here when adding new top-level categories
 */
const CATEGORY_LABELS = {
  // Top-level categories
  access: 'Access Control',
  token: 'Token Standards',
  diamond: 'Diamond Core',
  libraries: 'Utilities',
  utils: 'Utilities',
  interfaceDetection: 'Interface Detection',

  // Token subcategories
  ERC20: 'ERC-20',
  ERC721: 'ERC-721',
  ERC1155: 'ERC-1155',
  ERC6909: 'ERC-6909',
  Royalty: 'Royalty',

  // Access subcategories
  AccessControl: 'Access Control',
  AccessControlPausable: 'Pausable Access Control',
  AccessControlTemporal: 'Temporal Access Control',
  Owner: 'Owner',
  OwnerTwoSteps: 'Two-Step Owner',
};

/**
 * Descriptions for categories
 * Add new entries here for custom descriptions
 */
const CATEGORY_DESCRIPTIONS = {
  // Top-level categories
  access: 'Access control patterns for permission management in Compose diamonds.',
  token: 'Token standard implementations for Compose diamonds.',
  diamond: 'Core diamond proxy functionality for ERC-2535 diamonds.',
  libraries: 'Utility libraries and helpers for diamond development.',
  utils: 'Utility libraries and helpers for diamond development.',
  interfaceDetection: 'ERC-165 interface detection support.',

  // Token subcategories
  ERC20: 'ERC-20 fungible token implementations.',
  ERC721: 'ERC-721 non-fungible token implementations.',
  ERC1155: 'ERC-1155 multi-token implementations.',
  ERC6909: 'ERC-6909 minimal multi-token implementations.',
  Royalty: 'ERC-2981 royalty standard implementations.',

  // Access subcategories
  AccessControl: 'Role-based access control (RBAC) pattern.',
  AccessControlPausable: 'RBAC with pause functionality.',
  AccessControlTemporal: 'Time-limited role-based access control.',
  Owner: 'Single-owner access control pattern.',
  OwnerTwoSteps: 'Two-step ownership transfer pattern.',
};

/**
 * Sidebar positions for categories
 * Lower numbers appear first in the sidebar
 */
const CATEGORY_POSITIONS = {
  // Top-level (lower = higher priority)
  diamond: 1,
  access: 2,
  token: 3,
  libraries: 4,
  utils: 4,
  interfaceDetection: 5,

  // Token subcategories
  ERC20: 1,
  ERC721: 2,
  ERC1155: 3,
  ERC6909: 4,
  Royalty: 5,

  // Access subcategories
  Owner: 1,
  OwnerTwoSteps: 2,
  AccessControl: 3,
  AccessControlPausable: 4,
  AccessControlTemporal: 5,

  // Leaf directories (ERC20/ERC20, etc.) - alphabetical
  ERC20Bridgeable: 2,
  ERC20Permit: 3,
  ERC721Enumerable: 2,
};

// ============================================================================
// Label & Description Generation
// ============================================================================

/**
 * Generate a human-readable label from a directory name
 * @param {string} name - Directory name (e.g., 'AccessControlPausable', 'ERC20')
 * @returns {string} Human-readable label
 */
function generateLabel(name) {
  // Check explicit mapping first
  if (CATEGORY_LABELS[name]) {
    return CATEGORY_LABELS[name];
  }

  // Handle ERC standards specially
  if (/^ERC\d+/.test(name)) {
    const match = name.match(/^(ERC)(\d+)(.*)$/);
    if (match) {
      const variant = match[3]
        ? ' ' + match[3].replace(/([A-Z])/g, ' $1').trim()
        : '';
      return `ERC-${match[2]}${variant}`;
    }
    return name;
  }

  // CamelCase to Title Case with spaces
  return name.replace(/([A-Z])/g, ' $1').replace(/^ /, '').trim();
}

/**
 * Generate description for a category based on its path
 * @param {string} name - Directory name
 * @param {string[]} parentPath - Parent path segments
 * @returns {string} Category description
 */
function generateDescription(name, parentPath = []) {
  // Check explicit mapping first
  if (CATEGORY_DESCRIPTIONS[name]) {
    return CATEGORY_DESCRIPTIONS[name];
  }

  // Generate from context
  const label = generateLabel(name);
  const parent = parentPath[parentPath.length - 1];

  if (parent === 'token') {
    return `${label} token implementations with modules and facets.`;
  }
  if (parent === 'access') {
    return `${label} access control pattern for Compose diamonds.`;
  }
  if (parent === 'ERC20' || parent === 'ERC721') {
    return `${label} extension for ${generateLabel(parent)} tokens.`;
  }

  return `${label} components for Compose diamonds.`;
}

/**
 * Get sidebar position for a category
 * @param {string} name - Directory name
 * @param {number} depth - Nesting depth
 * @returns {number} Sidebar position
 */
function getCategoryPosition(name, depth) {
  if (CATEGORY_POSITIONS[name] !== undefined) {
    return CATEGORY_POSITIONS[name];
  }
  return 99; // Default to end
}

// ============================================================================
// Source Structure Scanning
// ============================================================================

/**
 * Check if a directory contains .sol files (directly or in subdirectories)
 * @param {string} dirPath - Directory path to check
 * @returns {boolean} True if contains .sol files
 */
function containsSolFiles(dirPath) {
  try {
    const entries = fs.readdirSync(dirPath, { withFileTypes: true });

    for (const entry of entries) {
      if (entry.isFile() && entry.name.endsWith('.sol')) {
        return true;
      }
      if (entry.isDirectory() && !entry.name.startsWith('.')) {
        if (containsSolFiles(path.join(dirPath, entry.name))) {
          return true;
        }
      }
    }
  } catch (error) {
    console.warn(`Warning: Could not read directory ${dirPath}: ${error.message}`);
  }

  return false;
}

/**
 * Scan the src/ directory and build structure map
 * @returns {Map<string, object>} Map of relative paths to category info
 */
function scanSourceStructure() {
  const srcDir = CONFIG.srcDir || 'src';
  const structure = new Map();

  function scanDir(dirPath, relativePath = '') {
    let entries;
    try {
      entries = fs.readdirSync(dirPath, { withFileTypes: true });
    } catch (error) {
      console.error(`Error reading directory ${dirPath}: ${error.message}`);
      return;
    }

    for (const entry of entries) {
      if (!entry.isDirectory()) continue;

      // Skip hidden directories and interfaces
      if (entry.name.startsWith('.') || entry.name === 'interfaces') {
        continue;
      }

      const fullPath = path.join(dirPath, entry.name);
      const relPath = relativePath ? `${relativePath}/${entry.name}` : entry.name;

      // Only include directories that contain .sol files
      if (containsSolFiles(fullPath)) {
        const parts = relPath.split('/');
        structure.set(relPath, {
          name: entry.name,
          path: relPath,
          depth: parts.length,
          parent: relativePath || null,
          parentParts: relativePath ? relativePath.split('/') : [],
        });

        // Recurse into subdirectories
        scanDir(fullPath, relPath);
      }
    }
  }

  if (fs.existsSync(srcDir)) {
    scanDir(srcDir);
  } else {
    console.warn(`Warning: Source directory ${srcDir} does not exist`);
  }

  return structure;
}

// ============================================================================
// Category File Generation
// ============================================================================

/**
 * Map source directory name to docs directory name
 * @param {string} srcName - Source directory name
 * @returns {string} Documentation directory name
 */
function mapDirectoryName(srcName) {
  // Map libraries -> utils for URL consistency
  if (srcName === 'libraries') {
    return 'utils';
  }
  return srcName;
}

/**
 * Compute slug from output directory path
 * @param {string} outputDir - Full output directory path
 * @param {string} libraryDir - Base library directory
 * @returns {string} Slug path (e.g., '/docs/library/access')
 */
function computeSlug(outputDir, libraryDir) {
  const relativePath = path.relative(libraryDir, outputDir);
  
  if (!relativePath || relativePath.startsWith('..')) {
    // Root library directory
    return '/docs/library';
  }

  // Convert path separators and create slug
  const normalizedPath = relativePath.replace(/\\/g, '/');
  return `/docs/library/${normalizedPath}`;
}

/**
 * Create a _category_.json file for a directory
 * @param {string} outputDir - Directory to create category file in
 * @param {string} name - Directory name
 * @param {string} relativePath - Relative path from library dir
 * @param {number} depth - Nesting depth
 * @returns {boolean} True if file was created, false if it already existed
 */
function createCategoryFile(outputDir, name, relativePath, depth) {
  const categoryFile = path.join(outputDir, '_category_.json');
  const libraryDir = CONFIG.libraryOutputDir || 'website/docs/library';

  // Don't overwrite existing category files (allows manual customization)
  if (fs.existsSync(categoryFile)) {
    return false;
  }

  // Get the actual directory name from the output path (may be mapped, e.g., utils instead of libraries)
  const actualDirName = path.basename(outputDir);
  const parentParts = relativePath.split('/').slice(0, -1);
  // Use actual directory name for label generation (supports both original and mapped names)
  const label = generateLabel(actualDirName);
  const position = getCategoryPosition(actualDirName, depth);
  const description = generateDescription(actualDirName, parentParts);
  const slug = computeSlug(outputDir, libraryDir);

  const category = {
    label,
    position,
    collapsible: true,
    collapsed: true, // Collapse all categories by default
    link: {
      type: 'generated-index',
      slug,
      description,
    },
  };

  // Ensure directory exists
  fs.mkdirSync(outputDir, { recursive: true });
  fs.writeFileSync(categoryFile, JSON.stringify(category, null, 2) + '\n');

  return true;
}

/**
 * Ensure the base library category file exists
 * @param {string} libraryDir - Path to library directory
 * @returns {boolean} True if created, false if existed
 */
function ensureBaseCategory(libraryDir) {
  const categoryFile = path.join(libraryDir, '_category_.json');

  if (fs.existsSync(categoryFile)) {
    return false;
  }

  const baseCategory = {
    label: 'Library',
    position: 4,
    collapsible: true,
    collapsed: true, // Collapse base Library category by default
    link: {
      type: 'generated-index',
      slug: '/docs/library',
      title: 'Library Reference',
      description: 'API reference for all Compose modules and facets.',
    },
  };

  fs.mkdirSync(libraryDir, { recursive: true });
  fs.writeFileSync(categoryFile, JSON.stringify(baseCategory, null, 2) + '\n');

  return true;
}

// ============================================================================
// Path Computation
// ============================================================================

/**
 * Compute output path for a source file
 * Mirrors the src/ structure in website/docs/library/
 * Applies directory name mapping (e.g., libraries -> utils)
 *
 * @param {string} solFilePath - Path to .sol file (e.g., 'src/access/AccessControl/AccessControlMod.sol')
 * @returns {object} Output path information
 */
function computeOutputPath(solFilePath) {
  const libraryDir = CONFIG.libraryOutputDir || 'website/docs/library';

  // Normalize path separators
  const normalizedPath = solFilePath.replace(/\\/g, '/');

  // Remove 'src/' prefix and '.sol' extension
  const relativePath = normalizedPath.replace(/^src\//, '').replace(/\.sol$/, '');

  const parts = relativePath.split('/');
  const fileName = parts.pop();

  // Map directory names (e.g., libraries -> utils)
  const mappedParts = parts.map(part => mapDirectoryName(part));

  const outputDir = path.join(libraryDir, ...mappedParts);
  const outputFile = path.join(outputDir, `${fileName}.mdx`);

  return {
    outputDir,
    outputFile,
    relativePath: mappedParts.join('/'),
    fileName,
    category: mappedParts[0] || '',
    subcategory: mappedParts[1] || '',
    fullRelativePath: mappedParts.join('/'),
    depth: mappedParts.length,
  };
}

/**
 * Ensure all parent category files exist for a given output path
 * Creates _category_.json files for each directory level
 *
 * @param {string} outputDir - Full output directory path
 */
function ensureCategoryFiles(outputDir) {
  const libraryDir = CONFIG.libraryOutputDir || 'website/docs/library';

  // Get relative path from library base
  const relativePath = path.relative(libraryDir, outputDir);

  if (!relativePath || relativePath.startsWith('..')) {
    return; // outputDir is not under libraryDir
  }

  // Ensure base category exists
  ensureBaseCategory(libraryDir);

  // Walk up the directory tree, creating category files
  const parts = relativePath.split(path.sep);
  let currentPath = libraryDir;

  for (let i = 0; i < parts.length; i++) {
    currentPath = path.join(currentPath, parts[i]);
    const segment = parts[i];
    // Use the mapped path for the relative path (already mapped in computeOutputPath)
    const relPath = parts.slice(0, i + 1).join('/');

    createCategoryFile(currentPath, segment, relPath, i + 1);
  }
}

// ============================================================================
// Structure Synchronization
// ============================================================================

/**
 * Synchronize docs structure with src structure
 * Creates any missing category directories and _category_.json files
 *
 * @returns {object} Summary of created categories
 */
function syncDocsStructure() {
  const structure = scanSourceStructure();
  const libraryDir = CONFIG.libraryOutputDir || 'website/docs/library';

  const created = [];
  const existing = [];

  // Ensure base library directory exists with category
  if (ensureBaseCategory(libraryDir)) {
    created.push('library');
  } else {
    existing.push('library');
  }

  // Create category for each directory in the structure
  // Sort by path to ensure parents are created before children
  const sortedPaths = Array.from(structure.entries()).sort((a, b) =>
    a[0].localeCompare(b[0])
  );

  for (const [relativePath, info] of sortedPaths) {
    // Map directory names in the path (e.g., libraries -> utils)
    const pathParts = relativePath.split('/');
    const mappedPathParts = pathParts.map(part => mapDirectoryName(part));
    const mappedRelativePath = mappedPathParts.join('/');
    const outputDir = path.join(libraryDir, ...mappedPathParts);
    
    const wasCreated = createCategoryFile(
      outputDir,
      info.name,
      mappedRelativePath,
      info.depth
    );

    if (wasCreated) {
      created.push(mappedRelativePath);
    } else {
      existing.push(mappedRelativePath);
    }
  }

  return {
    created,
    existing,
    total: structure.size,
    structure,
  };
}

// ============================================================================
// Exports
// ============================================================================

module.exports = {
  // Core functions
  scanSourceStructure,
  syncDocsStructure,
  computeOutputPath,
  ensureCategoryFiles,

  // Utilities
  generateLabel,
  generateDescription,
  getCategoryPosition,
  containsSolFiles,
  mapDirectoryName,
  computeSlug,

  // For extending/customizing
  CATEGORY_LABELS,
  CATEGORY_DESCRIPTIONS,
  CATEGORY_POSITIONS,
};

