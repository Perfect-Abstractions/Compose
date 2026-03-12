// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30 <0.9.0;

/* Compose
 * https://compose.diamonds
 */

import {Base_Test} from "test/Base.t.sol";
import {
    ERC721EnumerableTransferModHarness
} from "test/utils/harnesses/token/ERC721/ERC721EnumerableTransferModHarness.sol";
import {ERC721StorageUtils} from "test/utils/storage/ERC721StorageUtils.sol";

abstract contract ERC721EnumerableTransferMod_Base_Test is Base_Test {
    using ERC721StorageUtils for address;

    ERC721EnumerableTransferModHarness internal harness;

    function setUp() public virtual override {
        Base_Test.setUp();
        harness = new ERC721EnumerableTransferModHarness();
        vm.label(address(harness), "ERC721EnumerableTransferModHarness");
    }
}

