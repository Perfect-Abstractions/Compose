// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {ERC721BurnFacet} from "../../../../../src/token/ERC721/ERC721/ERC721BurnFacet.sol";

contract ERC721BurnFacetHarness is ERC721BurnFacet {
    /**
     * @notice Initialize the ERC721 token storage
     * @dev Only used for testing - production diamonds should initialize in constructor
     */
    function initialize() external {
        ERC721Storage storage s = getStorage();
    }

    /**
     * @notice Mints a new ERC-721 token to the specified address.
     * @dev Reverts if the receiver address is zero or if the token already exists.
     * @param _to The address that will own the newly minted token.
     * @param _tokenId The ID of the token to mint.
     */
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

    /**
     * @notice Returns the owner of a given token ID (raw, does not revert for non-existent tokens).
     * @param _tokenId The token ID to query.
     * @return The address of the token owner (or address(0) if not minted).
     */
    function ownerOf(uint256 _tokenId) public view returns (address) {
        return getStorage().ownerOf[_tokenId];
    }
}
