// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

import {BaseBenchmark} from "./Base.t.sol";
import {DiamondLoupeFacet} from "../../src/diamond/DiamondLoupeFacet.sol";

/**
 *  @dev Please override `_deployLoupe` with the deployment of your optimised contract.
 */
contract OptimisedLoupeBenchmarkTest is BaseBenchmark {
    /*//////////////////////////////////////////////////////////////
                               OVERRIDES
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Override with a deployment of your optimised diamond loupe contract.
     */
    function _deployLoupe() internal override returns (address) {
        return address(new DiamondLoupeFacet());
    }

    /*//////////////////////////////////////////////////////////////
                             GAS BENCHMARKS
    //////////////////////////////////////////////////////////////*/

    struct Facet {
        address facet;
        bytes4[] functionSelectors;
    }

    function testGas_Loupe_Facets() external {
        uint256 startGas = gasleft();
        (bool success, bytes memory data) = address(diamond).call(abi.encodeWithSelector(SELECTOR_FACETS));
        emit log_uint(startGas - gasleft());

        Facet[] memory allFacets = abi.decode(data, (Facet[]));
        assertEq(allFacets.length, NUM_FACETS + 1); // plus Loupe
    }

    function testGas_Loupe_FacetFunctionSelectors() external {
        uint256 startGas = gasleft();
        (bool success, bytes memory data) =
            address(diamond).call(abi.encodeWithSelector(SELECTOR_FACET_FUNCTION_SELECTORS, loupe));
        emit log_uint(startGas - gasleft());

        bytes4[] memory facetSelectors = abi.decode(data, (bytes4[]));
        assertEq(facetSelectors.length, NUM_LOUPE_SELECTORS);
    }

    function testGas_Loupe_FacetAddresses() external {
        uint256 startGas = gasleft();
        (bool success, bytes memory data) = address(diamond).call(abi.encodeWithSelector(SELECTOR_FACET_ADDRESSES));
        emit log_uint(startGas - gasleft());

        address[] memory allFacets = abi.decode(data, (address[]));
        assertEq(allFacets.length, NUM_FACETS + 1); // plus Loupe
    }

    function testGas_Loupe_FacetAddress() external {
        uint256 startGas = gasleft();
        (bool success, bytes memory data) =
            address(diamond).call(abi.encodeWithSelector(SELECTOR_FACET_ADDRESS, SELECTOR_FACET_ADDRESSES));
        emit log_uint(startGas - gasleft());
    }
}
