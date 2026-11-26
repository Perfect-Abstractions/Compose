// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {ERC4626ConvertToSharesMod_Base_Test} from "../ERC4626ConvertToSharesModBase.t.sol";
import {ConvertToSharesBehavior} from "../../shared/ConvertToSharesBehavior.t.sol";
import {ERC4626_Base_Test} from "test/unit/token/ERC4626/ERC4626Base.t.sol";

contract ConvertToShares_ERC4626ConvertToSharesMod_Fuzz_Unit_Test is
    ERC4626ConvertToSharesMod_Base_Test,
    ConvertToSharesBehavior
{
    function setUp() public override(ERC4626ConvertToSharesMod_Base_Test, ERC4626_Base_Test) {
        super.setUp();
    }

    function vault() internal view override returns (address) {
        return address(harness);
    }

    function convert(uint256 amount) internal view override returns (uint256) {
        return harness.convertToShares(amount);
    }
}
