// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {ERC721TransferFacet_Base_Test} from "test/unit/token/ERC721/Transfer/ERC721TransferFacetBase.t.sol";
import {ERC721TransferFacet} from "src/token/ERC721/Transfer/ERC721TransferFacet.sol";

/**
 *  @dev BTT spec: test/trees/ERC721.tree
 */
contract ExportSelectors_ERC721TransferFacet_Unit_Test is ERC721TransferFacet_Base_Test {
    function test_ShouldReturnSelectors_ExportSelectors() external view {
        bytes memory selectors = facet.exportSelectors();
        bytes memory expected = abi.encodePacked(
            ERC721TransferFacet.transferFrom.selector,
            bytes4(keccak256("safeTransferFrom(address,address,uint256)")),
            bytes4(keccak256("safeTransferFrom(address,address,uint256,bytes)"))
        );
        assertEq(selectors, expected, "exportSelectors");
    }
}

