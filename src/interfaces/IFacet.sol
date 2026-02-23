// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

/**
 * @title IFacet
 * @notice Interface for a facet contract
 */
interface IFacet {
    /**
     * @notice Exports the selectors that are exposed by the facet.
     * @return Packed selectors that are exported by the facet.
     */
    function exportSelectors() external pure returns (bytes memory);
}