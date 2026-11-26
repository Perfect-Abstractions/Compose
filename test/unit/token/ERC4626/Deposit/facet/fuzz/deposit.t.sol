// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {ERC4626DepositFacet_Base_Test} from "../ERC4626DepositFacetBase.t.sol";
import {EntryBehavior} from "test/unit/token/ERC4626/shared/ActionBehavior.t.sol";
import {ERC4626_Base_Test} from "test/unit/token/ERC4626/ERC4626Base.t.sol";
import {ERC20StorageUtils} from "test/utils/storage/ERC20StorageUtils.sol";

/**
 * @dev BTT spec: test/trees/ERC4626.tree
 */
contract Deposit_ERC4626Facet_Fuzz_Unit_Test is ERC4626DepositFacet_Base_Test, EntryBehavior {
    using ERC20StorageUtils for address;

    function setUp() public override(ERC4626DepositFacet_Base_Test, ERC4626_Base_Test) {
        super.setUp();
    }

    function vault() internal view override returns (address) {
        return address(facet);
    }

    function quote(uint256 amount) internal view override returns (uint256) {
        return facet.previewDeposit(amount);
    }

    function limit(address owner) internal view override returns (uint256) {
        return facet.maxDeposit(owner);
    }

    function exactShares() internal pure override returns (bool) {
        return false;
    }

    function enter(uint256 amount, address receiver) internal override returns (uint256) {
        return facet.deposit(amount, receiver);
    }

    function test_RevertWhen_PositiveDepositRoundsToZero() external {
        seedVault(vault(), 100, 0);
        address(assetToken).setBalance(users.alice, 1);
        assertEq(quote(1), 0);

        expectZeroQuoteRevert(false);
        enter(1, users.receiver);

        assertEq(assetToken.balanceOf(users.alice), 1);
        assertEq(assetToken.balanceOf(vault()), 100);
    }
}
