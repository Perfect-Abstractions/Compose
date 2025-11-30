// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

import {BaseBenchmark} from "./Base.t.sol";
import {DiamondLoupeFacet} from "../../src/diamond/DiamondLoupeFacet.sol";

contract LoupeGasBenchmarkTest is BaseBenchmark {
    /*//////////////////////////////////////////////////////////////
                               OVERRIDES
    //////////////////////////////////////////////////////////////*/

    function _deployLoupe() internal override returns (address) {
        return address(new DiamondLoupeFacet());
    }

    /*//////////////////////////////////////////////////////////////
                             GAS BENCHMARKS
    //////////////////////////////////////////////////////////////*/

    /**
     * Estimated gas: 370_049_638
     */
    function testGas_Loupe_Facets() external {
        uint256 startGas = gasleft();
        (bool success, bytes memory data) = address(diamond).call(abi.encodeWithSelector(SELECTOR_FACETS));
        emit log_uint(startGas - gasleft());

        DiamondLoupeFacet.Facet[] memory allFacets = abi.decode(data, (DiamondLoupeFacet.Facet[]));
        assertEq(allFacets.length, NUM_FACETS + 1); // plus Loupe
    }

    /**
     * Estimated gas: 5_889_500
     */
    function testGas_Loupe_FacetFunctionSelectors() external {
        uint256 startGas = gasleft();
        (bool success, bytes memory data) =
            address(diamond).call(abi.encodeWithSelector(SELECTOR_FACET_FUNCTION_SELECTORS, loupe));
        emit log_uint(startGas - gasleft());

        bytes4[] memory facetSelectors = abi.decode(data, (bytes4[]));
        assertEq(facetSelectors.length, NUM_LOUPE_SELECTORS);
    }

    /**
     * Estimated gas: 31_606_629
     */
    function testGas_Loupe_FacetAddresses() external {
        uint256 startGas = gasleft();
        (bool success, bytes memory data) = address(diamond).call(abi.encodeWithSelector(SELECTOR_FACET_ADDRESSES));
        emit log_uint(startGas - gasleft());

        address[] memory allFacets = abi.decode(data, (address[]));
        assertEq(allFacets.length, NUM_FACETS + 1); // plus Loupe
    }

    /**
     * Estimated gas: 12_672
     */
    function testGas_Loupe_FacetAddress() external {
        uint256 startGas = gasleft();
        (bool success, bytes memory data) =
            address(diamond).call(abi.encodeWithSelector(SELECTOR_FACET_ADDRESS, SELECTOR_FACET_ADDRESSES));
        emit log_uint(startGas - gasleft());
    }
}
