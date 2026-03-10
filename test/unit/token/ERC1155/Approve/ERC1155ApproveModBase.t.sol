// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30 <0.9.0;

/* Compose
 * https://compose.diamonds
 */

import {Base_Test} from "test/Base.t.sol";
import {ERC1155ApproveModHarness} from "test/utils/harnesses/token/ERC1155/ERC1155ApproveModHarness.sol";
import {ERC1155StorageUtils} from "test/utils/storage/ERC1155StorageUtils.sol";

abstract contract ERC1155ApproveMod_Base_Test is Base_Test {
    using ERC1155StorageUtils for address;

    ERC1155ApproveModHarness internal harness;

    function setUp() public virtual override {
        Base_Test.setUp();
        harness = new ERC1155ApproveModHarness();
        vm.label(address(harness), "ERC1155ApproveModHarness");
    }
}
