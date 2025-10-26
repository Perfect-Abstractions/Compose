// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

import {ERC721Facet} from "../../../src/token/ERC721/ERC721/ERC721Facet.sol";

/// @title ERC721FacetHarness
/// @notice Test harness for ERC721Facet that adds initialization and minting for testing
contract ERC721FacetHarness is ERC721Facet {
    /// @notice Initialize the ERC721 token storage
    /// @dev Only used for testing - production diamonds should initialize in constructor
    function initialize(string memory _name, string memory _symbol, string memory _baseURI) external {
        ERC721Storage storage s = getStorage();
        s.name = _name;
        s.symbol = _symbol;
        s.baseURI = _baseURI;
    }

    /// @notice Mint tokens to an address
    /// @dev Only used for testing - exposes internal mint functionality
    function mint(address _to, uint256 _tokenId) external {
        ERC721Storage storage s = getStorage();
        if (_to == address(0)) {
            revert ERC721InvalidReceiver(address(0));
        }
        if (s.ownerOf[_tokenId] != address(0)) {
            revert ERC721InvalidSender(address(0));
        }
        s.ownerOf[_tokenId] = _to;
        unchecked {
            s.balanceOf[_to]++;
        }
        emit Transfer(address(0), _to, _tokenId);
    }

    /// @notice Burn a token
    /// @dev Only used for testing - exposes internal burn functionality
    function burn(uint256 _tokenId) external {
        ERC721Storage storage s = getStorage();
        address owner = s.ownerOf[_tokenId];
        if (owner == address(0)) {
            revert ERC721NonexistentToken(_tokenId);
        }
        delete s.ownerOf[_tokenId];
        delete s.approved[_tokenId];
        unchecked {
            s.balanceOf[owner]--;
        }
        emit Transfer(owner, address(0), _tokenId);
    }
}
