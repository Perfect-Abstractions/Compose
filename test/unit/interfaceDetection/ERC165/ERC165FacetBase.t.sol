// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {Test} from "forge-std/Test.sol";
import {IERC165} from "src/interfaceDetection/ERC165/ERC165Facet.sol";
import {ERC165FacetHarness} from "test/utils/harnesses/interfaceDetection/ERC165/ERC165FacetHarness.sol";

/**
 * @dev BTT spec: test/trees/ERC165.tree
 */
abstract contract ERC165Facet_Base_Test is Test {
    ERC165FacetHarness internal erc165Facet;

    bytes4 internal constant IERC165_INTERFACE_ID = type(IERC165).interfaceId;
    bytes4 internal constant IERC721_INTERFACE_ID = 0x80ac58cd;
    bytes4 internal constant IERC20_INTERFACE_ID = 0x36372b07;
    bytes4 internal constant INVALID_INTERFACE_ID = 0xffffffff;
    bytes4 internal constant CUSTOM_INTERFACE_ID = 0x12345678;
    bytes4 internal constant ZERO_INTERFACE_ID = 0x00000000;

    function setUp() public virtual {
        erc165Facet = new ERC165FacetHarness();
        erc165Facet.initialize();
    }
}

