// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

/**
 * @title ERC-721 Data Facet
 */
contract ERC721DataFacet {
    /**
     * @notice Error indicating the queried owner address is invalid (zero address).
     */
    error ERC721InvalidOwner(address _owner);

    /**
     * @notice Error indicating that the queried token does not exist.
     */
    error ERC721NonexistentToken(uint256 _tokenId);

    bytes32 constant STORAGE_POSITION = keccak256("erc721");

    /**
     * @custom:storage-location erc8042:erc721
     */
    struct ERC721Storage {
        mapping(uint256 tokenId => address owner) ownerOf;
        mapping(address owner => uint256 balance) balanceOf;
        mapping(address owner => mapping(address operator => bool approved)) isApprovedForAll;
        mapping(uint256 tokenId => address approved) approved;
    }

    /**
     * @notice Returns a pointer to the ERC-721 storage struct.
     * @dev Uses inline assembly to access the storage slot defined by STORAGE_POSITION.
     * @return s The ERC721Storage struct in storage.
     */
    function getStorage() internal pure returns (ERC721Storage storage s) {
        bytes32 position = STORAGE_POSITION;
        assembly {
            s.slot := position
        }
    }

    /**
     * @notice Returns the number of tokens owned by a given address.
     * @param _owner The address to query the balance of.
     * @return The balance (number of tokens) owned by `_owner`.
     */
    function balanceOf(address _owner) external view returns (uint256) {
        if (_owner == address(0)) {
            revert ERC721InvalidOwner(_owner);
        }
        return getStorage().balanceOf[_owner];
    }

    /**
     * @notice Returns the owner of a given token ID.
     * @param _tokenId The token ID to query.
     * @return The address of the token owner.
     */
    function ownerOf(uint256 _tokenId) public view returns (address) {
        address owner = getStorage().ownerOf[_tokenId];
        if (owner == address(0)) {
            revert ERC721NonexistentToken(_tokenId);
        }
        return owner;
    }

    /**
     * @notice Returns the approved address for a given token ID.
     * @param _tokenId The token ID to query the approval of.
     * @return The approved address for the token.
     */
    function getApproved(uint256 _tokenId) external view returns (address) {
        address owner = getStorage().ownerOf[_tokenId];
        if (owner == address(0)) {
            revert ERC721NonexistentToken(_tokenId);
        }
        return getStorage().approved[_tokenId];
    }

    /**
     * @notice Returns true if an operator is approved to manage all of an owner's assets.
     * @param _owner The token owner.
     * @param _operator The operator address.
     * @return True if the operator is approved for all tokens of the owner.
     */
    function isApprovedForAll(address _owner, address _operator) external view returns (bool) {
        return getStorage().isApprovedForAll[_owner][_operator];
    }
}
