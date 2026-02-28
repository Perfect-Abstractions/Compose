// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

bytes32 constant STORAGE_POSITION = keccak256("eip712.typed.structured.data.hashing.and.signing");

/**
 * @custom:storage-location erc8042:eip712.typed.structured.data.hashing.and.signing
 */
struct EIP712Storage {
    bytes32 domainSeparator;
    string name;
    string version;
    bytes32 TYPE_HASH;
    bytes32 NAME_HASH;
    bytes32 VERSION_HASH;
    uint256 chainId;
    address verifyingContract;
}

/**
 * @notice Returns a pointer to the ERC-712 storage struct.
 * @dev Uses inline assembly to access the storage slot defined by STORAGE_POSITION.
 * @return s The EIP712Storage struct in storage.
 */
function getStorage() pure returns (EIP712Storage storage s) {
    bytes32 position = STORAGE_POSITION;
    assembly {
        s.slot := position
    }
}

/**
 * @notice Retures a domain separator from storage if calling contract and chain id is same as verifyingContract and chainId stored in storage.
 * @notice otherwise it builds the deomain separator
 * @return the domain separator
 */
function domainSeparator() view returns (bytes32) {
    EIP712Storage memory s = getStorage();

    address thisAddress;
    uint256 chain;
    assembly {
        thisAddress := address()
        chain := chainid()
    }

    if (thisAddress == s.verifyingContract && chain == s.chainId) {
        return s.domainSeparator;
    } else {
        return buildDomainSeparator(s, thisAddress, chain);
    }
}

/**
 * @param s EIP712 storage in smart contract
 * @param verifyingContract  verifying smart contract address from storage or current calling contract
 * @param chainid chainid of current using chain
 * @return returns the domain separator
 */
function buildDomainSeparator(EIP712Storage memory s, address verifyingContract, uint256 chainid)
    pure
    returns (bytes32)
{
    return keccak256(abi.encode(s.TYPE_HASH, s.NAME_HASH, s.VERSION_HASH, chainid, verifyingContract));
}

function hashTypedData(bytes32 structHash) view returns (bytes32) {
    return typedDataHash(domainSeparator(), structHash);
}

function typedDataHash(bytes32 domainSeparator, bytes32 structHash) pure returns (bytes32) {
    return keccak256(abi.encode("\x19\x01", domainSeparator, structHash));
}

/**
 * @return name of the EIP712 contract
 */
function EIP712Name() view returns (string memory) {
    return getStorage().name;
}

/**
 * @return version of the EIP712 contract
 */
function EIP712Version() view returns (string memory) {
    return getStorage().version;
}
