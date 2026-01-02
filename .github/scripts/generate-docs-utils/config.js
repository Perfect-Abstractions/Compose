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
   * - Modules come before their corresponding facets
   * - Core/base contracts come before extensions
   * - Burn facets come after main facets
   */
  contractPositions: {
    // Diamond core
    DiamondMod: 1,
    DiamondCutMod: 2,
    DiamondCutFacet: 3,
    DiamondLoupeFacet: 4,

    // Access - Owner pattern
    OwnerMod: 1,
    OwnerFacet: 2,

    // Access - Two-step owner
    OwnerTwoStepsMod: 1,
    OwnerTwoStepsFacet: 2,

    // Access - AccessControl pattern
    AccessControlMod: 1,
    AccessControlFacet: 2,

    // Access - AccessControlPausable
    AccessControlPausableMod: 1,
    AccessControlPausableFacet: 2,

    // Access - AccessControlTemporal
    AccessControlTemporalMod: 1,
    AccessControlTemporalFacet: 2,

    // ERC-20 base
    ERC20Mod: 1,
    ERC20Facet: 2,
    ERC20BurnFacet: 3,

    // ERC-20 Bridgeable
    ERC20BridgeableMod: 1,
    ERC20BridgeableFacet: 2,

    // ERC-20 Permit
    ERC20PermitMod: 1,
    ERC20PermitFacet: 2,

    // ERC-721 base
    ERC721Mod: 1,
    ERC721Facet: 2,
    ERC721BurnFacet: 3,

    // ERC-721 Enumerable
    ERC721EnumerableMod: 1,
    ERC721EnumerableFacet: 2,
    ERC721EnumerableBurnFacet: 3,

    // ERC-1155
    ERC1155Mod: 1,
    ERC1155Facet: 2,

    // ERC-6909
    ERC6909Mod: 1,
    ERC6909Facet: 2,

    // Royalty
    RoyaltyMod: 1,
    RoyaltyFacet: 2,

    // Libraries
    NonReentrancyMod: 1,
    ERC165Mod: 1,
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
