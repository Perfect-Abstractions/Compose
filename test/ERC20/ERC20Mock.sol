// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.30;

import {ERC20Facet} from "../src/ERC20/ERC20/ERC20Facet.sol";
import {LibERC20} from "../src/ERC20/ERC20/libraries/LibERC20.sol";


/// @title ERC20Mock
/// @notice Helper contract that extends ERC20Facet and exposes mint function for testing.
/// @dev This contract is NOT part of the library. It exists solely to enable testing of ERC20Facet functionality.
contract ERC20Mock is ERC20Facet {
    
    /// @notice Mints tokens to address.
    /// @dev External function for LibERC20.mint() to enable testing.
    /// @param _to Address to receive minted tokens.
    /// @param _amount Amount of tokens to mint.
    function mint(address _to, uint256 _amount) external {
        LibERC20.mint(_to, _amount);
    }

    /// @notice Initializes the ERC20 token with name, symbol, and decimals.
    /// @dev Sets up storage for testing.
    /// @param _name Token name.
    /// @param _symbol Token symbol.
    /// @param _decimals Token decimals.
    function initialize(string memory _name, string memory _symbol, uint8 _decimals) external {
        LibERC20.ERC20Storage storage s = LibERC20.getStorage();
        s.name = _name;
        s.symbol = _symbol;
        s.decimals = _decimals;
    }
}
