// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30 <0.9.0;

/* Compose
 * https://compose.diamonds
 */

import {stdError} from "forge-std/StdError.sol";
import {Base_Test} from "test/Base.t.sol";
import {ERC20StorageUtils} from "test/utils/storage/ERC20StorageUtils.sol";
import {ERC20TransferFacet} from "src/token/ERC20/ERC20/ERC20TransferFacet.sol";

/// @dev BTT spec: test/trees/ERC20.tree
contract ERC20TransferFacet_Base_Test is Base_Test {
    using ERC20StorageUtils for address;

    ERC20TransferFacet internal facet;

    function setUp() public virtual override {
        Base_Test.setUp();
        facet = new ERC20TransferFacet();
        vm.label(address(facet), "ERC20TransferFacet");
    }
}
