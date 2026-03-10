// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30 <0.9.0;

/* Compose
 * https://compose.diamonds
 */

import {Base_Test} from "test/Base.t.sol";
import {ERC1155MintModHarness} from "test/harnesses/token/ERC1155/ERC1155MintModHarness.sol";
import {ERC1155StorageUtils} from "test/utils/storage/ERC1155StorageUtils.sol";

abstract contract ERC1155MintMod_Base_Test is Base_Test {
    using ERC1155StorageUtils for address;

    ERC1155MintModHarness internal harness;

    function setUp() public virtual override {
        Base_Test.setUp();
        harness = new ERC1155MintModHarness();
        vm.label(address(harness), "ERC1155MintModHarness");
    }
}
