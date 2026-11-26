// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {ERC4626MintFacet_Base_Test} from "../ERC4626MintFacetBase.t.sol";
import {EntryBehavior} from "test/unit/token/ERC4626/shared/ActionBehavior.t.sol";
import {ERC4626_Base_Test} from "test/unit/token/ERC4626/ERC4626Base.t.sol";

/**
 * @dev BTT spec: test/trees/ERC4626.tree
 */
contract Mint_ERC4626Facet_Fuzz_Unit_Test is ERC4626MintFacet_Base_Test, EntryBehavior {
    function setUp() public override(ERC4626MintFacet_Base_Test, ERC4626_Base_Test) {
        super.setUp();
    }

    function vault() internal view override returns (address) {
        return address(facet);
    }

    function quote(uint256 amount) internal view override returns (uint256) {
        return facet.previewMint(amount);
    }

    function limit(address owner) internal view override returns (uint256) {
        return facet.maxMint(owner);
    }

    function exactShares() internal pure override returns (bool) {
        return true;
    }

    function enter(uint256 amount, address receiver) internal override returns (uint256) {
        return facet.mint(amount, receiver);
    }
}
