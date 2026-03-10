// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {ERC20PermitFacet_Base_Test} from "test/unit/token/ERC20/Permit/ERC20PermitFacetBase.t.sol";

/**
 *  @dev BTT spec: test/trees/ERC20.tree
 */
contract DomainSeparator_ERC20PermitFacet_Unit_Test is ERC20PermitFacet_Base_Test {
    function test_ShouldReturnExpected_DOMAIN_SEPARATOR() external view {
        bytes32 expected = keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256(bytes(TOKEN_NAME)),
                keccak256("1"),
                block.chainid,
                address(facet)
            )
        );
        assertEq(facet.DOMAIN_SEPARATOR(), expected, "DOMAIN_SEPARATOR");
    }
}
