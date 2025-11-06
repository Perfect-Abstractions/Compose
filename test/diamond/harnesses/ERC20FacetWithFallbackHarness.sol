// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

import {ERC20Facet} from "../../../src/token/ERC20/ERC20/ERC20Facet.sol";

/// @title ERC20FacetHarness
/// @notice Test harness for ERC20Facet that adds initialization and minting for testing
contract ERC20FacetWithFallbackHarness is ERC20Facet {
    /// @notice Initialize the ERC20 token storage
    /// @dev Only used for testing - production diamonds should initialize in constructor
    function initialize(string memory _name, string memory _symbol, uint8 _decimals) external {
        ERC20Storage storage s = getStorage();
        s.name = _name;
        s.symbol = _symbol;
        s.decimals = _decimals;
    }

    /// @notice Mint tokens to an address
    /// @dev Only used for testing - exposes internal mint functionality
    function mint(address _to, uint256 _value) external {
        ERC20Storage storage s = getStorage();
        if (_to == address(0)) {
            revert ERC20InvalidReceiver(address(0));
        }
        unchecked {
            s.totalSupply += _value;
            s.balanceOf[_to] += _value;
        }
        emit Transfer(address(0), _to, _value);
    }

    /// @dev This function is to return an error message if the Diamond calls a function not present on initialization.`
    fallback() external {
        revert("WRONG FUNCTION CALL");
    }
}
