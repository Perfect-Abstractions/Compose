// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {ERC20TransferFacet} from "src/token/ERC20/ERC20/ERC20TransferFacet.sol";

/**
 * @title ERC20TransferFacetHarness
 * @notice Test harness for ERC20TransferFacet that adds minting for testing
 */
contract ERC20TransferFacetHarness is ERC20TransferFacet {
    /**
     * @notice Mint tokens to an address
     * @dev Only used for testing - exposes internal mint functionality
     */
    function mint(address _to, uint256 _value) external {
        ERC20TransferStorage storage s = getStorage();
        if (_to == address(0)) {
            revert ERC20InvalidReceiver(address(0));
        }
        unchecked {
            s.totalSupply += _value;
            s.balanceOf[_to] += _value;
        }
        emit Transfer(address(0), _to, _value);
    }
}
