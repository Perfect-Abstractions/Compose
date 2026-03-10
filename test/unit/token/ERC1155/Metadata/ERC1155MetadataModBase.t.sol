// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30 <0.9.0;

/* Compose
 * https://compose.diamonds
 */

import {Base_Test} from "test/Base.t.sol";
import {ERC1155MetadataModHarness} from "test/harnesses/token/ERC1155/ERC1155MetadataModHarness.sol";

abstract contract ERC1155MetadataMod_Base_Test is Base_Test {
    ERC1155MetadataModHarness internal harness;

    function setUp() public virtual override {
        Base_Test.setUp();
        harness = new ERC1155MetadataModHarness();
        vm.label(address(harness), "ERC1155MetadataModHarness");
    }
}
