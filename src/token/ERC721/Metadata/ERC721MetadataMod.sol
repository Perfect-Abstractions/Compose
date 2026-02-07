// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

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
function getStorage() pure returns (ERC721MetadataStorage storage s) {
    bytes32 position = STORAGE_POSITION;
    assembly {
        s.slot := position
    }
}

function setMetadata(string memory _name, string memory _symbol, string memory _baseURI) {
    ERC721MetadataStorage storage s = getStorage();
    s.name = _name;
    s.symbol = _symbol;
    s.baseURI = _baseURI;
}
