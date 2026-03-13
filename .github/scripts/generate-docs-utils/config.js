/**
 * Configuration for documentation generation
 *
 * Centralized configuration for paths, settings, and defaults.
 * Modify this file to change documentation output paths or behavior.
 */

module.exports = {
  // ============================================================================
  // Input Paths
  // ============================================================================

  /** Directory containing forge doc output */
  forgeDocsDir: 'docs/src/src',

  /** Source code directory to mirror */
  srcDir: 'src',

  // ============================================================================
  // Output Paths
  // ============================================================================

  /**
   * Base output directory for contract documentation
   * Structure mirrors src/ automatically
   */
  contractsOutputDir: 'website/docs/contracts',

  // ============================================================================
  // Sidebar Positions
  // ============================================================================

  /** Default sidebar position for contracts without explicit mapping */
  defaultSidebarPosition: 50,

  /**
   * Contract-specific sidebar positions
   * Maps contract name to position number (lower = higher in sidebar)
   *
   * Convention:
   * - Facets come before their corresponding modules
   * - Core/base contracts come before extensions
   * - Burn facets come after main facets
   */
  contractPositions: {
    // Diamond core – order: DiamondMod, DiamondInspectFacet, DiamondUpgradeFacet, DiamondUpgradeMod, then Examples
    DiamondMod: 1,
    DiamondInspectFacet: 2,
    DiamondUpgradeFacet: 3,
    DiamondUpgradeMod: 4,
    DiamondCutMod: 3,
    DiamondCutFacet: 1,
    DiamondLoupeFacet: 4,

    // Access - Owner pattern
    OwnerMod: 2,
    OwnerFacet: 1,

    // Access - Two-step owner
    OwnerTwoStepsMod: 2,
    OwnerTwoStepsFacet: 1,

    // Access - AccessControl pattern
    AccessControlMod: 2,
    AccessControlFacet: 1,

    // Access - AccessControlPausable
    AccessControlPausableMod: 2,
    AccessControlPausableFacet: 1,

    // Access - AccessControlTemporal
    AccessControlTemporalMod: 2,
    AccessControlTemporalFacet: 1,

    // ERC-20 base
    ERC20Mod: 2,
    ERC20Facet: 1,
    ERC20BurnFacet: 3,

    // ERC-20 Bridgeable
    ERC20BridgeableMod: 2,
    ERC20BridgeableFacet: 1,

    // ERC-20 Permit
    ERC20PermitMod: 2,
    ERC20PermitFacet: 1,

    // ERC-721 base
    ERC721Mod: 2,
    ERC721Facet: 1,
    ERC721BurnFacet: 3,

    // ERC-721 Enumerable
    ERC721EnumerableMod: 2,
    ERC721EnumerableFacet: 1,
    ERC721EnumerableBurnFacet: 3,

    // ERC-1155
    ERC1155Mod: 2,
    ERC1155Facet: 1,

    // ERC-6909
    ERC6909Mod: 2,
    ERC6909Facet: 1,

    // Royalty
    RoyaltyMod: 2,
    RoyaltyFacet: 1,

    // Libraries
    NonReentrancyMod: 1,
    ERC165Mod: 2,
    ERC165Facet: 1,
  },

  /**
   * Diamond docs: sidebar labels for the sidebar nav (e.g. "Module", "Inspect Facet").
   * File names stay as contract names (e.g. DiamondMod.mdx, DiamondInspectFacet.mdx).
   */
  diamondSidebarLabels: {
    DiamondMod: 'Module',
    DiamondInspectFacet: 'Inspect Facet',
    DiamondUpgradeFacet: 'Upgrade Facet',
    DiamondUpgradeMod: 'Upgrade Module',
  },

  // ============================================================================
  // Repository Configuration
  // ============================================================================

  /** Main repository URL - always use this for source links */
  mainRepoUrl: 'https://github.com/Perfect-Abstractions/Compose',

  /**
   * Normalize gitSource URL to always point to the main repository's main branch
   * Replaces any fork or incorrect repository URLs with the main repo URL
   * Converts blob URLs to tree URLs pointing to main branch
   * @param {string} gitSource - Original gitSource URL from forge doc
   * @returns {string} Normalized gitSource URL
   */
  normalizeGitSource(gitSource) {
    if (!gitSource) return gitSource;
    
    // Pattern: https://github.com/USER/Compose/blob/COMMIT/src/path/to/file.sol
    // Convert to: https://github.com/Perfect-Abstractions/Compose/tree/main/src/path/to/file.sol
    const githubUrlPattern = /https:\/\/github\.com\/[^\/]+\/Compose\/(?:blob|tree)\/[^\/]+\/(.+)/;
    const match = gitSource.match(githubUrlPattern);
    
    if (match) {
      // Extract the path after the repo name (should start with src/)
      const pathPart = match[1];
      // Ensure it starts with src/ (remove any leading src/ if duplicated)
      const normalizedPath = pathPart.startsWith('src/') ? pathPart : `src/${pathPart}`;
      return `${this.mainRepoUrl}/tree/main/${normalizedPath}`;
    }
    
    // If it doesn't match the pattern, try to construct from the main repo
    // Extract just the file path if it's a relative path or partial URL
    if (gitSource.includes('/src/')) {
      const srcIndex = gitSource.indexOf('/src/');
      const pathAfterSrc = gitSource.substring(srcIndex + 1);
      return `${this.mainRepoUrl}/tree/main/${pathAfterSrc}`;
    }
    
    // If it doesn't match any pattern, return as-is (might be a different format)
    return gitSource;
  },
};
