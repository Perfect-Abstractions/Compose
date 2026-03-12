// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30 <0.9.0;

/* Compose
 * https://compose.diamonds
 */

import {Base_Test} from "test/Base.t.sol";
import {ERC20PermitFacet} from "src/token/ERC20/Permit/ERC20PermitFacet.sol";
import {ERC20PermitFacetHarness} from "test/utils/harnesses/token/ERC20/ERC20PermitFacetHarness.sol";

abstract contract ERC20PermitFacet_Base_Test is Base_Test {
    ERC20PermitFacetHarness internal facet;

    function setUp() public virtual override {
        Base_Test.setUp();
        facet = new ERC20PermitFacetHarness();
        facet.setMetadata(TOKEN_NAME, TOKEN_SYMBOL, TOKEN_DECIMALS);
        vm.label(address(facet), "ERC20PermitFacetHarness");
    }

    /**
     * @dev Computes EIP-712 digest for Permit(owner, spender, value, nonce, deadline) for the current facet.
     */
    function _getPermitDigest(address owner, address spender, uint256 value, uint256 nonce, uint256 deadline)
        internal
        view
        returns (bytes32)
    {
        bytes32 structHash = keccak256(
            abi.encode(
                keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
                owner,
                spender,
                value,
                nonce,
                deadline
            )
        );
        return keccak256(abi.encodePacked("\x19\x01", facet.DOMAIN_SEPARATOR(), structHash));
    }
}
