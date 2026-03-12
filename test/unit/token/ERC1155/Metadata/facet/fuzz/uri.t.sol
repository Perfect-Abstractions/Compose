// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {ERC1155MetadataFacet_Base_Test} from "test/unit/token/ERC1155/Metadata/ERC1155MetadataFacetBase.t.sol";
import {ERC1155MetadataFacet} from "src/token/ERC1155/Metadata/ERC1155MetadataFacet.sol";

/**
 * @dev BTT spec: test/trees/ERC1155.tree
 *
 * Note: Default URI and token-specific URI are set via the mod (setURI, setBaseURI, setTokenURI).
 * The facet only exposes uri(id). So when testing the facet in isolation, storage is never set;
 * uri() returns empty string for default and for token-specific. We test that uri() is callable
 * and returns the empty string when uninitialized. For "default uri" and "baseURI+tokenURI"
 * behavior we use the Metadata mod harness (same storage as facet) in Metadata/mod/fuzz/metadata.t.sol.
 */
contract Uri_ERC1155MetadataFacet_Fuzz_Test is ERC1155MetadataFacet_Base_Test {
    function testFuzz_ShouldReturnUri_Uri_WhenUninitialized(uint256 id) external view {
        assertEq(facet.uri(id), "", "uri uninitialized");
    }
}
