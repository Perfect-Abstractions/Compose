// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

import {ERC20PermitFacet} from "../../../../../src/token/ERC20/ERC20/ERC20PermitFacet.sol";

/// @title ERC20PermitFacetHarness
/// @notice Test harness for ERC20PermitFacet that adds initialization and minting for testing
contract ERC20PermitFacetHarness is ERC20PermitFacet {
    /// @notice Initialize the ERC20 token storage
    /// @dev Only used for testing - production diamonds should initialize in constructor
    function initialize(string memory _name, uint256 _totalSupply) external {
        ERC20PermitStorage storage s = getStorage();
        s.name = _name;
        s.totalSupply = _totalSupply;
    }

    /// @notice Mint tokens to an address
    /// @dev Only used for testing - exposes internal mint functionality
    function mint(address _to, uint256 _value) external {
        ERC20PermitStorage storage s = getStorage();
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
