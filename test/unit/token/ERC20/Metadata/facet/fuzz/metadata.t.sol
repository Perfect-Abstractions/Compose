// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {ERC20MetadataFacet_Base_Test} from "test/unit/token/ERC20/Metadata/ERC20MetadataFacetBase.t.sol";
import {ERC20MetadataFacet} from "src/token/ERC20/Metadata/ERC20MetadataFacet.sol";

/**
 *  @dev BTT spec: test/trees/ERC20.tree
 */
contract Metadata_ERC20MetadataFacet_Fuzz_Unit_Test is ERC20MetadataFacet_Base_Test {
    function test_ShouldReturnName_WhenSetViaMod() external {
        facet.setMetadata(TOKEN_NAME, TOKEN_SYMBOL, TOKEN_DECIMALS);
        assertEq(facet.name(), TOKEN_NAME, "name");
    }

    function test_ShouldReturnSymbol_WhenSetViaMod() external {
        facet.setMetadata(TOKEN_NAME, TOKEN_SYMBOL, TOKEN_DECIMALS);
        assertEq(facet.symbol(), TOKEN_SYMBOL, "symbol");
    }

    function test_ShouldReturnDecimals_WhenSetViaMod() external {
        facet.setMetadata(TOKEN_NAME, TOKEN_SYMBOL, TOKEN_DECIMALS);
        assertEq(facet.decimals(), TOKEN_DECIMALS, "decimals");
    }

    function testFuzz_ShouldReturnName_WhenSetViaMod(string memory name) external {
        vm.assume(bytes(name).length <= 100);
        facet.setMetadata(name, "SYM", 18);
        assertEq(facet.name(), name, "name");
    }

    function testFuzz_ShouldReturnSymbol_WhenSetViaMod(string memory symbol) external {
        vm.assume(bytes(symbol).length <= 100);
        facet.setMetadata("Name", symbol, 18);
        assertEq(facet.symbol(), symbol, "symbol");
    }

    function testFuzz_ShouldReturnDecimals_WhenSetViaMod(uint8 decimals) external {
        facet.setMetadata("Name", "SYM", decimals);
        assertEq(facet.decimals(), decimals, "decimals");
    }
}
