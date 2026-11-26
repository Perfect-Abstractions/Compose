// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {ERC4626MintMod_Base_Test} from "../ERC4626MintModBase.t.sol";
import {EntryBehavior} from "test/unit/token/ERC4626/shared/ActionBehavior.t.sol";
import {ERC4626_Base_Test} from "test/unit/token/ERC4626/ERC4626Base.t.sol";

/**
 * @dev BTT spec: test/trees/ERC4626.tree
 */
contract Mint_ERC4626Mod_Fuzz_Unit_Test is ERC4626MintMod_Base_Test, EntryBehavior {
    function setUp() public override(ERC4626MintMod_Base_Test, ERC4626_Base_Test) {
        super.setUp();
    }

    function vault() internal view override returns (address) {
        return address(harness);
    }

    function quote(uint256 amount) internal view override returns (uint256) {
        return harness.previewMint(amount);
    }

    function limit(address owner) internal view override returns (uint256) {
        return harness.maxMint(owner);
    }

    function exactShares() internal pure override returns (bool) {
        return true;
    }

    function enter(uint256 amount, address receiver) internal override returns (uint256) {
        return harness.mint(amount, receiver);
    }
}
