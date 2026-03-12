// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30 <0.9.0;

/* Compose
 * https://compose.diamonds
 */

import {Base_Test} from "test/Base.t.sol";
import {ERC721EnumerableBurnModHarness} from "test/utils/harnesses/token/ERC721/ERC721EnumerableBurnModHarness.sol";
import {ERC721StorageUtils} from "test/utils/storage/ERC721StorageUtils.sol";

abstract contract ERC721EnumerableBurnMod_Base_Test is Base_Test {
    using ERC721StorageUtils for address;

    ERC721EnumerableBurnModHarness internal harness;

    function setUp() public virtual override {
        Base_Test.setUp();
        harness = new ERC721EnumerableBurnModHarness();
        vm.label(address(harness), "ERC721EnumerableBurnModHarness");
    }
}

