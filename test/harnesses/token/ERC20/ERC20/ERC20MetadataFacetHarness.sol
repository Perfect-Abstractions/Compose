// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {ERC20MetadataFacet} from "src/token/ERC20/ERC20/ERC20MetadataFacet.sol";

/**
 * @title ERC20MetadataFacetHarness
 * @notice Test harness for ERC20MetadataFacet that adds initialization for testing
 */
contract ERC20MetadataFacetHarness is ERC20MetadataFacet {
    /**
     * @notice Initialize the ERC20 metadata storage
     * @dev Only used for testing - production diamonds should initialize in constructor
     */
    function initialize(string memory _name, string memory _symbol, uint8 _decimals) external {
        ERC20MetadataStorage storage s = getStorage();
        s.name = _name;
        s.symbol = _symbol;
        s.decimals = _decimals;
    }
}
