// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {ERC4626RedeemMod_Base_Test} from "../ERC4626RedeemModBase.t.sol";
import {ExitBehavior} from "test/unit/token/ERC4626/shared/ActionBehavior.t.sol";
import {ERC4626_Base_Test} from "test/unit/token/ERC4626/ERC4626Base.t.sol";

/**
 * @dev BTT spec: test/trees/ERC4626.tree
 */
contract Redeem_ERC4626Mod_Fuzz_Unit_Test is ERC4626RedeemMod_Base_Test, ExitBehavior {
    function setUp() public override(ERC4626RedeemMod_Base_Test, ERC4626_Base_Test) {
        super.setUp();
    }

    function vault() internal view override returns (address) {
        return address(harness);
    }

    function quote(uint256 amount) internal view override returns (uint256) {
        return harness.previewRedeem(amount);
    }

    function limit(address owner) internal view override returns (uint256) {
        return harness.maxRedeem(owner);
    }

    function exactShares() internal pure override returns (bool) {
        return true;
    }

    function leave(uint256 amount, address receiver, address owner) internal override returns (uint256) {
        return harness.redeem(amount, receiver, owner);
    }

    function test_RevertWhen_PositiveRedeemRoundsToZero() external {
        seedExit();
        assertEq(quote(1), 0);

        expectZeroQuoteRevert(true);
        leave(1, users.receiver, users.alice);

        assertEq(limit(users.alice), 1000);
        assertEq(assetToken.balanceOf(users.receiver), 0);
    }
}
