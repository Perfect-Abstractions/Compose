// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/**
 * @title ERC-721 Token
 * @notice A complete, dependency-free ERC-721 implementation using the diamond storage pattern.
 * @dev This facet provides metadata, ownership, approvals, safe transfers, minting, burning, and helpers.
 */
contract ERC721MetadataFacet {
    /**
     * @notice Error indicating that the queried token does not exist.
     */
    error ERC721NonexistentToken(uint256 _tokenId);

    /**
     * @notice Error indicating the queried owner address is invalid (zero address).
     */
    error ERC721InvalidOwner(address _owner);

    bytes32 constant STORAGE_POSITION = keccak256("erc721.metadata");

    /**
     * @custom:storage-location erc8042:erc721
     */
    struct ERC721MetadataStorage {
        string name;
        string symbol;
        string baseURI;
    }

    /**
     * @notice Returns a pointer to the ERC-721 storage struct.
     * @dev Uses inline assembly to access the storage slot defined by STORAGE_POSITION.
     * @return s The ERC721Storage struct in storage.
     */
    function getStorage() internal pure returns (ERC721MetadataStorage storage s) {
        bytes32 position = STORAGE_POSITION;
        assembly {
            s.slot := position
        }
    }

    bytes32 constant ERC721_STORAGE_POSITION = keccak256("erc721");

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
    function getERC721Storage() internal pure returns (ERC721Storage storage s) {
        bytes32 position = STORAGE_POSITION;
        assembly {
            s.slot := position
        }
    }

    /**
     * @notice Returns the token collection name.
     * @return The name of the token collection.
     */
    function name() external view returns (string memory) {
        return getStorage().name;
    }

    /**
     * @notice Returns the token collection symbol.
     * @return The symbol of the token collection.
     */
    function symbol() external view returns (string memory) {
        return getStorage().symbol;
    }

    /**
     * @notice Provide the metadata URI for a given token ID.
     * @param _tokenId tokenID of the NFT to query the metadata from
     * @return the URI providing the detailed metadata of the specified tokenID
     */
    function tokenURI(uint256 _tokenId) external view returns (string memory) {
        ERC721MetadataStorage storage s = getStorage();
        ERC721Storage storage erc721Storage = getERC721Storage();
        address owner = erc721Storage.ownerOf[_tokenId];
        if (owner == address(0)) {
            revert ERC721NonexistentToken(_tokenId);
        }
        if (bytes(s.baseURI).length == 0) {
            return "";
        }
        if (_tokenId == 0) {
            return string.concat(s.baseURI, "0");
        }
        /**
         * Convert _tokenId to string
         */
        uint256 temp = _tokenId;
        uint256 stringLength;
        while (temp != 0) {
            stringLength++;
            temp /= 10;
        }
        bytes memory tokenIdString = new bytes(stringLength);
        while (_tokenId != 0) {
            stringLength--;
            /**
             * Convert each digit to its ASCII representation
             * by adding 48 to get the ASCII code for the digit.
             * Then store it in the byte array
             */
            tokenIdString[stringLength] = bytes1(uint8(48 + (_tokenId % 10)));
            _tokenId /= 10;
        }
        return string.concat(s.baseURI, string(tokenIdString));
    }
}
