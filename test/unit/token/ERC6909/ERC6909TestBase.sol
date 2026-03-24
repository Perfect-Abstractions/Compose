// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30 <0.9.0;

/* Compose
 * https://compose.diamonds
 */

import {Base_Test} from "test/Base.t.sol";
import {ERC6909StorageUtils} from "test/utils/storage/ERC6909StorageUtils.sol";

/**
 * @notice Shared ERC-6909 test setup: storage helpers for facet/mod harness contracts.
 * @dev Mirrors `ERC1155*Base` seed patterns so `using ERC6909StorageUtils for address` is exercised.
 */
abstract contract ERC6909_Test_Base is Base_Test {
    using ERC6909StorageUtils for address;

    function setUp() public virtual override {
        Base_Test.setUp();
    }

    function seedBalance(address target, address owner, uint256 id, uint256 value) internal {
        target.setBalanceOf(owner, id, value);
    }

    function seedAllowance(address target, address owner, address spender, uint256 id, uint256 value) internal {
        target.setAllowance(owner, spender, id, value);
    }

    function seedIsOperator(address target, address owner, address spender, bool value) internal {
        target.setIsOperator(owner, spender, value);
    }
}
