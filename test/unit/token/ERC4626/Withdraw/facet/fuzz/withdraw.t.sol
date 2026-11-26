// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {ERC4626WithdrawFacet_Base_Test} from "../ERC4626WithdrawFacetBase.t.sol";
import {ExitBehavior} from "test/unit/token/ERC4626/shared/ActionBehavior.t.sol";
import {ERC4626_Base_Test} from "test/unit/token/ERC4626/ERC4626Base.t.sol";

/**
 * @dev BTT spec: test/trees/ERC4626.tree
 */
contract Withdraw_ERC4626Facet_Fuzz_Unit_Test is ERC4626WithdrawFacet_Base_Test, ExitBehavior {
    function setUp() public override(ERC4626WithdrawFacet_Base_Test, ERC4626_Base_Test) {
        super.setUp();
    }

    function vault() internal view override returns (address) {
        return address(facet);
    }

    function quote(uint256 amount) internal view override returns (uint256) {
        return facet.previewWithdraw(amount);
    }

    function limit(address owner) internal view override returns (uint256) {
        return facet.maxWithdraw(owner);
    }

    function exactShares() internal pure override returns (bool) {
        return false;
    }

    function leave(uint256 amount, address receiver, address owner) internal override returns (uint256) {
        return facet.withdraw(amount, receiver, owner);
    }
}
