// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

import {ERC721Facet} from "../../../../../src/token/ERC721/ERC721/ERC721Facet.sol";

contract ERC721FacetHarness is ERC721Facet {
    /// @notice Initialize the ERC721 token storage
    /// @dev Only used for testing - production diamonds should initialize in constructor
    function initialize(
        string memory _name,
        string memory _symbol,
        string memory _baseURI
    ) external {
        ERC721Storage storage s = getStorage();
        s.name = _name;
        s.symbol = _symbol;
        s.baseURI = _baseURI;
    }

    function baseURI() external view returns(string memory){
        return ERC721Facet.getStorage().baseURI;
    }   

    /// @notice Mints a new ERC-721 token to the specified address.
    /// @dev Reverts if the receiver address is zero or if the token already exists.
    /// @param _to The address that will own the newly minted token.
    /// @param _tokenId The ID of the token to mint.
    function mint(address _to, uint256 _tokenId) public {
        ERC721Storage storage s = getStorage();
        require(_to != address(0), "ERC721InvalidReceiver");
        require(s.ownerOf[_tokenId] == address(0), "ERC721InvalidSender");
        s.ownerOf[_tokenId] = _to;
        unchecked {
            s.balanceOf[_to]++;
        }
        emit Transfer(address(0), _to, _tokenId);
    }
}