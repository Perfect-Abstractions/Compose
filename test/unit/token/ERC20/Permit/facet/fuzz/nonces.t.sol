// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {ERC20PermitFacet_Base_Test} from "test/unit/token/ERC20/Permit/ERC20PermitFacetBase.t.sol";
import {ERC20PermitFacet} from "src/token/ERC20/Permit/ERC20PermitFacet.sol";

/**
 *  @dev BTT spec: test/trees/ERC20.tree
 */
contract Nonces_ERC20PermitFacet_Fuzz_Unit_Test is ERC20PermitFacet_Base_Test {
    function testFuzz_ShouldReturnZero_Nonces_WhenOwnerHasNotUsedPermit(address owner) external view {
        assertEq(facet.nonces(owner), 0, "nonces");
    }

    function test_ShouldIncrementNonce_AfterPermit() external {
        uint256 ownerPrivateKey = 0xA11CE;
        address owner = vm.addr(ownerPrivateKey);
        address spender = users.bob;
        uint256 value = 100e18;
        uint256 deadline = block.timestamp + 1 hours;
        bytes32 hash = _getPermitDigest(owner, spender, value, 0, deadline);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, hash);

        assertEq(facet.nonces(owner), 0, "nonce before");
        facet.permit(owner, spender, value, deadline, v, r, s);
        assertEq(facet.nonces(owner), 1, "nonce after");
    }
}
