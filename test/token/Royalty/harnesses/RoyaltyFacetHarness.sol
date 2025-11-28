/**
 *  SPDX-License-Identifier: MIT
 */
pragma solidity >=0.8.30;

import {RoyaltyFacet} from "../../../../src/token/Royalty/RoyaltyFacet.sol";

/**
 * @title RoyaltyFacetHarness
 * @notice Test harness for RoyaltyFacet
 * @dev Adds helper functions to set up royalty state for testing
 */
contract RoyaltyFacetHarness is RoyaltyFacet {
    /**
     * @notice Set default royalty (for testing)
     * @dev Directly manipulates storage to set default royalty info
     */
    function setDefaultRoyalty(address _receiver, uint96 _feeNumerator) external {
        RoyaltyStorage storage s = getStorage();
        s.defaultRoyaltyInfo = RoyaltyInfo(_receiver, _feeNumerator);
    }

    /**
     * @notice Set token royalty (for testing)
     * @dev Directly manipulates storage to set token-specific royalty info
     */
    function setTokenRoyalty(uint256 _tokenId, address _receiver, uint96 _feeNumerator) external {
        RoyaltyStorage storage s = getStorage();
        s.tokenRoyaltyInfo[_tokenId] = RoyaltyInfo(_receiver, _feeNumerator);
    }
}
